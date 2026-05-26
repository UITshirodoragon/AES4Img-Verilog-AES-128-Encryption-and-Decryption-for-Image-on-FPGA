# UART/RS232 Image Load

Flow UART cho phép PC gửi ảnh 320x240 RGB565 vào external SRAM trước khi chạy AES. Đây là đường demo phần cứng chính của `top_de`.

## Tổng Quan

```text
PC
  -> tools/send_image_packet_2.py
  -> UART 115200 8N1
  -> uart_controller
  -> uart_rx_packet_256
  -> uart_sram_packet_writer_320x240
  -> SRAM[ADDR_ORIG]
  -> AES DMA/VGA qua top_de
```

Sau khi đủ 600 packet hợp lệ, `image_loaded` bật lên. Controller chuyển sang `C_IDLE`, dashboard báo ảnh đã sẵn sàng, và người dùng có thể nhấn `KEY[1]` để chạy AES.

## Kích Thước Ảnh

```text
WIDTH             = 320
HEIGHT            = 240
FORMAT            = RGB565
TOTAL_BYTES       = 320 * 240 * 2 = 153600
PACKET_DATA_SIZE  = 256 bytes
TOTAL_PACKETS     = 153600 / 256 = 600
```

Mỗi packet chứa 256 byte, tương đương 128 pixel RGB565 hoặc 128 word SRAM 16-bit.

## Packet Format

```text
HEADER : 0xAA
DATA   : 256 bytes
CRC8   : 1 byte
ACK    : 0x06
NACK   : 0x15
```

CRC8:

```text
Polynomial : 0x07
Initial    : 0xFF
Coverage   : DATA only
```

Host script retry khi nhận NACK hoặc timeout ACK.

## Byte Order

Python sender gửi mỗi pixel RGB565 theo thứ tự:

```text
high byte
low byte
```

FPGA writer lưu vào SRAM:

```verilog
sram_wdata <= {high_byte, low_byte};
```

Byte order sai sẽ làm màu ảnh lệch hoặc nhiễu.

## Chạy Bằng GUI

```bash
python -m pip install pillow pyserial tkinterdnd2
python tools/send_image_packet_2.py --gui
```

GUI hỗ trợ chọn ảnh, preview resize, chọn COM port, theo dõi packet progress và log ACK/NACK/timeout.

## Chạy Bằng CLI

Windows:

```bash
python tools/send_image_packet_2.py --path tools/test0.png --port COM3
```

Linux:

```bash
python3 tools/send_image_packet_2.py --path tools/test0.png --port /dev/ttyUSB0
```

Tùy chỉnh baudrate:

```bash
python tools/send_image_packet_2.py --path tools/test0.png --port COM3 --baud 115200
```

Nếu đổi baudrate, phải cập nhật cả Python sender và `rtl/uart/baud_rate_gen.v`.

## Board Flow

1. Compile/nạp `quartus/AES4Img.qpf` với `TOP_LEVEL_ENTITY=top_de`.
2. Reset board bằng `KEY[0]`.
3. FPGA xóa 3 vùng SRAM và chuyển sang wait image.
4. Gửi ảnh từ PC.
5. Chờ đủ 600 packet và dashboard báo image loaded.
6. Chọn mode bằng switch.
7. Nhấn `KEY[1]` để chạy AES.

Switch quan trọng:

| Switch | Ý nghĩa |
|---|---|
| `SW[0]` | `0=FAST`, `1=SLOW-L3` |
| `SW[1]` | `0=ENCRYPT`, `1=DECRYPT` |
| `SW[2]` | Auto encrypt rồi decrypt |
| `SW[5]` | Verify marker |
| `SW[6]` | Clear flags/reload marker |
| `SW[8]` | Bypass UART wait nếu SRAM ORIG đã được preload |

## Dashboard Debug

Dashboard VGA hiển thị các trường debug từ UART profile:

- System state.
- DMA state.
- AES wrapper state.
- SRAM owner.
- UART packet count.
- UART packet parser state.
- SRAM writer state.
- CRC calculated/received.
- UART flags.

Nếu ảnh không load được, kiểm tra trước:

- COM port đúng chưa.
- Baudrate có khớp 115200 không.
- UART RX/TX có bị đấu ngược không.
- FPGA đã reset sau khi mở UART chưa.
- Dashboard có tăng packet count không.
- Log PC có ACK hay toàn timeout/NACK.

## Thời Gian Load Dự Kiến

UART 115200 8N1 có payload lý thuyết khoảng 11,520 byte/s trước overhead ACK/NACK. Với ảnh 153,600 byte, thời gian thực tế thường khoảng 14-25 giây tùy adapter và driver.

## Module Liên Quan

- `rtl/top_de.v`
- `rtl/control/aes_image_demo_controller_uart.v`
- `rtl/uart/uart_controller.v`
- `rtl/uart/uart_rx_packet_256.v`
- `rtl/uart/uart_sram_packet_writer_320x240.v`
- `rtl/uart/uart_image_loader_320x240.v`
- `rtl/sram/sram_arbiter_3m.v`
- `tools/send_image_packet_2.py`
