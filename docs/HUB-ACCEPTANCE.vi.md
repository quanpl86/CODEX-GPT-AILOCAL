# HUB: phạm vi hoàn thiện và nghiệm thu

Mục tiêu: vận hành single-user trên Windows qua Chrome, local-first, đúng project và có bằng chứng. Không dùng phần trăm hoàn thành để che phần thiếu account/quyền hoặc chưa thử thực tế.

| Phase | Acceptance |
|---|---|
| A — Giao việc rõ vai trò | Tách chat và triển khai; project/files/acceptance/test scope rõ; giải thích model/owner |
| B — Delivery workflow | Local staging → Codex đọc toàn proposal/review → apply đúng SHA → checks thực → repair tối đa hai vòng → escalation; không chạy lệnh do model gợi ý |
| C — Điều hành | Job state/timeline/report bền vững; refresh không mất draft; retry không apply hai lần; restart nhận diện lượt bị gián đoạn |
| D — Project và MCP | Tạo project theo layout; chỉ dùng binding đã đăng ký; credential/consent thuộc người dùng; tách chat API và ChatGPT web/C2C |
| E — Nghiệm thu | Tests boundary, tamper, stale source, concurrency, provider errors; Chrome thật desktop/mobile/keyboard/error/console/network; gói source cuối và Git/CI được xác minh riêng |

Phần thiếu API key, tài khoản hoặc binding MCP không thể tự cấp thay người dùng. Từng adapter/tool phải có trạng thái unavailable/configured/verified và báo nguyên nhân. Không tuyên bố đáp ứng 100% mọi loại công việc hoặc mọi MCP chỉ từ một lượt chat.

Coding workflow chỉ áp dụng task ít rủi ro và file allowlist đã chọn. High/critical phải phân rã và review riêng. Không tự publish/deploy/mua dịch vụ. Auto apply chỉ khi policy và review đã kiểm chứng; trong các mốc đầu UI trình bày full changes/hash/review và cho người dùng yêu cầu apply đúng proposal. User click không thay thế Codex review.
