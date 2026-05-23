# Refactor Notes

Repo này đã được tổ chức lại để tách rõ AES core, DMA, SRAM, VGA, UART và top-level profiles. Phần refactor giữ nguyên thuật toán AES gốc, chỉ bọc lại và ghép hệ thống theo kiến trúc dễ mô phỏng hơn.

## Được giữ lại

- `aes_encryption_core.v`
- `aes_decryption_core.v`
- Các khối AES datapath gốc:
  - `Sbox_8bits.v`
  - `Inv_Sbox_8bits.v`
  - `SubBytes.v`
  - `InvSubBytes.v`
  - `ShiftRows.v`
  - `InvShiftRows.v`
  - `MixColumns.v`
  - `Inv_MixColumns.v`
  - `KeyExpansion.v`
  - `InvKeyExpansion.v`
  - `rcon_gen.v`
- Khóa demo mặc định `2b7e151628aed2a6abf7158809cf4f3c`.
- Thư mục `legacy/` để đối chiếu source ban đầu.

## Đã thay đổi về tổ chức hệ thống

- Không dùng một `MasterController` lớn gộp VGA/SRAM/AES như kiến trúc cũ.
- Thêm `aes128_core_wrapper.v` để chuẩn hóa core AES thành IP có `start`, `busy`, `done`.
- Thêm `aes_sram_dma_320x240.v` để xử lý ảnh theo block 8 pixel.
- Thêm SRAM arbiter để tách quyền truy cập SRAM giữa các master.
- Thêm VGA dashboard 320x240 ở góc trên phải.
- Thêm profile ROM, preloaded SRAM và UART live loader.
- Thêm testbench self-checking cho AES wrapper, DMA, SRAM arbiter, UART packet và smoke test hệ thống.

## Các profile hiện tại

| Profile | Top-level | Mục tiêu |
|---|---|---|
| ROM | `rtl/top.v` | Simulation hoặc FPGA đủ RAM nội bộ |
| Preloaded | `rtl/top_preloaded.v` | External SRAM đã có ảnh gốc |
| UART | `rtl/top_uart.v` | Demo thật với PC gửi ảnh qua UART |

## v2.1 UART upgrade

v2.1 thêm đường load ảnh từ PC:

```text
PC image
  -> UART packet 256 byte + CRC8
  -> FPGA ACK/NACK
  -> SRAM[ADDR_ORIG]
  -> AES DMA
```

Các module chính được thêm:

- `rtl/uart/baud_rate_gen.v`
- `rtl/uart/uart_rx.v`
- `rtl/uart/uart_tx.v`
- `rtl/uart/uart_controller.v`
- `rtl/uart/uart_rx_packet_256.v`
- `rtl/uart/uart_sram_packet_writer_320x240.v`
- `rtl/uart/uart_image_loader_320x240.v`
- `rtl/sram/sram_arbiter_3m.v`
- `rtl/control/aes_image_demo_controller_uart.v`
- `rtl/top_uart.v`

## Điểm cần chú ý khi compile thật

1. `top_uart` là top-level khuyến nghị cho phần cứng thật.
2. `top.v` dùng ROM ảnh 320x240, có thể không fit trên Cyclone II.
3. Nếu dùng ROM và Quartus không infer đúng `$readmemh`, có thể cần thay bằng altsyncram/MIF.
4. QSF chính cho UART là `quartus/AES_128_v2_1_uart.qsf`.
5. ModelSim cần compile theo thứ tự trong `sim/scripts/modelsim_compile_functional.do`.
6. `verify_pass` hiện là marker; verify đầy đủ nên làm bằng testbench hoặc thêm compare DMA.

## Những gì không nên commit lên GitHub

Các thư mục build/output nên để local:

- `quartus/db/`
- `quartus/incremental_db/`
- `quartus/output_files/`
- `quartus/simulation/modelsim/`
- `work/`
- `transcript`
- `*.wlf`, `*.vcd`, `*.sof`, `*.pof`, `*.rpt`, `*.summary`
- `__pycache__/`

`.gitignore` đã được cập nhật để tránh push các artifact này trong các lần sau.
