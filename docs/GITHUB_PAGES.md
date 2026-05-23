# GitHub Pages Setup

Repo đã có static website ở root để publish bằng GitHub Pages.

## File website

```text
index.html
styles.css
script.js
.nojekyll
assets/
docs/
```

Website dùng ảnh trong `assets/`. Quy ước tên ảnh hiện tại:

```text
screenshot_test0.png
screenshot_test1.png
screenshot_test2.png
vgashot_test0_load.jpg
vgashot_test0_encrypt.jpg
vgashot_test0_decrypt.jpg
vgashot_test1_load.jpg
vgashot_test1_encrypt.jpg
vgashot_test1_decrypt.jpg
vgashot_test2_load.jpg
vgashot_test2_encrypt.jpg
vgashot_test2_decrypt.jpg
```

Nếu thêm test mới, nên giữ cùng pattern:

```text
screenshot_testN.png
vgashot_testN_load.jpg
vgashot_testN_encrypt.jpg
vgashot_testN_decrypt.jpg
```

Sau đó cập nhật `script.js` để gallery biết test mới.

## Publish bằng GitHub Actions

Workflow đã chuẩn bị:

```text
.github/workflows/pages.yml
```

Các bước:

1. Push repo lên GitHub.
2. Vào `Settings -> Pages`.
3. Ở `Build and deployment`, chọn `Source: GitHub Actions`.
4. Push vào branch `main` hoặc `master`, hoặc bấm `Run workflow`.
5. Website sẽ được publish từ artifact `_site` gồm HTML/CSS/JS, `assets/` và `docs/`.

## Publish thủ công từ branch

Nếu không dùng Actions:

1. Vào `Settings -> Pages`.
2. Chọn `Deploy from a branch`.
3. Chọn branch chính và folder `/ (root)`.
4. GitHub Pages sẽ đọc trực tiếp `index.html` ở root.

## Xem thử local

Website là static thuần, có thể mở trực tiếp:

```text
index.html
```

Hoặc chạy một server bất kỳ nếu muốn kiểm tra URL tương tự production:

```bash
python -m http.server 8080
```

Sau đó mở:

```text
http://localhost:8080
```
