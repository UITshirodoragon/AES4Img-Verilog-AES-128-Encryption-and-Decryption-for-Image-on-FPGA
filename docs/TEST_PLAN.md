# Test Plan

Tài liệu này gom các bước kiểm thử mô phỏng và phần cứng cho AES4Img.

## Functional simulation

Compile toàn bộ RTL và testbench:

```tcl
vsim -do sim/scripts/modelsim_compile_functional.do
```

Chạy self-test:

```tcl
vsim -do sim/scripts/run_all_selftests.do
```

Mở waveform DMA:

```tcl
vsim -do sim/scripts/wave_aes_dma.do
```

## Unit/self-check testbench

| Testbench | Mục tiêu |
|---|---|
| `tb_aes128_core_wrapper_selftest.v` | Kiểm tra AES-128 encrypt/decrypt bằng known-answer vector |
| `tb_sram_arbiter_selftest.v` | Kiểm tra grant VGA-only, DMA priority, DMA write và idle |
| `tb_image_loader_selftest.v` | Kiểm tra ROM loader ghi đúng dữ liệu vào SRAM |
| `tb_aes_sram_dma_320x240_selftest.v` | Kiểm tra DMA đọc 8 pixel, pack AES block, ghi 8 pixel |
| `tb_vga_timing_waveform.v` | Kiểm tra HS/VS/video_on/x/y/frame_tick |
| `tb_system_smoke_small.v` | Smoke test hệ thống rút nhỏ 16x2 |
| `tb_uart_rx_packet_256_selftest.v` | Kiểm tra parser packet 256 byte và CRC8 |
| `tb_uart_sram_packet_writer_selftest.v` | Kiểm tra writer biến 256 byte thành 128 word SRAM |

## AES known-answer vector

Wrapper hiện dùng vector AES-128 chuẩn:

```text
Key        = 2b7e151628aed2a6abf7158809cf4f3c
Plaintext  = 3243f6a8885a308d313198a2e0370734
Ciphertext = 3925841d02dc09fbdc118597196a0b32
```

Pass criteria:

- Encrypt output khớp ciphertext.
- Decrypt output khớp plaintext.
- `busy/done` có timing hợp lệ và không bị kẹt.

## UART simulation checklist

1. Gửi packet header `0xAA`.
2. Gửi đúng 256 payload byte.
3. Gửi CRC8 đúng và kiểm tra ACK `0x06`.
4. Gửi CRC8 sai và kiểm tra NACK `0x15`.
5. Kiểm tra writer ghép high byte/low byte thành đúng RGB565 word.
6. Kiểm tra `packet_count` tăng đúng sau mỗi packet hợp lệ.
7. Kiểm tra `image_loaded` bật sau 600 packet trong test mở rộng.

## Hardware test checklist

1. Compile `quartus/AES_128_v2_1_uart.qpf` với top-level `top_uart`.
2. Nạp `.sof` lên board.
3. Reset board bằng `KEY[0]`.
4. Mở UART GUI hoặc CLI và gửi `tools/test0.png`.
5. Quan sát dashboard:
   - UART packet count tăng.
   - CRC calc/recv hợp lệ.
   - Image loaded bật sau 600 packet.
6. Chạy fast encrypt:
   - `SW[0]=0`, `SW[1]=0`, nhấn `KEY[1]`.
   - Vùng `ENC` có dữ liệu nhiễu kiểu cipher.
7. Chạy fast decrypt:
   - `SW[1]=1`, nhấn `KEY[1]`.
   - Vùng `DEC` khôi phục gần ảnh gốc.
8. Chạy auto slow demo:
   - `SW[0]=1`, `SW[2]=1`, nhấn `KEY[1]`.
   - Quan sát ảnh hiện dần do DMA throttle.
9. Lặp lại với `tools/test1.png` và `tools/test2.png`.

## Timing simulation

Sau khi Quartus compile và tạo gate-level netlist:

1. Generate `.vo`.
2. Generate `.sdo`.
3. Cập nhật đường dẫn trong `sim/scripts/modelsim_compile_timing_template.do`.
4. Dùng SRAM model hoặc board-level testbench phù hợp.
5. Chạy simulation và kiểm tra không có violation nghiêm trọng ở clock 50 MHz.

## Regression criteria

Một thay đổi được xem là an toàn khi:

- Tất cả self-test functional pass.
- UART packet ACK/NACK đúng.
- AES known-answer vector pass cả encrypt và decrypt.
- Không thay đổi byte order RGB565.
- Address map `ADDR_ORIG/ADDR_ENC/ADDR_DEC` không bị lệch.
- Dashboard vẫn hiển thị được state, counter và owner.
- Website/README vẫn tham chiếu đúng ảnh trong `assets/`.
