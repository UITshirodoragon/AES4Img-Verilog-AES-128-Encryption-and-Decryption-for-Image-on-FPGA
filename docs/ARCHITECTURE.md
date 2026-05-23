# Kiến Trúc AES4Img

Tài liệu này mô tả kiến trúc hiện tại của repo AES4Img: nhận ảnh RGB565 320x240, lưu vào SRAM, xử lý AES-128 theo block 8 pixel, và hiển thị kết quả qua VGA 640x480.

## Mục tiêu thiết kế

- Giữ nguyên AES encryption/decryption core đã có, chỉ chuẩn hóa interface bằng wrapper.
- Tránh dùng internal ROM lớn trong flow demo thật vì ảnh 320x240 RGB565 cần khoảng 1.23 Mbit.
- Cho UART loader, AES DMA và VGA cùng chia sẻ external SRAM có priority rõ ràng.
- Có fast mode để đo throughput và slow mode để quan sát ảnh thay đổi trên VGA.
- Tách module theo chức năng để dễ mô phỏng, thay top-level, hoặc nâng cấp từng khối.

## Dataflow tổng quát

```text
PC image
  |
  | 0xAA + 256 payload bytes + CRC8
  v
UART RX / packet checker
  |
  | 128 RGB565 words per packet
  v
SRAM ADDR_ORIG
  |
  | DMA reads 8 pixels = 128-bit AES block
  v
AES-128 wrapper
  |
  | DMA writes 8 RGB565 words
  v
SRAM ADDR_ENC or ADDR_DEC
  |
  v
VGA quadrant renderer + dashboard
```

## SRAM map

```verilog
ADDR_ORIG = 18'h00000; // original image
ADDR_ENC  = 18'h14000; // encrypted image
ADDR_DEC  = 18'h28000; // decrypted image
```

Với ảnh 320x240:

```text
Pixels per image = 320 * 240 = 76,800
Word size        = 16-bit RGB565
Bytes per image  = 153,600
AES block        = 8 pixels = 128 bits
AES blocks/image = 9,600
```

## VGA layout

VGA chạy 640x480, chia 4 vùng 320x240:

```text
+----------------------+----------------------+
| ORIG                 | DASHBOARD            |
| SRAM[ADDR_ORIG]      | text status/debug    |
+----------------------+----------------------+
| ENC                  | DEC                  |
| SRAM[ADDR_ENC]       | SRAM[ADDR_DEC]       |
+----------------------+----------------------+
```

Các module chính:

- `vga_timing_640x480.v`: tạo timing 640x480@60Hz từ clock 25 MHz.
- `vga_sram_reader.v`: tạo request đọc SRAM cho 3 vùng ảnh.
- `vga_quadrant_renderer_320x240.v`: render pixel RGB565 và label vùng.
- `text_dashboard.v`: render trạng thái controller, DMA, AES, UART, packet, CRC.
- `vga_system_640x480.v`: ghép timing, reader, renderer và dashboard.

## AES core boundary

`rtl/aes_core/aes128_core_wrapper.v` là ranh giới IP ổn định:

```verilog
start
decrypt
block_in[127:0]
key[127:0]
  -> block_out[127:0]
  -> busy
  -> done
```

Wrapper giữ nguyên hai core cũ:

- `aes_encryption_core.v`
- `aes_decryption_core.v`

Khóa mặc định trong controller:

```verilog
128'h2b7e151628aed2a6abf7158809cf4f3c
```

## AES/SRAM DMA

`rtl/dma/aes_sram_dma_320x240.v` đọc ảnh theo từng block:

1. Đọc 8 word RGB565 liên tiếp từ vùng nguồn.
2. Pack thành `block_in[127:0]`.
3. Gửi `start` cho AES wrapper.
4. Chờ `done`.
5. Unpack `block_out[127:0]` thành 8 word RGB565.
6. Ghi vào vùng đích.

Nguồn và đích phụ thuộc mode:

| Mode | Nguồn | Đích |
|---|---|---|
| Encrypt | `ADDR_ORIG` | `ADDR_ENC` |
| Decrypt | `ADDR_ENC` | `ADDR_DEC` |

## SRAM arbitration

Repo có 2 arbiter:

| Module | Số master | Dùng ở đâu |
|---|---:|---|
| `sram_arbiter.v` | 2 | ROM/preloaded profile: DMA và VGA |
| `sram_arbiter_3m.v` | 3 | UART profile: UART loader, AES DMA, VGA |

Priority trong UART profile:

```text
UART loader > AES DMA > VGA reader
```

Lý do:

- Khi đang load ảnh, UART phải ghi SRAM liên tục để hoàn thành packet.
- Khi AES chạy fast mode, DMA cần toàn quyền SRAM để đạt throughput.
- VGA chỉ đọc khi hệ thống cho phép xem ảnh, hoặc khi DMA đang throttle trong slow mode.

## System phases trong `top_uart`

`rtl/control/aes_image_demo_controller_uart.v` điều khiển flow chính:

```text
C_CLEAR_SRAM
  -> xóa 3 vùng ORIG/ENC/DEC sau reset
C_WAIT_IMAGE
  -> chờ PC gửi đủ 600 packet
C_IDLE
  -> ảnh đã sẵn sàng, chờ KEY[1]
C_ENC_RUN
  -> DMA encrypt ORIG -> ENC
C_ENC_OK
  -> lưu flag encrypt done
C_DEC_RUN
  -> DMA decrypt ENC -> DEC
C_DEC_OK
  -> lưu flag decrypt done
C_DONE
  -> hiển thị kết quả, KEY[1] quay lại idle
```

`SW[8]` bypasses UART wait nếu `ADDR_ORIG` đã được preload bằng công cụ khác.

## Fast mode và Slow-L3

`input_control.v` giải mã:

```text
SW[0] = 0 -> FAST
SW[0] = 1 -> SLOW-L3
```

Fast mode:

- AES/DMA được ưu tiên throughput.
- VGA image read bị chặn khi UART loader hoặc AES DMA busy.
- Dashboard vẫn hiển thị trạng thái.

Slow-L3:

- DMA được throttle theo frame tick.
- VGA có slot đọc SRAM để ảnh ORIG/ENC/DEC hiện dần trên màn hình.
- Phù hợp demo trực quan hơn là đo tốc độ.

## Top-level profiles

| Top-level | Controller | SRAM master set | Input image path |
|---|---|---|---|
| `top_uart.v` | `aes_image_demo_controller_uart` | UART + DMA + VGA | PC gửi qua UART |
| `top_preloaded.v` | `aes_image_demo_controller_preloaded` | DMA + VGA | External SRAM đã có ORIG |
| `top.v` | `aes_image_demo_controller` | ROM loader + DMA + VGA | Internal ROM đọc HEX |

`top_uart` là flow khuyến nghị cho phần cứng thật vì không cần synthesize ROM ảnh 320x240 trong FPGA.

## Extension points

- Thay AES core: giữ interface của `aes128_core_wrapper.v`.
- Tăng baudrate: cập nhật cả `tools/send_image_packet_2.py` và `rtl/uart/baud_rate_gen.v`.
- Thêm readback UART: thêm command/packet mới sau khi image load.
- Verify phần cứng đầy đủ: thêm DMA compare pass đọc `ADDR_ORIG` và `ADDR_DEC`.
- Hỗ trợ ảnh kích thước khác: parameter `IMG_W`, `IMG_H`, address map, packet count và VGA layout đều cần đồng bộ.
