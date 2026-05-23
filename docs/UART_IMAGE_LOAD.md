# UART/RS232 Image Load

Flow UART cho phép PC gửi ảnh 320x240 RGB565 vào external SRAM trước khi chạy AES. Đây là đường demo chính của `top_uart`.

## Tổng quan

```text
PC
  -> tools/send_image_packet_2.py
  -> UART 115200 8N1
  -> uart_controller
  -> uart_rx_packet_256
  -> uart_sram_packet_writer_320x240
  -> SRAM[ADDR_ORIG]
```

Sau khi đủ 600 packet hợp lệ, `image_loaded` bật lên. Controller chuyển sang `C_IDLE`, dashboard báo ảnh đã sẵn sàng, và người dùng có thể nhấn `KEY[1]` để chạy AES.

## Kích thước ảnh

```text
WIDTH             = 320
HEIGHT            = 240
FORMAT            = RGB565
TOTAL_BYTES       = 320 * 240 * 2 = 153600
PACKET_DATA_SIZE  = 256 bytes
TOTAL_PACKETS     = 153600 / 256 = 600
```

Mỗi packet chứa 256 byte, tương đương 128 pixel RGB565 hoặc 128 word SRAM 16-bit.

## Packet format

```text
HEADER : 0xAA
DATA   : 256 bytes
CRC8   : 1 byte
```

CRC8:

```text
Polynomial : 0x07
Initial    : 0xFF
Coverage   : DATA only
```

FPGA response:

```text
ACK  = 0x06
NACK = 0x15
```

Host script sẽ retry khi nhận NACK hoặc timeout ACK.

## Byte order

Python sender gửi mỗi pixel RGB565 theo thứ tự:

```text
high byte
low byte
```

FPGA writer lưu vào SRAM:

```verilog
sram_wdata <= {high_byte, low_byte};
```

Điểm này quan trọng vì byte order sai sẽ làm màu ảnh lệch hoặc nhiễu.

## Chạy bằng GUI

```bash
python -m pip install pillow pyserial tkinterdnd2
python tools/send_image_packet_2.py --gui
```

GUI hỗ trợ:

- Chọn hoặc kéo thả ảnh.
- Preview ảnh sau resize.
- Chọn COM port.
- Theo dõi packet progress.
- Log ACK/NACK/timeout.

## Chạy bằng CLI

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

Nếu đổi baudrate, phải cập nhật cả `BAUD` trong Python và generator baud trong RTL.

## Board flow

1. Reset board bằng `KEY[0]`.
2. FPGA xóa 3 vùng SRAM và chuyển sang wait image.
3. Gửi ảnh từ PC.
4. Chờ đủ 600 packet và dashboard báo image loaded.
5. Chọn mode bằng switch.
6. Nhấn `KEY[1]` để chạy AES.

Switch quan trọng:

| Switch | Ý nghĩa |
|---|---|
| `SW[0]` | `0=FAST`, `1=SLOW-L3` |
| `SW[1]` | `0=ENCRYPT`, `1=DECRYPT` |
| `SW[2]` | Auto encrypt rồi decrypt |
| `SW[5]` | Verify marker |
| `SW[6]` | Clear flags/reload marker |
| `SW[8]` | Bypass UART wait nếu SRAM ORIG đã được preload |

## Dashboard debug

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

## Thời gian load dự kiến

UART 115200 8N1 có payload lý thuyết khoảng 11,520 byte/s trước overhead ACK/NACK. Với ảnh 153,600 byte, thời gian thực tế thường khoảng 14-25 giây tùy adapter và driver.

## Module liên quan

- `rtl/top_uart.v`
- `rtl/control/aes_image_demo_controller_uart.v`
- `rtl/uart/uart_controller.v`
- `rtl/uart/uart_rx_packet_256.v`
- `rtl/uart/uart_sram_packet_writer_320x240.v`
- `rtl/uart/uart_image_loader_320x240.v`
- `rtl/sram/sram_arbiter_3m.v`
- `tools/send_image_packet_2.py`
