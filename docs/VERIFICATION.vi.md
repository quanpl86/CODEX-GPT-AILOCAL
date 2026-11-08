# Hồ sơ xác minh triển khai

Ngày 08/11/2026, Asia/Saigon. Hồ sơ này phân biệt kết quả có bằng chứng và phần chưa nghiệm thu.

| Hạng mục | Bằng chứng | Trạng thái |
|---|---|---|
| Ollama | API server 0.40.15; model list/show | Đã kiểm tra |
| MiMo 9B Q4_K_M | pull thành công, SHA-256 digest được Ollama xác minh | Đã tải |
| 5 alias theo tác vụ | Smoke test cả 5 trả `a + b`; file smoke-results.json | Đã inference ngắn trước khi bổ sung guard |
| Launcher web | Sinh đúng hàm add(a,b) | Đã inference |
| Codex gọi local và lưu kết quả | Hai lượt tham vấn trong local-runs; một completed, một truncated | Luồng thực tế chạy được; chất lượng đề xuất không đạt để tự áp dụng |
| Kiểm tra độc lập lời khuyên | Nhận xét sai về input/lock bị bác bỏ, không đưa vào code | Đã đối chiếu |
| Guard và lỗi request | Test-LocalWorkflow.ps1, Test-CapacityGuard.ps1 | Có kiểm thử offline; không phải stress test |
| Installer | Test-Installer.ps1 | Giữ hướng dẫn cũ; rerun; WhatIf; bảo vệ config sửa; marker lỗi |
| C2C cập nhật | update-check --force: 0.1.3, local=remote 535a07dbb7aee887924c53767d985c09d405319d | Up-to-date tại thời điểm kiểm tra |
| C2C bridge/OAuth | doctor: bridge/mcp/oauth/tunnel đạt; unauthenticated MCP trả 401 | Đã kết nối |
| ChatGPT đọc workspace | workspace_info xác nhận AI-LOCAL / 46b9932ae091, đọc README, rồi đọc 6 file review | Đã kiểm tra qua ChatGPT |
| ChatGPT Project | AI-LOCAL, bộ nhớ Chỉ dự án, thư viện tắt; lưu connector đúng | Đã cấu hình |
| Blender/Godot/Blockbench plugin | UI ChatGPT có cài; tool namespaces được ChatGPT phát hiện | Đã đăng ký |
| App MCP status | Lượt đầu trả 429; probe local không có listener trên 9876/9877/8787/3000 | Chưa đạt kết nối live |
| App MCP task thực tế | Không có yêu cầu tạo/sửa asset hoặc scene cụ thể | Chưa kiểm thử end-to-end |
| Cloud MCP | UI có nhiều plugin; không thay đổi dữ liệu cloud | Chỉ kiểm kê, không thử ghi/publish |

## Giới hạn và quyết định

- North dùng CPU do thử CUDA bị lỗi khởi tạo hai lần. Không coi CPU mode là hiệu năng tốt: các câu trả lời ngắn chỉ khoảng 2 token/giây ở lượt đo trước.
- Qwen3.8 cũng chậm trong phép thử ngắn. Không quảng bá model lớn là tối ưu trên GPU 8 GB.
- Guard mới không chạy lại inference GPU sau sự cố thiếu RAM. Các test sau đó là offline/read-only, tránh tạo thêm áp lực tài nguyên. Thay đổi guard/output được kiểm thử bằng mock, không coi kết quả inference cũ là benchmark của mã mới.
- ComfyUI có tác vụ từ trước, dùng Flux2 dev + Mistral BF16; sau khi người dùng cho phép, interrupt đúng job và unload. Xác minh queue 0/0, RAM trống ~22,3 GiB, GPU ~897 MiB. Ứng dụng không bị kill và lịch sử không bị xóa.
- Godot launcher hiện gắn F:/MyGodotGame/test-mcp. AI-LOCAL không có project.godot; không tự chuyển binding, cài addon hay sửa scene ở dự án cũ.
- Blender và Godot trùng port editor 9876. Start-ProjectMcp.ps1 kiểm tra xung đột; không tự kill tiến trình hoặc đổi port một phía.
- Không sửa global Codex model provider, không ghi bộ nhớ Codex của người dùng. Người dùng đã cho phép commit/push tới quanpl86/CODEX-GPT-AILOCAL; kiểm tra publication được báo riêng.

## Lệnh dùng để tái kiểm tra

```powershell
.\Test-LocalWorkflow.ps1
.\Test-Installer.ps1
.\Test-CapacityGuard.ps1
.\Test-Integrations.ps1
```

Không gọi Test-Profiles.ps1 khi ComfyUI/GPU khác đang chạy. Khi cần nghiệm thu ứng dụng, chạy launcher đúng và gọi read-only tool qua ChatGPT, rồi mới thực hiện tác vụ asset/scene có tiêu chí rõ ràng. Không chuyển `tool_call_verified` sang true chỉ vì port mở.

## Bổ sung local-first và skill

- Đã tạo alias thứ sáu local-code trên Qwen3-Coder 30B; chưa inference với alias này vì guard chặn dưới 22 GiB RAM trống.
- Bảy skill chuyên môn được validator skill-creator xác nhận hợp lệ và cài vào kho skill Codex. Phân công local viết mã, Codex review/apply/test, ChatGPT plan/MCP/milestone review đã lưu trong Project instructions.
- Lượt viết PowerShell thật bằng MiMo có kết quả bị cắt hoặc sai syntax/contract. Các proposal không được áp dụng. Sau vòng sửa không đạt, phần router/report được fallback Codex hoàn thiện; không tuyên bố local đã viết mã production đạt.
- Luồng stage/apply được kiểm thử offline với output mock: từ chối traversal, protected paths, stale source, tamper, truncation và syntax lỗi; WhatIf không ghi source, receipt chưa tự báo test đạt.
- Test-ProjectAI.ps1 gom kiểm thử syntax, HTTP contracts, guard, local coder, routing, installer và repair report. Source và ZIP giải nén đều đã chạy bộ kiểm thử này.
- CI Windows/pipeline đóng gói đã cấu hình; chờ kiểm tra hosted run sau push. Không có dịch vụ web nên Chrome app QA là N/A. Phiên ChatGPT trên Chrome không được tính là QA app.

- ChatGPT đã review iteration 1 qua connector và trả DONE/APPROVED, không có blocking corrections; đọc source/staged diff và execution_output exit code 0. Đây là review phần toolkit, không phải chứng nhận production cho ứng dụng chưa tồn tại.

## Publication đã xác minh

- Source commit: e24bf28331a6b25be5ea939135a392bc6825a7d8, nhánh main; remote refs/heads/main đã trả đúng SHA sau push.
- GitHub Actions [Toolkit verification #42447630933](https://github.com/quanpl86/CODEX-GPT-AILOCAL/actions/runs/42447630933) completed/success. Tất cả bước checkout, offline checks, build kit và upload artifact đều success.
- Commit tài liệu bàn giao theo sau chỉ ghi kết quả đã xảy ra. Kết quả workflow cho từng SHA xem trực tiếp trên GitHub; không nhầm trạng thái của một SHA với SHA khác.

## HUB 0.4.0 candidate — 2026-11-08

Tài liệu ở các phần trên là bằng chứng lịch sử; không suy ra kết nối C2C/MCP còn live từ lần kiểm tra cũ. Trạng thái hiện tại xem WORK-BOARD.md.

- Test-ProjectAI.ps1 hiện gồm toàn bộ PowerShell regression và 19 Node tests: HTTP Host/Origin/CSRF, UTF-8, secret handling/DPAPI, preview origin/ownership, durable idempotency, >100 report restart recovery, source/receipt integrity, bounded repair và acceptance. Tất cả đạt trên Windows ở source candidate.
- Independent Codex review đã phát hiện và sửa các lỗi source mutation/recheck, JS UI classification, receipt rollback, damaged report isolation, retry admission và interrupted workflow recovery; lượt sau không còn actionable findings. Review không thay thế tests hoặc chứng nhận mọi client bên ngoài.
- Smoke score: 5/5 test thực; smoke greet: local sai hai vòng bị reject, explicit Codex fallback, reviewed SHA apply và 4/4 test thực. Module non-UI nghiệm thu qua API có ghi rõ operator_report; không giả làm tự động browser evidence.
- Chrome ngoài đã tương tác thật với HUB, tạo project, xem source, preview counter/reset bằng keyboard, draft qua reload, mobile effective 433 px không overflow và console không lỗi tại lượt đó. Sau các sửa cuối, công cụ bị Local browser use disabled; user báo bật lại nhưng kiểm tra vẫn bị từ chối. Final-source Chrome gate BLOCKED. Screenshot trước đó không dùng để chứng nhận source cuối.
- API key thật chưa có; C2C workspace session hiện chưa xác minh active; Antigravity tool isolation và MCP asset end-to-end theo project vẫn có giới hạn đã ghi trong sổ tay.
- Git publication và hosted CI của SHA mới phải xem riêng sau push. Publication candidate không phải production deployment hay universal 100% completion.
