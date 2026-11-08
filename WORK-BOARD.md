# Tiến độ AI-LOCAL

Mục tiêu: bộ điều phối local-first có vai trò, review/test, skill chuyên môn, triển khai lại và GitHub CI.

| Phase / Task | Owner | Trạng thái | Acceptance / bằng chứng |
|---|---|---|---|
| P1 — Kiểm kê, Ollama, model | Codex | Done | 5 alias inference ngắn; smoke-results.json |
| P2 — C2C, ChatGPT Project | Codex + ChatGPT | Done | Doctor đạt; ChatGPT workspace_info/read_file đúng AI-LOCAL |
| P3 — Resource guard, installer | Codex QA | Done | Tests offline và kiểm tra RAM đạt; ComfyUI dừng theo yêu cầu |
| P4 — Local viết mã và vòng sửa | Local implementer -> Codex | Done (cơ chế) | Staging/apply/hash/path/syntax tests đạt; mã MiMo PowerShell chưa đạt bị từ chối, fallback Codex |
| P5 — Role, skill, UI/code/QA chuẩn | Codex + ChatGPT review | Done | 7 skill validated/cài; Project instructions local-first lưu; ChatGPT review iteration 1 DONE, không còn blocking correction |
| P6 — CI/package và kiểm thử cuối | Codex QA/release | Done | Offline/source/ZIP tests đạt; GitHub run 42447630933 success cho e24bf28, gồm test/build/upload kit |
| P7 — Commit/push GitHub | Codex release | Done | main đã push, remote xác nhận source commit e24bf28331a6b25be5ea939135a392bc6825a7d8; commit tài liệu bàn giao theo sau |
| MCP app live | ChatGPT + app operator | On demand / chưa đạt | Plugin có; status 429; local app chưa mở; không chuyển Godot project cũ |
| Chrome nghiệm thu web app | Codex QA | N/A hiện tại | Toolkit không có ứng dụng web; bắt buộc khi có thay đổi web/UI |

## Handoff đang mở

- Local implementer -> Codex: mẫu PowerShell không đạt syntax/contract đã bị từ chối; router/report hoàn thiện bằng fallback Codex và có regression tests. Ngưỡng model code lớn đã chặn khi RAM chưa đủ.
- ChatGPT -> Codex release: iteration 1 DONE/APPROVED, không có blocking corrections; được chuyển sang commit/push đã được người dùng ủy quyền.
- Codex release -> người dùng: source đã commit/push lên quanpl86/CODEX-GPT-AILOCAL main, CI kiểm thử/đóng gói/upload artifact đã success. MCP app runtime vẫn on-demand, chưa được coi là nghiệm thu live.

Không coi MCP app là done cho tới khi read-only tool live và tác vụ thực tế của đúng project được kiểm tra.
