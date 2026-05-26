# Lưu Ý Bộ Nhớ Cho Ảnh 320x240 RGB565

Ảnh 320x240 RGB565 có dung lượng:

```text
320 * 240 * 16 bit = 1,228,800 bit
320 * 240 * 2 byte = 153,600 byte
```

Chỉ riêng ảnh gốc đã cần khoảng 1.23 Mbit nếu đặt trong internal ROM/RAM FPGA. Với Cyclone II trên DE2, dung lượng M4K dễ bị thiếu sau khi cộng thêm AES core, font ROM, UART, VGA và logic điều khiển.

## Profile Đang Giữ

Sau khi rút gọn, project chính chỉ giữ 2 top:

| Top | Vai trò | Ảnh đầu vào | Ghi chú bộ nhớ |
|---|---|---|---|
| `rtl/top_de.v` | Nạp kit DE2 thật | UART ghi vào external SRAM | Khuyến nghị cho phần cứng thật, không synthesize ROM ảnh lớn |
| `rtl/top.v` | Smoke-test, testbench, debug | ROM HEX qua `$readmemh` | Dùng cho mô phỏng hoặc FPGA có đủ RAM nội bộ |

Profile preloaded riêng đã bỏ. Nếu cần dùng ảnh đã nạp sẵn trong SRAM, dùng `top_de.v` và bật `SW[8]` để bypass bước chờ UART.

## `top.v`: ROM Nội Bộ Cho Test

Dùng khi:

- Mô phỏng functional.
- Smoke-test hệ thống kích thước nhỏ.
- Cần flow đơn giản, ảnh được build sẵn vào project test.

Flow:

```text
image_320x240_rgb565.hex
  -> image_rom_320x240_rgb565
  -> image_loader_320x240
  -> SRAM[ADDR_ORIG]
  -> AES/VGA debug flow
```

Ưu điểm:

- Dễ mô phỏng.
- Không cần PC gửi ảnh qua UART.
- Có thể rút nhỏ `IMG_W/IMG_H` trong testbench.

Nhược điểm:

- Không phù hợp làm flow phần cứng chính trên DE2 nếu ảnh 320x240 được synthesize vào FPGA.
- Mỗi lần đổi ảnh phải regenerate HEX/MIF và rebuild flow test.

## `top_de.v`: UART Live Loader Cho DE2

Dùng khi:

- Muốn demo trực tiếp với PC.
- Muốn thay ảnh nhanh mà không rebuild Quartus.
- Board có UART/RS232 adapter.

Flow:

```text
tools/send_image_packet_2.py
  -> UART 115200 8N1
  -> uart_image_loader_320x240
  -> SRAM[ADDR_ORIG]
  -> AES encrypt/decrypt
  -> VGA dashboard
```

Ưu điểm:

- Không cần ROM ảnh nội bộ.
- Đổi ảnh từ PC thuận tiện.
- Có packet CRC8, ACK/NACK và dashboard debug.

Nhược điểm:

- 115200 baud mất khoảng 14-25 giây cho một ảnh 153,600 byte.
- Cần pyserial/Pillow trên PC.

## SRAM Map

```verilog
ADDR_ORIG = 18'h00000; // original image
ADDR_ENC  = 18'h14000; // encrypted image
ADDR_DEC  = 18'h28000; // decrypted image
```

Mỗi vùng ảnh cần:

```text
320 * 240 = 76,800 word 16-bit
```

Ba vùng ảnh cần:

```text
76,800 * 3 = 230,400 word 16-bit
```

## Archive Không Ảnh Hưởng Build

`legacy/` và `legacy_uart/` được giữ để đối chiếu lịch sử. Hai thư mục này:

- Không nằm trong `quartus/AES4Img.qsf`.
- Không nằm trong `sim/scripts/rtl_files.f`.
- Không được gọi bởi `top_de.v` hoặc `top.v`.
- Không ảnh hưởng compile project chính.

## Khuyến Nghị

- Dùng `top_de.v` cho demo phần cứng thật.
- Dùng `top.v` cho simulation hoặc smoke test.
- Giữ file `image_320x240_rgb565.hex/.mif` làm mẫu cho test/debug.
- Không commit các thư mục build Quartus như `quartus/db/`, `quartus/incremental_db/`, `quartus/output_files/`.
