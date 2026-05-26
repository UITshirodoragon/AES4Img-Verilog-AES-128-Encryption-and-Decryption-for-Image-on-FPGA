# Refactor Notes

Tài liệu này ghi lại quyết định rút gọn kiến trúc AES4Img.

## Quyết Định Đã Chốt

Project chính chỉ giữ 2 top-level:

| Top | Vai trò |
|---|---|
| `rtl/top_de.v` | Top phần cứng để compile/nạp kit DE2 |
| `rtl/top.v` | Top cho smoke-test, testbench và debug |

`legacy/` và `legacy_uart/` vẫn được giữ trong repo để tham khảo, nhưng không compile và không ảnh hưởng project chính.

## Thay Đổi Chính

- Đổi Quartus project chính thành `quartus/AES4Img.qpf`.
- Đổi `TOP_LEVEL_ENTITY` thành `top_de`.
- Tách rõ `top_de.v` cho board thật và `top.v` cho mô phỏng/debug.
- Thêm parameter cho `top.v` để testbench có thể rút nhỏ `IMG_W`, `IMG_H`, `ADDR_*`, `HEX_FILE`.
- Cập nhật `tb_system_smoke_small.v` để instantiate `top` thay vì gọi trực tiếp controller.
- Cập nhật ModelSim source list để chỉ include các module còn thuộc kiến trúc chính.

## File Đã Loại Khỏi RTL Chính

Các file sau đã được bỏ khỏi `rtl/` active vì không còn nằm trong cây reachable từ 2 top chính:

- `rtl/top_uart.v`: vai trò đã được thay bằng `rtl/top_de.v`.
- `rtl/top_preloaded.v`: bỏ profile top riêng.
- `rtl/control/aes_image_demo_controller_preloaded.v`: bỏ controller preloaded riêng.
- `rtl/uart/hex7seg.v`: không còn được gọi từ top chính.

## File Vẫn Giữ

Các module sau vẫn cần thiết:

- `rtl/control/aes_image_demo_controller_uart.v`: controller phần cứng cho `top_de`.
- `rtl/control/aes_image_demo_controller.v`: controller ROM/debug cho `top`.
- `rtl/dma/aes_sram_dma_320x240.v`: DMA AES/SRAM dùng chung.
- `rtl/dma/image_loader_320x240.v`: ROM-to-SRAM loader cho `top`.
- `rtl/rom/image_rom_320x240_rgb565.v`: ROM test/debug cho `top`.
- `rtl/sram/sram_arbiter_3m.v`: arbiter UART + DMA + VGA cho `top_de`.
- `rtl/sram/sram_arbiter.v`: arbiter DMA + VGA cho `top`.

## Quartus Project Chính

Project chính:

```text
quartus/AES4Img.qpf
quartus/AES4Img.qsf
quartus/AES4Img.sdc
```

`quartus/AES4Img.qsf` chỉ include source cần cho flow phần cứng `top_de`. Nó không include ROM debug top, preloaded profile, hay thư mục legacy.

## Simulation Project Chính

Simulation vẫn include cả 2 top:

```text
rtl/top.v
rtl/top_de.v
```

Source list chính:

```text
sim/scripts/rtl_files.f
sim/scripts/modelsim_compile_functional.do
```

## Legacy Policy

`legacy/` và `legacy_uart/` là archive. Quy định:

- Không xóa.
- Không đưa vào Quartus QSF chính.
- Không đưa vào ModelSim compile script chính.
- Không tham chiếu từ tài liệu kiến trúc hiện tại như một phần active design.
- Chỉ dùng khi cần đối chiếu code cũ.
