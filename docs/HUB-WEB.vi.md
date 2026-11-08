# Web HUB AI — triển khai và vận hành

Bản hiện tại 0.4 có coding workflow, auto-repair/apply theo lựa chọn, source/board editor, encrypted API setup và web starter/preview. Quy trình sử dụng hiện hành: [HUB-OPERATIONS.vi.md](HUB-OPERATIONS.vi.md). Các ghi nhận smoke 0.3 bên dưới là lịch sử, không thay trạng thái nghiệm thu mới nhất trong WORK-BOARD.md.

## Mở HUB

Yêu cầu Windows, PowerShell 7 (`pwsh`), Node.js 22 trở lên; không cần npm install hoặc Docker. Dùng checkout HUB, không chạy một bản kit trong dự án con làm HUB thứ hai.

Trên máy/checkout mới, tạo `hub/projects.json` từ `hub/projects.example.json` (chỉ khi chưa có), kiểm tra root/ID; tạo `integrations.json` từ template và sửa executable/binding đúng máy. Kiểm tra `hub/layout.json` trỏ đúng ổ thư mục muốn dùng rồi chạy `Initialize-ManagedWorkspace.ps1`. Không ghi đè registry/config thật khi nâng cấp. Copy `hub/web-config.example.json` sang `hub/web-config.json` nếu muốn model hỏi đáp Codex đã chọn; xác minh model còn được tài khoản hỗ trợ. Không copy secrets hoặc connector của máy/dự án khác. Tài khoản và pairing C2C vẫn phải thiết lập chính thức riêng.

1. Từ thư mục HUB, chạy `pwsh -NoProfile -File Start-HubWeb.ps1` hoặc nhấp `Open-Hub.cmd`.
2. Mở `http://127.0.0.1:8765`. Launcher mở Chrome nếu đã cài. Server chạy ẩn, không cần giữ terminal.
3. Launcher nhận diện HUB đang chạy; không mở thêm listener trên cùng cổng. Port khác: `-Port 8766`.
4. Dịch vụ không tự chạy lúc Windows khởi động. Không có tunnel/public hosting cho dashboard. Không mở port ra LAN/Internet: bản này phục vụ một người dùng trên máy, chưa có đăng nhập đa người dùng.
5. Khi nâng cấp server, xác định đúng PID Node có command line `web/server.mjs` thuộc checkout này, dừng riêng PID đó rồi chạy launcher. Không kill tất cả Node/Ollama/ComfyUI. Lượt đang chạy chuyển thành interrupted sau restart, không tự chạy lại.

## Các luồng làm việc

- **Phòng điều phối:** chọn dự án và AI, nhập câu hỏi, gửi. HUB gắn quy tắc/board của đúng dự án, kèm tối đa bốn lượt gần nhất. Đây là ngữ cảnh rút gọn, không phải toàn repository. Mỗi project/agent có lịch sử riêng. Câu hỏi local quá giới hạn 12000 ký tự cả context bị từ chối, không cắt câu hỏi.
- **Giao việc:** chọn domain/độ khó/rủi ro, tạo nhiệm vụ bàn giao từ nội dung đã nhập. `hub/tasks/.../task.json` và `handoff.md` lưu root/route/owner. Tạo bàn giao không tự chạy agent. Codex tiếp nhận bàn giao để review/apply/test/release theo quy trình.
- **Local viết mã vào staging:** rủi ro thấp, độ khó low/medium; nhập 1–5 file tương đối. HUB dùng Invoke-LocalCoder, resource guard, schema/hash/path checks. “Chỉ tạo proposal” dừng ở staging. “Triển khai” tiếp tục Codex review toàn bộ mã, apply đúng SHA và chạy checks; hai checkbox điều khiển tự apply/sửa có giới hạn. Có thể tắt để đi từng bước. Risk cao/critical chuyển qua nhiệm vụ review/phân rã trước.
- **Dự án:** xem board thật, tạo skeleton có rules và thư mục asset chuẩn. Không tạo ứng dụng hoàn chỉnh chỉ bằng bước tạo skeleton.
- **Báo cáo:** xem kết quả/error/trạng thái của từng lượt và task bàn giao. Hoàn tất lượt chat/staging không đồng nghĩa sản phẩm đã kiểm thử.
- **AI & ứng dụng:** mở Ollama, Blender, Blockbench và transport đã cấu hình qua Ensure-ProjectService. Godot cần binding đúng dự án, không tự đổi binding/cổng. Có cấu hình không đồng nghĩa kết nối MCP từ xa đã đạt.
- **Quy trình:** xem rules của dự án và hướng dẫn. Board không được AI tự cập nhật qua chat. Codex cập nhật từ bằng chứng trong vòng delivery.

## Adapter trực tiếp

### AI Local

Dùng Ask-Local, mặc định profile web (MiMo) cho hỏi đáp nhanh. Viết mã staging chọn profile theo domain; general dùng code. Không thay model khi bị resource guard chặn. Ollama có thể tự mở qua thẻ ứng dụng; model giữ nguyên alias đã cấu hình. ComfyUI đang chạy hoặc không xác minh queue được sẽ chặn inference. Không tự giải phóng model của client khác.

### Codex

Launcher nhận diện `%APPDATA%/npm/node_modules/@openai/codex/bin/codex.js`. Có thể cấu hình biến môi trường server `HUB_CODEX_JS` nếu CLI cài chỗ khác. CLI dùng phiên đăng nhập chính thức; HUB không đọc token. Chạy `codex login` theo hướng dẫn của CLI nếu cần, rồi mở lại server.

Hỏi đáp dùng `codex exec --json --ephemeral --sandbox read-only`, yêu cầu tắt từng MCP/plugin khai báo trong config và features.apps; không dùng bypass approvals. Override table rỗng không đủ vì config có thể merge; tạo mục enabled=false cho server chỉ được inject cũng có thể gây invalid transport, nên adapter chỉ override mục có config thật. Ngữ cảnh có board/rules và CLI làm việc tại root đã resolve. Sandbox filesystem không phải chứng nhận an toàn cho mọi CLI/plugin bên ngoài; kiểm tra phiên bản/cấu hình client khi nâng cấp. Adapter không chủ động cấp thêm MCP.

Kiểm tra live ngày 2026-11-08: model cấu hình CLI `gpt-6.1-sol` bị tài khoản ChatGPT CLI từ chối với model_not_found. Cache CLI làm mới cho thấy `gpt-6-luna` khả dụng; đã xác minh lượt CLI và lượt qua HUB đều trả lời. Theo chính sách điều phối tiết kiệm, HUB riêng dùng `codexModel: gpt-6-luna` trong ignored `hub/web-config.json`; không đổi model desktop hay provider/tài khoản. Biến `HUB_CODEX_MODEL` ưu tiên hơn cấu hình này. Bản 0.3 từng có cảnh báo MCP Notion. Bản 0.4 đã tắt apps/plugins/remote-plugin/shell/dependency install, bỏ desktop app-tools pipe ở CLI con, tắt MCP home/ancestor và reject tool events/startup MCP ngoài phạm vi; lượt CLI không có tool đã xác minh. Không coi lượt trả lời ngắn là chứng minh sandbox/MCP đã an toàn cho mọi tác vụ.

### ChatGPT / OpenAI API

Adapter trực tiếp dùng **Responses API**, không tự lấy cookie/lịch sử/MCP của ChatGPT web. Các quyền connector của ChatGPT không tự chuyển sang HUB. Kết nối C2C hiện hữu tiếp tục phục vụ ChatGPT web đọc workspace và review; không dùng C2C như API trả lời chat.

Trong Quy trình & hướng dẫn có thể nhập key/model trực tiếp, lưu DPAPI trên Windows và dùng ngay. Cách cũ vẫn hỗ trợ: đặt `OPENAI_API_KEY` và `HUB_OPENAI_MODEL` trên server rồi restart HUB. Không gửi key qua hội thoại, không đưa vào source/.env example/report. Launcher kế thừa environment; không tự tạo model mặc định hoặc chuyển provider. Chỉ khi người dùng chọn adapter này và bấm gửi mới gọi API. Payload: `/v1/responses`, store=false, max_output_tokens=2048, không tools; lỗi thiếu key/model/quota hiển thị trong báo cáo. Token cap là giới hạn đầu ra, không phải ngân sách tiền cứng. Dữ liệu gửi gồm câu hỏi, rules/board rút gọn và lịch sử gần đây; tránh nhập secrets/private data.

### Antigravity

Launcher nhận diện `agy.exe` trên PATH hoặc `HUB_AGY_EXE`. Dùng tài khoản/phiên đăng nhập của CLI chính thức, không trích xuất credential. Trước dùng đăng nhập Antigravity theo UI/CLI chính thức, kiểm tra `agy --version` và `agy --help`.

Adapter gọi headless `--print`, `--mode plan`, `--sandbox`, `--disable-slash-commands`, text output và timeout 300s. Không dùng `--dangerously-skip-permissions`, không đổi model/provider hay bật mua thêm credits. Phiên bản kiểm kê trên máy: 1.2.7; tài liệu hiện hành có tính năng mới hơn nên không coi Windows sandbox của bản này là ranh giới OS đã nghiệm thu. Plan mode hạn chế sửa mã theo client; các quyền MCP/tool toàn cục của Antigravity cần được review trước sử dụng dữ liệu nhạy cảm. Không hứa adapter áp policy của Codex lên mọi tool của Antigravity.

Lượt hỏi đáp qua HUB đã trả lời thành công; lần đo đầu mất khoảng 4 phút 32 giây. Đây là bằng chứng transport/auth cơ bản, không phải nghiệm thu tốc độ hay quyền tool.

Dự án phải đăng ký `antigravity` trong `hub/projects.json` để dùng; UI không tự cấp quyền. AI-LOCAL đã được đăng ký. Dự án mới mặc định Codex/ChatGPT/local, onboard Antigravity sau khi kiểm tra quyền client.

## Cấu trúc dự án và dữ liệu

`hub/layout.json` định nghĩa workspace `F:/Projects/AI-PROJECTS` và nhóm web/games/apps/media/learning. `Initialize-ManagedWorkspace.ps1` tạo shared rules; `New-ManagedProject.ps1` tạo `<workspace>/<kind>/<id>`, project.json, AGENTS, WORK-BOARD, README và các thư mục source/asset. Resolver kiểm tra identity/category/root và reparse. Không di chuyển dự án đang có tự động.

`hub/projects.json`, `integrations.json`, `hub/tasks`, `hub/web-state` là dữ liệu riêng của máy và không đóng gói/commit. Lịch sử chat/request/report lưu plaintext cục bộ; bảo vệ tài khoản Windows/ổ đĩa, không nhập secrets. Backup riêng trước nâng cấp. Bản này lưu theo file cho một người dùng, không phải hệ thống multi-tenant. UI chỉ hiển thị 100 lượt gần nhất; file cũ vẫn còn.

Windows trên máy này trả TCP connection refused sau khoảng 2037 ms. Guard cũ chờ 700 ms nên báo unknown với ComfyUI đã tắt. Guard hiện chờ kết quả tối đa 5 giây; vẫn chặn timeout, queue active/pending và API không xác minh được. Không bỏ kiểm tra hoặc tự dừng client khác. Bridge dùng UTF-8 stdout; decoder Node giữ byte đa phần, tránh hỏng tiếng Việt qua pipe.

API GET /api/state lấy snapshot; POST /api/jobs nhận chat/task/stage/workflow/createProject/service/board/previewStart/previewStop; workflow có endpoint chuyển bước riêng. Host 127.0.0.1 chính xác, origin cùng nguồn, CSRF token, JSON/body limit, CSP, asset allowlist; không generic shell/file endpoint. Một tác vụ một lúc. Model output hiển thị text, không render HTML/script. Điều này ngăn truy cập từ website khác; không bảo vệ trước phần mềm độc hại đã chạy dưới cùng tài khoản Windows.

## Kiểm tra và bàn giao cho AI Agent

1. Đọc AGENTS, TEAM-CONTRACT, board; giữ một writer/file.
2. Chạy `./Test-ProjectAI.ps1` và `node --test web/hub.test.mjs` (suite chính đã gọi Node).
3. Chạy launcher, GET /api/state và thử luồng API thật. Test API mock chỉ chứng minh contract, không chứng minh provider live.
4. Mở Chrome ngoài: gửi chat, lỗi thiếu cấu hình, staging, bàn giao, chọn board, đọc báo cáo, refresh/persistence, responsive/keyboard và console/network. Nếu computer-use bị tắt, ghi blocked; không thay bằng screenshot/mock và gọi là đạt.
5. Chạy `New-DeploymentPackage.ps1` trên source cuối. Chỉ release khi các gate cần thiết đạt. Không gọi production-ready khi Chrome/provider/MCP chưa nghiệm thu.

Nguồn giao thức: [OpenAI text/Responses](https://developers.openai.com/api/docs/guides/text), [Antigravity headless](https://antigravity.google/docs/cli/headless/), [CLI flags và permission settings](https://antigravity.google/docs/cli/reference/).

## Những phần chưa tự động hoàn toàn

Không có cầu tự động mang toàn bộ MCP cloud từ tài khoản ChatGPT vào HUB. Đã có vòng code staging → Codex review → apply/tests và tối đa hai vòng repair theo lựa chọn trước khi giao việc. Chat không tự triển khai; deploy/publication vẫn cần quyền và release gates riêng. Không có multi-user auth, scheduler, chat streaming token hay kết nối trực tiếp vào chat desktop đang mở. Tiến trình hiển thị ở mức job/board thực, không suy đoán phần trăm model. Thiếu key/đăng nhập hoặc QA Chrome là blocker thực, không phải trạng thái thành công.
