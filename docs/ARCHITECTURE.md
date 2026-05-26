# Kiến Trúc AES4Img

Tài liệu này mô tả kiến trúc chính sau khi rút gọn của AES4Img. Repo chỉ còn 2 top-level đang được bảo trì:

- `rtl/top_de.v`: top phần cứng để compile/nạp lên kit DE2.
- `rtl/top.v`: top mô phỏng, smoke-test, testbench và debug.

Hai thư mục `legacy/` và `legacy_uart/` được giữ lại để tham khảo lịch sử, nhưng không nằm trong Quartus project, không nằm trong ModelSim source list chính, và không ảnh hưởng đến kiến trúc hiện tại.

## Mục Tiêu Thiết Kế

- Nhận ảnh RGB565 320x240 từ PC qua UART trong flow phần cứng thật.
- Lưu ảnh gốc, ảnh mã hóa và ảnh giải mã trong external SRAM 16-bit.
- Xử lý AES-128 theo block 128-bit, tương đương 8 pixel RGB565 mỗi block.
- Hiển thị đồng thời ảnh gốc, ảnh mã hóa, ảnh giải mã và dashboard debug qua VGA 640x480.
- Giữ nguyên AES encryption/decryption core gốc, chỉ chuẩn hóa interface bằng wrapper `start/busy/done`.
- Tách top phần cứng và top test để tránh đưa ROM ảnh lớn vào build DE2 thật.

## Top-Level Chính

| Top-level | Mục đích | Controller | Đường ảnh đầu vào | Compile chính |
|---|---|---|---|---|
| `rtl/top_de.v` | Nạp kit DE2 thật | `aes_image_demo_controller_uart` | PC gửi qua UART/RS232 | Có, trong `quartus/AES4Img.qsf` |
| `rtl/top.v` | Smoke-test, testbench, debug | `aes_image_demo_controller` | ROM HEX nội bộ qua `$readmemh` | Không dùng cho Quartus phần cứng thật |

`top_de.v` là top-level phần cứng chính. `top.v` vẫn được giữ vì testbench cần một top ổn định, có parameter để rút nhỏ ảnh khi mô phỏng.

## Dataflow Phần Cứng `top_de`

```text
PC image
  -> tools/send_image_packet_2.py
  -> UART 115200 8N1
  -> uart_controller
  -> uart_rx_packet_256
  -> uart_sram_packet_writer_320x240
  -> SRAM[ADDR_ORIG]
  -> aes_sram_dma_320x240
  -> aes128_core_wrapper
  -> SRAM[ADDR_ENC] hoặc SRAM[ADDR_DEC]
  -> vga_system_640x480
  -> VGA monitor
```

## Dataflow Test/Debug `top`

```text
image_320x240_rgb565.hex
  -> image_rom_320x240_rgb565
  -> image_loader_320x240
  -> SRAM[ADDR_ORIG]
  -> aes_sram_dma_320x240
  -> aes128_core_wrapper
  -> SRAM[ADDR_ENC] hoặc SRAM[ADDR_DEC]
  -> vga_system_640x480
```

## Memory Map

External SRAM dùng địa chỉ word 16-bit, mỗi pixel RGB565 chiếm 1 word.

```verilog
ADDR_ORIG = 18'h00000; // 0x00000..0x12BFF, ảnh gốc
ADDR_ENC  = 18'h14000; // 0x14000..0x26BFF, ảnh đã mã hóa
ADDR_DEC  = 18'h28000; // 0x28000..0x3ABFF, ảnh đã giải mã
```

Với ảnh mặc định:

```text
IMG_W            = 320
IMG_H            = 240
Pixels/image     = 76,800
Bytes/image      = 153,600
Words/image      = 76,800
AES block        = 128 bit = 8 pixel RGB565
AES blocks/image = 9,600
```

Ba vùng ảnh cần tổng cộng `230,400` word SRAM. Khoảng trống giữa các base address giúp debug địa chỉ dễ hơn.

## Interface `top_de.v`

### Input

| Tín hiệu | Rộng | Chức năng |
|---|---:|---|
| `CLOCK_50` | 1 | Clock hệ thống 50 MHz |
| `KEY[0]` | 1 | Reset active-low |
| `KEY[1]` | 1 | Start AES operation |
| `KEY[2]` | 1 | Pause/resume DMA |
| `KEY[3]` | 1 | Step/debug pulse |
| `SW[0]` | 1 | `0=FAST`, `1=SLOW-L3` |
| `SW[1]` | 1 | `0=ENCRYPT`, `1=DECRYPT` |
| `SW[2]` | 1 | Auto encrypt rồi decrypt |
| `SW[5]` | 1 | Verify marker enable |
| `SW[6]` | 1 | Clear status/reload marker |
| `SW[7]` | 1 | Debug pattern |
| `SW[8]` | 1 | Bypass UART wait nếu `ADDR_ORIG` đã được preload |
| `UART_RXD` | 1 | UART receive từ PC |

`SW[3]`, `SW[4]`, `SW[9]..SW[17]` hiện chưa dùng trong controller chính.

### Output/Inout

| Tín hiệu | Rộng | Chức năng |
|---|---:|---|
| `UART_TXD` | 1 | UART ACK/NACK về PC |
| `SRAM_ADDR[17:0]` | 18 | External SRAM address |
| `SRAM_DQ[15:0]` | 16 | External SRAM data bus bidirectional |
| `SRAM_WE_N` | 1 | SRAM write enable active-low |
| `SRAM_OE_N` | 1 | SRAM output enable active-low |
| `SRAM_UB_N` | 1 | SRAM upper byte enable active-low |
| `SRAM_LB_N` | 1 | SRAM lower byte enable active-low |
| `SRAM_CE_N` | 1 | SRAM chip enable active-low |
| `VGA_HS`, `VGA_VS` | 1 | VGA sync |
| `VGA_R/G/B[9:0]` | 10 mỗi kênh | VGA color output |
| `VGA_CLK` | 1 | Pixel clock 25 MHz |
| `VGA_BLANK_N` | 1 | VGA blank active-low |
| `VGA_SYNC_N` | 1 | VGA sync active-low, giữ 0 theo board DAC |
| `LEDR[17:0]` | 18 | Debug state/counter |
| `LEDG[8:0]` | 9 | Debug flags |

## Controller `aes_image_demo_controller_uart`

Flow phần cứng chính:

```text
C_CLEAR_SRAM
  -> clear ORIG/ENC/DEC sau reset
C_WAIT_IMAGE
  -> chờ PC gửi đủ 600 packet hoặc SW[8] bypass
C_IDLE
  -> chờ KEY[1]
C_ENC_RUN
  -> DMA encrypt ORIG -> ENC
C_ENC_OK
  -> set encrypt done flag
C_DEC_RUN
  -> DMA decrypt ENC -> DEC
C_DEC_OK
  -> set decrypt done flag
C_DONE
  -> giữ kết quả trên VGA, KEY[1] quay về idle
```

Các state được mã hóa bằng `localparam` trong controller:

```verilog
C_WAIT_IMAGE = 4'd0;
C_IDLE       = 4'd1;
C_ENC_RUN    = 4'd2;
C_ENC_OK     = 4'd3;
C_DEC_RUN    = 4'd4;
C_DEC_OK     = 4'd5;
C_DONE       = 4'd6;
C_CLEAR_SRAM = 4'd7;
```

## UART Packet Interface

PC gửi đúng 600 packet cho ảnh 320x240 RGB565:

```text
HEADER : 0xAA
DATA   : 256 bytes
CRC8   : 1 byte, polynomial 0x07, init 0xFF, tính trên DATA
ACK    : 0x06
NACK   : 0x15
```

Mỗi packet chứa 256 byte, tương đương 128 pixel RGB565. Byte order là high byte trước, low byte sau:

```verilog
sram_wdata <= {high_byte, low_byte};
```

## SRAM Arbitration

`top_de.v` dùng `sram_arbiter_3m.v` với 3 master:

| Master | Chức năng |
|---|---|
| UART loader | Ghi ảnh gốc vào `ADDR_ORIG` |
| AES DMA | Đọc/ghi ORIG, ENC, DEC |
| VGA reader | Đọc 3 vùng ảnh để hiển thị |

Priority:

```text
UART loader > AES DMA > VGA reader
```

`top.v` dùng `sram_arbiter.v` với 2 master: ROM loader/AES DMA dùng chung slot DMA, và VGA reader.

## AES DMA

`rtl/dma/aes_sram_dma_320x240.v` là cầu nối SRAM và AES wrapper.

Input điều khiển chính:

| Tín hiệu | Chức năng |
|---|---|
| `start` | Bắt đầu chạy một lượt ảnh |
| `decrypt` | `0`: ORIG->ENC, `1`: ENC->DEC |
| `fast_mode` | Chạy tối đa throughput |
| `slow_level` | Mức throttle khi quan sát VGA |
| `pause` | Dừng/tiếp tục DMA |
| `step` | Bước debug |
| `frame_tick` | Tick theo frame VGA để throttle |

FSM DMA:

```verilog
S_IDLE       = 4'd0;
S_READ_REQ   = 4'd1;
S_READ_WAIT  = 4'd2;
S_READ_CAP   = 4'd3;
S_AES_START  = 4'd4;
S_AES_WAIT   = 4'd5;
S_WRITE_REQ  = 4'd6;
S_WRITE_WAIT = 4'd7;
S_NEXT       = 4'd8;
S_THROTTLE   = 4'd9;
S_DONE       = 4'd10;
```

Byte/word packing:

- Pixel 0 đi vào `aes_block_in[127:112]`.
- Pixel 7 đi vào `aes_block_in[15:0]`.
- Khi ghi kết quả, mapping được đảo ngược tương ứng từ `aes_block_out`.

## AES Wrapper

`rtl/aes_core/aes128_core_wrapper.v` là interface ổn định của AES core:

```verilog
input  clk;
input  reset_n;
input  start;
input  decrypt;
input  [127:0] block_in;
input  [127:0] key;
output [127:0] block_out;
output busy;
output done;
output [3:0] core_state_dbg;
```

Khóa mặc định trong controller:

```verilog
128'h2b7e151628aed2a6abf7158809cf4f3c
```

## VGA Subsystem

VGA chạy 640x480 và chia màn hình thành 4 vùng 320x240:

```text
+----------------------+----------------------+
| ORIG                 | DASHBOARD            |
| SRAM[ADDR_ORIG]      | state/counter/debug  |
+----------------------+----------------------+
| ENC                  | DEC                  |
| SRAM[ADDR_ENC]       | SRAM[ADDR_DEC]       |
+----------------------+----------------------+
```

Module:

- `vga_timing_640x480.v`: sinh `x`, `y`, `video_on`, `frame_tick_25`, HS/VS.
- `vga_sram_reader.v`: tạo request SRAM cho ORIG/ENC/DEC.
- `vga_quadrant_renderer_320x240.v`: render RGB565 và label vùng.
- `text_dashboard.v`: render state controller, DMA, AES, UART, packet, CRC.
- `vga_system_640x480.v`: ghép toàn bộ VGA pipeline.

## Parameter Và Define

Thiết kế hiện không dùng global `` `define `` cho cấu hình chính. Các cấu hình quan trọng dùng `parameter` và `localparam`.

Parameter top/debug:

```verilog
IMG_W     = 320;
IMG_H     = 240;
ADDR_ORIG = 18'h00000;
ADDR_ENC  = 18'h14000;
ADDR_DEC  = 18'h28000;
HEX_FILE  = "image_320x240_rgb565.hex"; // chỉ dùng trong top.v
```

Parameter UART:

```verilog
TOTAL_PACKETS = 600;
PACKET_DATA_SIZE = 256 bytes; // cố định trong packet parser/writer
```

Parameter baud:

```verilog
OV_MAX_COUNT = 27; // baud_rate_gen.v, cấu hình hiện tại cho UART 115200 trên 50 MHz
```

## Source Chính Sau Rút Gọn

Quartus phần cứng thật chỉ dùng `quartus/AES4Img.qpf` và `quartus/AES4Img.qsf`. Source list này trỏ tới cây `top_de.v` và không include ROM/debug top.

Simulation chính dùng `sim/scripts/rtl_files.f` và `sim/scripts/modelsim_compile_functional.do`. Source list này include cả `top_de.v` và `top.v`, nhưng không include các profile đã loại bỏ.

Các file đã loại khỏi kiến trúc chính:

- `rtl/top_uart.v`: đã đổi vai trò thành `rtl/top_de.v`.
- `rtl/top_preloaded.v`: bỏ profile top riêng.
- `rtl/control/aes_image_demo_controller_preloaded.v`: không còn controller riêng.
- `rtl/uart/hex7seg.v`: không được gọi từ top chính.

`legacy/` và `legacy_uart/` vẫn còn trong repo, nhưng chỉ là archive tham khảo.
