# Lưu Ý Bộ Nhớ Cho Ảnh 320x240 RGB565

Ảnh 320x240 RGB565 có dung lượng:

```text
320 * 240 * 16 bit = 1,228,800 bit
320 * 240 * 2 byte = 153,600 byte
```

Chỉ riêng ảnh gốc đã cần khoảng 1.23 Mbit nếu đặt trong internal ROM/RAM FPGA. Với các board Cyclone II nhỏ, dung lượng M4K thường không đủ sau khi cộng thêm AES core, font ROM, UART, VGA và logic điều khiển.

## Profile A: ROM nội bộ

Dùng khi:

- Mô phỏng functional.
- FPGA có đủ internal RAM.
- Cần flow đơn giản, ảnh được build sẵn vào project.

Flow:

```text
image_320x240_rgb565.hex
  -> image_rom_320x240_rgb565
  -> image_loader_320x240
  -> SRAM[ADDR_ORIG]
```

Ưu điểm:

- Dễ mô phỏng.
- Không cần PC gửi ảnh qua UART.
- File HEX/MIF kiểm soát được dữ liệu đầu vào.

Nhược điểm:

- Có thể không fit trên Cyclone II vì ROM ảnh quá lớn.
- Mỗi lần đổi ảnh phải regenerate HEX/MIF và rebuild.

## Profile B: Preloaded external SRAM

Dùng khi:

- Có tool riêng để nạp external SRAM.
- Muốn bỏ toàn bộ ROM ảnh khỏi FPGA.

Flow:

```text
Control Panel / Flash / custom loader
  -> SRAM[ADDR_ORIG]
  -> top_preloaded
  -> AES encrypt/decrypt
```

Ưu điểm:

- Tiết kiệm internal RAM.
- Phù hợp board thật nếu đã có cơ chế nạp SRAM.

Nhược điểm:

- Cần công cụ preload bên ngoài.
- Repo không kiểm soát trực tiếp bước nạp ảnh.

## Profile C: UART live loader

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
  -> top_uart
```

Ưu điểm:

- Không cần ROM ảnh nội bộ.
- Đổi ảnh từ PC rất tiện.
- Có packet CRC8, ACK/NACK và dashboard debug.

Nhược điểm:

- 115200 baud mất khoảng 14-25 giây cho một ảnh 153,600 byte.
- Cần pyserial/Pillow trên PC.

## Khuyến nghị

- Dùng `top_uart` cho demo phần cứng thật.
- Dùng `top.v` và ROM HEX cho simulation hoặc smoke test.
- Giữ file `image_320x240_rgb565.hex/.mif` làm mẫu, nhưng không phụ thuộc vào ROM nội bộ khi board báo thiếu RAM.
- Không commit các thư mục build Quartus như `quartus/db/`, `quartus/incremental_db/`, `quartus/output_files/`.
