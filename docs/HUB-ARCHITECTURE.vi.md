# Dự án tổng: AI Delivery Hub

## Phân lớp

1. **Governance ở hub:** role/rule, skill có version, model routing, MCP lifecycle, chuẩn QA/UI/CI và hướng dẫn triển khai. Thay đổi quy trình là task riêng, có review/test, không sửa ngầm khi làm một feature dự án con.
2. **Danh mục dự án:** hub/projects.json (local, không public) ghi ID, root tuyệt đối hoặc root tương đối registry, loại dự án, agent được dùng và MCP được gắn. ID không phải đường dẫn tùy ý từ model. Root dự án không được là cả ổ đĩa.
3. **Execution ở dự án con:** source, dependency, secrets, kế hoạch/task, asset manifest, source/export asset và tests nằm ở đúng project. Không cần di chuyển repository hiện có vào hub; registry hỗ trợ cả thư mục con và repository ở vị trí khác.
4. **Adapter theo công cụ:** Codex có thể nhận task ở đúng working directory; ChatGPT dùng Project/connector riêng; local nhận allowlist/context và trả proposal; Antigravity nhận handoff trong workspace đúng. Chưa có adapter/API được kiểm chứng thì handoff thủ công, không gọi một CLI giả hoặc dùng browser như API model ngầm.

## Đăng ký dự án

Copy hub/projects.example.json thành hub/projects.json. Mỗi project có id duy nhất, root đúng, kind (web/app/media/learning/game/toolkit), enabled, agents và danh sách MCP cần thiết. Không chứa API key, token, cookie hoặc mật khẩu trong registry. Với dự án đã có, đọc quy tắc và xác minh Git/root trước khi đăng ký.

```powershell
./Resolve-HubProject.ps1 -ProjectId my-board-game
./New-HubTask.ps1 -ProjectId my-board-game -Mode implement -Agent codex `
  -Domain game -Complexity medium -Goal 'Thêm luật di chuyển và kiểm thử'
./New-HubTask.ps1 -ProjectId my-board-game -Mode asset -Agent chatgpt `
  -Domain game -Goal 'Tạo quân cờ theo brief đã duyệt'
```

New-HubTask tạo hồ sơ giao việc ở hub/tasks, không tự khởi chạy agent/model hoặc chỉnh source. Đây là điểm xuất phát cho agent điều phối trong chat hiện tại. Nó phải đọc handoff, chuyển working root, đọc AGENTS.md và kế hoạch tại project đích rồi mới thực hiện. Task hỏi đáp dùng mode ask: chỉ đọc.

Không tự spawn nhiều agent hoặc tạo chat mới chỉ vì registry có nhiều agent. Muốn song song phải có task độc lập, writer/file rõ và công cụ/ủy quyền tương ứng. Không để hai IDE/agent cùng ghi một branch/file mà không có cô lập được kiểm chứng.

## Ví dụ board game có 2D/3D

Người dùng yêu cầu -> hub xác định project ID -> ChatGPT chốt game/art brief -> Codex tạo cây art/source và public/assets theo stack dự án -> Codex mở Blender/Blockbench và MCP -> ChatGPT gọi tool tạo asset đúng path -> người dùng duyệt/nhập API khi cần -> Codex kiểm tra export/import -> local viết loader/gameplay -> Codex test thực tế Chrome -> ChatGPT review milestone khi có rủi ro hoặc cần quyết định lớn. Chi tiết ở ASSET-PIPELINE.vi.md.

MCP phải được gắn đúng project, không chỉ đúng tên app. Có thể dùng chung tiến trình dịch vụ, nhưng trước mỗi task phải đọc active document/project. Godot có global binding cũ thì chặn khi khác project. Media/học liệu cũng dùng output contract và thư mục riêng; không copy dữ liệu học sinh hoặc credentials vào prompt/log.

## Quy tắc đồng bộ

- Hub giữ version và nguồn chuẩn, mỗi project ghi version đã áp dụng và các override hợp lệ.
- Ưu tiên: yêu cầu người dùng và chính sách công cụ -> quy tắc phạm vi project -> contract hub phù hợp -> skill tác vụ. Quy tắc có xung đột thực phải báo, không tự bỏ kiểm tra.
- Cập nhật skill/model/MCP là thay đổi có version, backup, kiểm tra tương thích, test trước rollout và migration notes. Không tự ghi đè AGENTS.md do người dùng sửa; installer có marker/backup.
- secrets/state/registry thật nằm local hoặc credential store; Git chứa template và mã quy trình. Chi phí cloud/model được ghi theo task nếu công cụ có số liệu; không suy ra tiền từ token khi chưa biết giá/gói.
- Board tổng giữ phase, phụ thuộc, trạng thái các dự án; board con giữ chi tiết implementation. Handoff có task ID/project/root/role/evidence/next action. Không giả lập tiến độ của agent chưa thực sự chạy.

## Mức triển khai hiện tại

Đã có kiểm tra registry/root, task package và contract chung. Chỉ AI-LOCAL được đăng ký mặc định. Chưa tự đăng ký các repository khác hoặc điều khiển Antigravity khi chưa xác minh giao diện của nó. Để onboard một dự án thật, cung cấp root/ID/loại và nguồn output mong muốn; agent kiểm tra tại chỗ rồi mới mở quyền và kết nối riêng.

### Web HUB 0.3 preview

Web local tại 127.0.0.1:8765 dùng cùng registry/resolver và các helper hiện có. Tạo dự án mới bằng New-ManagedProject dưới workspace/category/ID; không chứa source dự án con trong repo governance. UI hiển thị board, lịch sử và báo cáo; chạy chat hoặc local staging theo action allowlist. Codex/Antigravity/local đã có lượt trả lời qua adapter; OpenAI API cần key/model. MCP cloud của ChatGPT không tự chuyển sang backend web. Chrome và isolation review còn chờ; chưa coi HUB là tự động toàn bộ/production. Xem HUB-WEB.vi.md để cài và tiếp nhận các gate còn mở.
