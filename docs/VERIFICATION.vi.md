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
