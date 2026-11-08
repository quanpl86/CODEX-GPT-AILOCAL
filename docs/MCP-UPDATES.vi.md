# Kiểm tra cập nhật và tự mở MCP — 08/11/2026

| Thành phần | Trước | Sau | Xác minh |
|---|---|---|---|
| Blender MCP | Server/addon đang dùng | Server 2.2.7, addon 1.8/protocol 15 | Updater dry-run báo mới nhất; remote get_addon_status thành công, Blender 5.2.1 LTS |
| Blockbench MCP | 0.3.1, checkout có lockfile sửa local | Runtime/plugin 0.4.0 tại F:/Apps/Blockbench-MCP-Runtime-0.4.0 | 125 tests pass; dependency audit sau bản sửa tương thích: 0; installed plugin hash khớp runtime |
| Godot MCP | 1.12.3 | Server pin 1.12.18 | npm registry và CLI --version/--help đạt; launcher/profile chuyển sang stdio |

Blockbench runtime cũ được giữ nguyên. Source mới ở upstream commit b024728b396691772d273b1d6b12960ce3d30c02; dependency lock runtime được cập nhật theo npm audit fix (không force), sau đó build và 125 tests chạy lại đạt. Không coi audit 0 là đảm bảo không có lỗi bảo mật.

Plugin Blockbench đã được backup trước khi copy; cửa sổ do phiên này mở chỉ được đóng để reload sau khi status xác nhận không có project. Profile chuyển từ checkout cũ sang runtime mới. HTTP local status/ping đạt, nhưng remote MCP status vẫn trả 429 ở lượt kiểm tra cuối; đây chưa phải nghiệm thu remote thành công.

Godot 1.12.18 yêu cầu token cho HTTP transport. Profile đã chuyển sang stdio version pin thay vì tắt auth hoặc nhúng token. Cả hai Start-Godot-MCP.ps1 dưới F:/Apps gọi bộ Ensure-ProjectService hiện tại, đọc binding có sẵn và truyền expected project rõ ràng. Script cũ và profile/config đã có backup timestamp. Project F:/MyGodotGame/test-mcp không được mở/chỉnh scene hay ghi đè addon chỉ để test setup này. Addon trong project đó chưa được nghiệm thu với server mới; kiểm tra/cập nhật khi có task vào đúng project.

Launcher là script local, không có kho phát hành chung để so “latest launcher”. Thay đổi launcher được ghi theo phiên triển khai và sao lưu; version mới nhất của MCP phải đối chiếu npm/PyPI/upstream chính thức mỗi lần cập nhật.

## Tự mở theo nhu cầu

```powershell
./Ensure-ProjectService.ps1 -Service ollama
./Ensure-ProjectService.ps1 -Service blender -StartTransport
./Ensure-ProjectService.ps1 -Service blockbench -StartTransport
./Ensure-ProjectService.ps1 -Service godot -ExpectedGodotProject '<registered root>' -StartTransport
```

Không tự mở tất cả lúc đăng nhập Windows. Bộ khởi động dùng file lock để tuần tự hóa startup, receipt PID + creation ticks + executable để tái sử dụng ứng dụng đã mở, và timeout chờ readiness. Không kill tiến trình khác hoặc đổi project để chiếm port. Window khởi động mặc định hidden; agent có thể đưa app ra trước khi người dùng cần xem/duyệt.

Transport dùng credential DPAPI đã lưu, chỉ đưa plaintext vào environment của tiến trình con và không in ra command line/log. Thiếu hoặc không giải mã được key trả needs_credentials; người dùng nhập qua launcher tương tác cũ. Không tự reset key. Health ports tách 8080/8081/8082 cho Blender/Blockbench/Godot. Cổng editor Blender/Godot 9876 vẫn phải dùng tuần tự.

`local_ready` không chứng minh remote auth hay đúng scene; `started_unverified` không phải task done. Agent phải gọi status/read-only MCP và xác minh project/output contract trước khi tạo asset. Startup thành công không tự tạo thư mục/output của dự án khác.

## Nguồn đã kiểm tra

- https://pypi.org/project/mcp-for-blender/
- https://github.com/sosadly/blockbench-mcp
- https://github.com/yanhuifair/Godot-MCP
- npm metadata @yanhuifair/godot-mcp 1.12.18 và CLI của package.

## Rollback

Các file đã thay có `.backup-<timestamp>` tại vị trí cũ; restore đúng file/profile khi transport đã được dừng có chủ đích. Không restore bằng cách xóa mọi config. Runtime Blockbench cũ chưa bị reset/pull đè; profile backup giữ đường dẫn cũ. Godot config backup giữ package pin 1.12.3. Kiểm tra remote tool lại sau rollback.
