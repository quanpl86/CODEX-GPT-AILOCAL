# Vận hành HUB AI 0.4

## Mở và chọn đúng nơi làm việc

Nhấp Open-Hub.cmd, dùng Chrome ngoài tại http://127.0.0.1:8765. HUB chỉ dành cho một người dùng trên máy, không public/LAN và không có multi-user authentication.

Trong Dự án & kế hoạch, tạo ID dự án, chọn nhóm và mục tiêu. Chọn “Web chạy ngay” nếu muốn baseline HTML/CSS/JavaScript không cần npm install. Đây là starter, không phải web game/hệ thống học tập đã hoàn thành.

Dự án nằm ở F:/Projects/AI-PROJECTS/<nhóm>/<id> theo hub/layout.json. Registry kiểm tra identity/root, không di chuyển hoặc ghi đè repository hiện có. Các dự án kiểm thử hub-delivery-smoke và hub-preview-smoke là fixture thật để nghiệm thu HUB, không phải sản phẩm được đặt hàng.

## Giao nhiệm vụ code

1. Phòng điều phối: chọn project, mô tả mục tiêu, chọn domain/độ khó/rủi ro. “Gửi câu hỏi” chỉ chat. AI Local là người viết code chính; lựa chọn AI trong chat không đổi owner của coding workflow.
2. Nhập đường dẫn tương đối của tối đa 5 file được thay đổi. Có thể xem file ở Dự án & kế hoạch và thêm vào phạm vi. File mới gõ tên tương đối; không gửi .env, key, config private.
3. Viết tiêu chí nghiệm thu cụ thể. Nếu có test Node, chọn đúng *.test.mjs/cjs/js. Tests được thực thi bằng Node dưới tài khoản Windows hiện tại sau review/apply; đây là chạy mã dự án, không phải OS sandbox cho mã không tin cậy.
4. Hai lựa chọn “tự áp dụng sau Codex duyệt” và “tự sửa tối đa hai vòng” hiển thị rõ trước khi bấm Triển khai. Có thể tắt để duyệt từng bước. Draft lưu trong session trình duyệt, gồm cả hai lựa chọn này; API key không nằm trong draft.
5. HUB tạo handoff → local staging → Codex review toàn bộ original/proposed code và governance → apply đúng SHA → checks. Không thực thi suggested_checks của model.
6. Report chứa expected/actual/requested change qua New-ReviewReport. Nếu chưa apply, local nhận cả proposal bị từ chối làm reference để sửa đúng chỗ. Không cắt prompt/code khi vượt budget; cần chia nhỏ task.
7. Hai vòng local không đạt thì dừng để Codex xử lý phần khó. RAM/ComfyUI đang bận thì dừng ngay, không tự retry, không dừng model của client khác. Có nút chuyển phần bị chặn cho Codex tạo proposal, vẫn qua review/hash/tests. Không tự chuyển sang API trả phí khác.
8. Khi checks qua, ghi bằng chứng runtime: Chrome thật cho UI; hoặc lý do không có UI và runtime phù hợp. HUB kiểm tra lại source hashes. Trạng thái nghiệm thu có xác nhận là operator_report, không giả là test tự động.

Task high/critical hoặc quá lớn phải phân rã và bàn giao Codex/ChatGPT review riêng. Không auto-apply source của HUB đang chạy từ web; bảo trì HUB do Codex desktop tích hợp. Publication/deploy/Git không được suy ra từ một câu trả lời model.

## Tiến độ và phục hồi

Công việc & báo cáo hiển thị timeline, owner, round, full proposal/SHA, review findings, checks/output và bằng chứng nghiệm thu. Tác vụ được xếp hàng, tối đa 10 việc chờ và một việc chạy; local requests không chạy song song.

Gửi lại cùng request key không tạo job thứ hai. Apply có project lock và receipt chống replay; stale source/staged content/review SHA sai bị chặn. Restart không tự chạy lại những lượt đang chạy/chờ, tránh lặp sửa mã hoặc phát sinh chi phí. Chỉ bấm review/repair/checks khi trạng thái cho phép. Đóng task không rollback mã đã apply.

Nếu mất kết nối, đợi HUB lên lại và làm mới; draft vẫn còn trong cùng tab. Không kill mọi Node/Ollama/ComfyUI để sửa một job. Nếu disk/quyền ghi lỗi, HUB dừng nhận việc mới và giữ báo lỗi, cần sửa storage trước khi chạy tiếp.

## Preview và source

Dự án vanilla-web có nút chạy/dừng preview. Preview có origin loopback riêng, không cùng origin với dashboard. Chỉ phục vụ index/styles/src/public; không directory listing, .env, file ẩn hoặc symlink. Không coi đây là production hosting hay server đa framework.

Chọn project → Chạy preview → Mở preview trên Chrome. Source đọc trên web không render HTML/script. Stop chỉ dừng process có script/nonce đúng receipt do HUB tạo. Stack Vite/Next/backend khác cần launcher được đăng ký và review riêng; không có ô chạy shell tùy ý.

Work board có thể sửa từ web. Save kiểm tra SHA trước ghi để không đè thay đổi của người khác. Đây là cập nhật do người vận hành, không tự chứng nhận tests đã qua.

## OpenAI API, ChatGPT và MCP

Quy trình & hướng dẫn có form API key + Model ID. Nhập trực tiếp ở máy, không gửi key vào chat. Khóa mã hóa Windows DPAPI dưới hub/web-state/openai-provider.json; chỉ user Windows hiện tại giải mã được. Không đưa file này vào Git/kit. Chỉ lưu cấu hình không gọi API tính phí. Biến môi trường cũ vẫn ưu tiên, UI sẽ báo nếu đang override.

Adapter dùng Responses API không có tools, store=false và output cap 2048. Không tự dùng lịch sử/quyền MCP của ChatGPT web. Muốn sử dụng cần key/model có quyền và billing/credits phù hợp do người dùng thiết lập. Token cap không phải hard monetary budget.

Codex dùng account CLI hiện hữu, gpt-6-luna cho adapter đã kiểm chứng. Adapter tắt apps/plugins/remote-plugin/shell/dependency MCP, không kế thừa desktop app-tools pipe, tắt MCP khai báo ở config home/ancestor và từ chối config inline không kiểm soát được. Tool event hoặc lỗi startup MCP làm reject kết quả. Đây là kiểm soát adapter, không thay cấu hình desktop hay chứng nhận mọi client bên ngoài.

Antigravity hiện là adapter plan/hỏi đáp, không tự viết source. Quyền tool của Antigravity vẫn thuộc cấu hình client; không được coi plan mode của CLI 1.2.7 là OS isolation đã chứng nhận. Không chuyển thêm credits/model/provider âm thầm.

MCP Blender/Blockbench/Godot dùng launcher/binding đã cấu hình. Asset task tạo handoff cho ChatGPT/app operator, chưa có quyền tự nhập API hoặc tự cấp connector. Godot binding cũ không được tự thay. Kết nối remote phải kiểm chứng bằng tool/tác vụ đúng project; app mở và transport healthy chưa đủ.

## Kiểm tra và nâng cấp

Khi mất kết nối sau bấm gửi, gửi lại cùng request trong phiên sẽ dùng mã chống chạy trùng. Journal `hub/web-state/requests` giữ claim bền vững qua restart và không phụ thuộc danh sách 100 report trên UI. Backup cả journal cùng reports; không xóa riêng journal để “thử lại”. Claim hỏng hoặc ghi dở bị chặn để phục hồi, không tự chạy lại. Report JSON lỗi/quá lớn được cách ly khỏi danh sách, giữ bản gốc và hiển thị cảnh báo. Nếu không ghi được report, HUB dừng nhận/chạy việc mới; sửa quyền ghi/dung lượng, backup rồi restart.

Restart đánh dấu mọi lượt queued/running cũ là interrupted, kể cả ngoài 100 report gần nhất. Với proposal đã apply nhưng lượt kiểm thử gián đoạn, dùng Chạy lại checks: HUB xác minh receipt, proposal và source trước khi tiếp tục, không apply lại. Nếu source đã đổi, cần review/regenerate riêng. Không sửa JSON để ép trạng thái verified.

Chạy Test-ProjectAI.ps1: tests web dùng bản sao allowlist có SHA trùng source để không trộn job fixture vào HUB đang dùng. Bộ kiểm thử không tự tải model hoặc gọi cloud có tính phí. Cần nghiệm thu Chrome ngoài source cuối, rồi New-DeploymentPackage.ps1. Kit không có registry thật, credentials, lịch sử hoặc weights. Commit/push/remote SHA/CI là các gate riêng.

Giới hạn cần giữ rõ: chưa có multi-user/production auth, không scheduler/background agent bất kỳ, không shell tùy ý, không auto-import mọi MCP cloud của tài khoản ChatGPT, không tự xác nhận appearance/credentials thay người dùng. Không có bảo đảm “100% mọi công việc”; từng tác vụ chỉ hoàn tất khi acceptance và bằng chứng tương ứng đạt.
