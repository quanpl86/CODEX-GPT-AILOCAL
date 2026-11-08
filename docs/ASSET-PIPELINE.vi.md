# Luồng Agent tạo asset 2D/3D cho web board game

## Vai trò khi nhận một yêu cầu

1. **ChatGPT / Art planner:** chốt phong cách, danh sách asset, chức năng trong game và tiêu chí hình thức. Mỗi asset có ID và task riêng.
2. **Codex / Operator & integrator:** xác định đúng root dự án; tạo các thư mục từ manifest; kiểm tra tài nguyên; gọi Ensure-ProjectService để mở app/plugin và transport cần thiết. Không mở mọi app theo mặc định.
3. **ChatGPT / MCP operator:** sau khi status xác nhận đúng ứng dụng/project, dùng Blockbench hoặc Blender để tạo/chỉnh asset theo brief. Không sửa source gameplay và không thay file khác ngoài asset được giao.
4. **Người dùng / Art approval:** xem preview, duyệt hình thức và nhập API/key tại ứng dụng/launcher khi thật sự cần. Agent không yêu cầu gửi key qua chat và không tự dùng dịch vụ tạo model tính phí ngoài phạm vi đã cho phép.
5. **Codex / Asset QA:** xác minh file nguồn và export có thật, đúng path/format/size; kiểm tra pivot, scale, texture, animation, polycount/draw-call budget theo brief. Chạy import và gameplay trên Chrome bên ngoài, kiểm tra console/network/loading và hiệu năng.
6. **AI local / Code implementer:** viết loader/component/game logic theo contract asset được chốt. Codex review/test và trả report cho local sửa.

## Cấu trúc thư mục mẫu

```text
<project>/
  art/source/blender/<asset-id>/        # .blend nguồn
  art/source/blockbench/<asset-id>/     # .bbmodel nguồn
  art/previews/<asset-id>/              # ảnh xem trước, chưa coi là file gốc
  art/briefs/<asset-id>.md              # brief và acceptance
  public/assets/2d/<asset-id>/          # PNG/WebP/SVG đã export
  public/assets/3d/<asset-id>/          # GLB/glTF và texture liên quan
  assets.manifest.json                  # ID -> URL, version, license, budget
```

Đây là mẫu cho web app phục vụ public assets; nếu framework hiện tại có pipeline import khác, map manifest sang cấu trúc đó thay vì thêm một hệ thống song song. Không dùng đường dẫn tuyệt đối máy tác giả trong mã web. Giữ file source ngoài public, chỉ export được duyệt mới đưa vào runtime.

## Contract giao ChatGPT trước khi gọi MCP

```text
TASK: asset-knight-001
Workspace: <verified project root>
Application: Blockbench (blocky) hoặc Blender (mesh/render)
Source file: <absolute project-contained source path>
Export file: <absolute project-contained GLB/PNG path>
Style: <approved palette, silhouette, materials, reference>
Units/pivot/orientation: <explicit convention compatible with game>
Budget: <triangles, texture resolution, animations, export size>
Acceptance: <visual approval + technical/runtime checks>
Writer: ChatGPT via this application's verified MCP only
Integrator/reviewer: Codex
```

Một asset chỉ có một writer tại một thời điểm. Export vào tên/version mới hoặc staging khi file đang dùng trong game; Codex review rồi promote. Không overwrite asset đã duyệt mà chưa có task thay thế. Ghi license và nguồn của asset bên ngoài; kết quả từ API ngoài phải có định dạng/đường dẫn thật, không lấy screenshot làm asset.

## Cách gọi bộ khởi động

```powershell
./Ensure-ProjectService.ps1 -Service blender -StartTransport
./Ensure-ProjectService.ps1 -Service blockbench -StartTransport
./Ensure-ProjectService.ps1 -Service godot -ExpectedGodotProject '<exact project root>' -StartTransport
```

Agent tiếp theo đọc kết quả: `local_ready` chỉ xác nhận local; transport `started_unverified` chưa phải remote authenticated. Sau đó gọi status/read-only bằng MCP. Nếu remote lỗi, không tạo model và không đổi project để thử chữa.

Ollama được Ask-Local khởi động theo nhu cầu trước inference; API key tạo asset không liên quan tới Ollama. Một task dùng Blender không mặc định phải trả tiền API: mesh thủ công qua addon có thể không cần API tạo sinh. Nếu người dùng chọn dịch vụ tạo sinh, họ nhập credential tại đúng nơi và giới hạn chi phí phải rõ.

## Trạng thái và handoff

`planned -> app_starting -> local_ready -> remote_verified -> creating -> needs_visual_approval -> exported -> technical_verified -> integrated -> accepted`

Khi chờ API/consent/duyệt hình thức: ghi `waiting_user`, không đánh dấu done. Handoff gồm task ID, writer, source/export path, phiên bản, preview, checks đã chạy và việc cần làm. Cập nhật work board khi đổi trạng thái; không cần gọi ChatGPT review lại cho mỗi lần chỉnh nhỏ đã nằm trong brief.

Mốc kiểm tra hiện tại: Blender tự mở + transport + remote addon status đã thành công. Blockbench tự mở local/transport đã kiểm tra; remote cần kiểm tra riêng. Godot không được mở project mẫu cũ để chứng minh thành công cho dự án khác.
