# v2.1 UART Refactor Notes

v2.1 thêm giai đoạn nạp ảnh qua UART/RS232 để demo phần cứng không cần internal ROM ảnh 320x240. Sau lần rút gọn kiến trúc, UART hardware top chính là `rtl/top_de.v`.

## Module Đang Giữ

```text
rtl/uart/baud_rate_gen.v
rtl/uart/uart_rx.v
rtl/uart/uart_tx.v
rtl/uart/uart_controller.v
rtl/uart/uart_rx_packet_256.v
rtl/uart/uart_sram_packet_writer_320x240.v
rtl/uart/uart_image_loader_320x240.v
rtl/sram/sram_arbiter_3m.v
rtl/control/aes_image_demo_controller_uart.v
rtl/top_de.v
```

`rtl/top_de.v` thay thế tên UART top cũ và là `TOP_LEVEL_ENTITY` trong `quartus/AES4Img.qsf`.

## Module VGA Được Mở Rộng

```text
rtl/vga/text_dashboard.v
rtl/vga/vga_quadrant_renderer_320x240.v
rtl/vga/vga_system_640x480.v
```

Các module VGA hiển thị thêm trạng thái UART loader, packet count, CRC và SRAM owner.

## Design Decision Chính

FPGA chờ PC gửi ảnh gốc vào external SRAM trước khi cho phép AES chạy:

```text
RESET
  -> CLEAR_SRAM
  -> WAIT_IMAGE_FROM_UART
  -> IMAGE_READY
  -> IDLE
  -> ENCRYPT / DECRYPT / AUTO
  -> DONE
```

Flow này thực tế hơn ROM nội bộ trên Cyclone II vì ảnh 320x240 RGB565 cần khoảng 1.23 Mbit.

## SRAM Priority

UART profile dùng `sram_arbiter_3m.v`:

```text
UART loader > AES DMA > VGA reader
```

Trong lúc load ảnh, UART giữ priority để ghi đủ packet. Trong fast AES mode, DMA giữ priority để không giảm throughput. VGA đọc ảnh khi hệ thống cho phép, đặc biệt hữu ích ở slow mode.

## Host Tool

`tools/send_image_packet_2.py` hỗ trợ cả GUI và CLI:

```bash
python tools/send_image_packet_2.py --gui
python tools/send_image_packet_2.py --path tools/test0.png --port COM3
```

Dependency:

```bash
python -m pip install pillow pyserial tkinterdnd2
```

## Protocol

```text
HEADER : 0xAA
DATA   : 256 bytes
CRC8   : poly 0x07, init 0xFF, DATA only
ACK    : 0x06
NACK   : 0x15
```

Ảnh có 153,600 byte nên cần đúng 600 packet.

## Giữ Nguyên

- AES encryption/decryption algorithm.
- AES datapath modules.
- Key demo mặc định.
- Address map 3 vùng SRAM.
- VGA 640x480 quadrant layout.

## Hướng Cải Tiến Tiếp Theo

- Thêm command UART readback để verify SRAM sau khi load.
- Thêm packet header chứa width/height/mode thay vì cố định 320x240.
- Thêm DMA compare pass để verify `DEC == ORIG` trên phần cứng.
- Tăng baudrate sau khi xác nhận timing và adapter ổn định.
- Thêm FIFO nếu UART clock domain tách khỏi system clock ở phiên bản sau.
