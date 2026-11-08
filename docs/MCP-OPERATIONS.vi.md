# Vận hành MCP ứng dụng trên máy hiện tại

Nguồn đã đọc: các launcher dưới `F:\Apps`, ngày 08/11/2026. Không sao chép các thông tin máy cụ thể này làm mặc định cho mọi dự án.

## Kiểm tra nhanh

```powershell
cd F:\Projects\AI-LOCAL
.\Test-Integrations.ps1
```

Lệnh chỉ đọc trạng thái: launcher tồn tại, cổng có listener, Ollama model đang nạp, ComfyUI queue, RAM trống. Kết quả ghi `integration-status.json`. Cổng mở không chứng minh đúng ứng dụng hoặc MCP tool gọi thành công; xác minh thêm bằng status/read-only tool trên ChatGPT.

Chạy launcher khi cần tác vụ ứng dụng (không phải tự động bật tất cả):

```powershell
.\Start-ProjectMcp.ps1 -App blender -WhatIf
.\Start-ProjectMcp.ps1 -App blender
.\Start-ProjectMcp.ps1 -App blockbench
.\Start-ProjectMcp.ps1 -App godot -ExpectedGodotProject 'F:\MyGodotGame\test-mcp'
```

Chỉ dùng Godot ví dụ trên khi thật sự làm việc với project đó. Script chặn nếu port 9876 đã bị chiếm hoặc Godot binding khác dự kiến; không sửa global binding. Launcher có thể chờ thao tác/key trong terminal, vì vậy lệnh chạy tương tác trong terminal người dùng thay vì khởi chạy ẩn.

## Blender

- Launcher: `F:\Apps\Blender-MCP-Quick-Launcher-Windows\Blender MCP.cmd`.
- Script thật hiện tại là `Start-Blender-MCP.ps1`, bản Unified KeyGuard v2. Không chọn nhầm file `Start-Blender-MCP-KeyGuard.ps1` chỉ vì tên giống bản mới.
- Profile: `blender-win`; command MCP được cấu hình: `uvx blender-mcp`.
- Socket addon trong Blender: `localhost:9876`. Đây không phải HTTP MCP endpoint.
- Tunnel executable: `F:\Projects\tunnel-client-v0.0.15-windows-amd64\tunnel-client.exe`.
- Key riêng Blender: `%APPDATA%\Blender-MCP-Quick-Launcher\runtime-key.dpapi`. Không đọc/xuất plaintext hay copy key giữa tài khoản Windows.

Thứ tự: mở Blender đúng file → N-panel / BlenderMCP → Start MCP Server → chạy launcher → xác nhận doctor và live tunnel không báo 401/403 → trong ChatGPT chọn Blender và gọi scene/status read-only. Trước khi thực hiện tạo/sửa model phải nhận đúng brief, xác nhận đối tượng và file output. Không dùng reset key làm phản xạ cho mọi lỗi.

Nếu launcher yêu cầu Runtime API key, người dùng nhập vào ô SecureString của launcher. Không yêu cầu gửi key qua chat. Nếu key hết hạn/sai quyền thì xử lý đúng thông báo; 403 khác với 401. Bộ kiểm tra không tự đọc các file DPAPI.

## Blockbench

- Launcher: `F:\Apps\Blockbench-MCP-Launcher\Blockbench MCP.cmd`.
- Script: `Start-MCP.ps1 -Profile blockbench-win -LocalPort 8787`.
- Cổng plugin app: 8787; launcher chờ local server, không tự cài plugin vào app.
- Store của launcher: `%APPDATA%\3D-MCP\runtime-api-key.dpapi`, khác với Blender KeyGuard.

Thứ tự: mở Blockbench → bật plugin/server MCP tương ứng → kiểm tra listener 8787 → launcher → ChatGPT gọi status/project read-only → khi có brief mới tạo asset. Ghi rõ model format, pivot, texture size, animation naming và export target. Không thay đổi file asset đang mở ở dự án khác.

## Godot

- Dùng bản launcher `F:\Apps\Godot-MCP-Quick-Launcher-Windows-v2`.
- Setup: `Setup Godot MCP.cmd`; chạy thường ngày: `Godot MCP.cmd`.
- Package trong setup đã kiểm tra: `@yanhuifair/godot-mcp@1.12.3`.
- Config người dùng: `%APPDATA%\3D-MCP\godot-mcp.json`.
- Binding hiện có là **`F:\MyGodotGame\test-mcp`**, không phải AI-LOCAL. Không chạy launcher rồi coi nó đang điều khiển AI-LOCAL.
- HTTP server theo config: `127.0.0.1:3000`; health `/health`, MCP `/mcp`.
- Editor bridge TCP 9876 khi plugin active; runtime bridge 9877 khi game chạy.

Triển khai project Godot khác: chọn thư mục thật có `project.godot`; kiểm tra/backup config và profile hiện tại trước khi thay binding. Cài addon theo setup đã đọc (`npx.cmd -y @yanhuifair/godot-mcp@1.12.3 --enable-plugin -p <PROJECT>`), rồi reload editor. Không chạy setup tương tác tự động với lựa chọn folder suy đoán.

Mỗi project nên có cấu hình launcher/profile riêng nếu cần sử dụng song song. Setup cũ hiện ghi config cấp người dùng và profile `godot-win`; chạy lại có thể đổi project cho mọi client đang dùng profile đó. Không thay global binding chỉ để “kiểm tra” dự án không có Godot.

Nghiệm thu: health HTTP đạt → tool đọc tên/path project đúng → liệt kê scene/node → chạy một scene test của chính dự án → kiểm tra debugger/runtime sau khi người dùng giao tác vụ. Chỉ health đạt chưa đủ để coi editor/runtime tools hoạt động.

## Xung đột cần xử lý

**Blender và Godot editor đều mặc định dùng TCP 9876.** Không bật hai addon bridge trên cùng địa chỉ/cổng. Trong bộ triển khai hiện tại dùng tuần tự. Muốn song song phải đổi đồng bộ cả server addon và client/MCP config, rồi nghiệm thu lại từng đầu. Không tự đổi một phía hoặc tắt/kill một app của dự án khác.

RAM/GPU cũng là tài nguyên dùng chung. Chỉ một tác vụ model nặng mỗi lần. Trước khi khởi động model local, xem ComfyUI queue. Các launcher ứng dụng có thể hiện prompt yêu cầu tương tác; không khởi chạy ẩn rồi coi như đã thành công. Nếu cần mở cửa sổ cho người dùng tương tác, phải nói rõ đó là launcher đang chờ họ.

## Cloud MCP và các bề mặt

Plugin trong ChatGPT không tự xuất hiện thành tool trong mọi chat Codex. Kiểm tra tool inventory của từng phiên. Nếu Codex cần tool trực tiếp, thêm đúng transport stdio/HTTP theo server docs và `codex mcp add --help`; không phỏng đoán endpoint từ tên app.

Lượt ChatGPT đầu tiên: nhận diện 28 tool Blender, 386 tool Godot, 71 tool Blockbench, nhưng status call trả `UNAVAILABLE — MCP SSE probe returned 429`. Đây là kết quả cụ thể của lượt thử, không phải chứng minh server hỏng vĩnh viễn hay key sai. Kiểm tra local listener trước; nếu local chưa chạy, mở đúng app/addon/launcher. Không retry dồn dập hoặc reset credentials để chữa 429.

Cloud services đã cài trong tài khoản phải được chọn theo tác vụ. Không tự bật mọi plugin, đồng bộ toàn bộ Drive/Notion, gửi email, push GitHub hoặc publish chỉ vì tên nằm trong danh sách đã cài.

## Phục hồi thiếu bộ nhớ ComfyUI

Đợt kiểm tra phát hiện ComfyUI Flux2 dùng 33,7 GB private memory, ảnh 896×1120, 50 bước; Windows pagefile dùng khoảng 10,4 GB. Không nhầm private commit với working set đang nằm hoàn toàn trong RAM.

Khi người dùng đồng ý dừng, đọc `/queue`, interrupt đúng prompt id, rồi `/free` với `unload_models=true,free_memory=true`. Xác minh running/pending về 0, RAM/GPU giảm. Nếu chỉ được hỏi “kiểm tra”, không tự hủy việc tạo ảnh từ trước. Không kill Python theo tên chung.

Trong đợt này API đã được xác minh từ `F:\Projects\ComfyUI\server.py`. Sau giải phóng: khoảng 22,3 GiB RAM trống, GPU 897 MiB, ComfyUI private memory khoảng 4,8 GiB. Tài liệu này không yêu cầu tự gọi interrupt như bước setup mặc định.
