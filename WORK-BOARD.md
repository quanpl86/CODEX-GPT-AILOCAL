# WORK BOARD — HUB AI 0.4.0 candidate

Mục tiêu: HUB single-user trên Windows, local-first, đúng project, có review và bằng chứng. Chủ sở hữu tích hợp/QA/Git: Codex. Bản source được publish để theo dõi/CI; chưa chứng nhận production hoặc 100% mọi tác vụ.

| Phase / task | Owner | Trạng thái | Bằng chứng / hành động tiếp |
|---|---|---|---|
| A: Project registry, workspace và starter vanilla-web | Codex integration | Implemented / tested | ManagedProjects + Test-ManagedProjects; F:/Projects/AI-PROJECTS/{web,games,apps,media,learning} |
| B: Local viết → Codex review → SHA apply → checks/repair | Local implementer / Codex QA | Implemented / runtime exercised | Hai smoke workflow; round giới hạn, không chạy lệnh model gợi ý |
| C: Queue, retry, recovery, secrets và source boundary | Codex security | Tests passed | Durable request journal; same-request concurrent admission; atomic receipt/rollback; tamper/stale/private-file tests |
| D: Web chat, reports, timeline, source, board, preview, provider setup | Codex integration | Implemented | Preview riêng origin; DPAPI; hỏi đáp tách triển khai; không arbitrary shell |
| E: Offline regression | Codex QA | Passed | Test-ProjectAI.ps1: PowerShell suite và 19/19 Node tests; không inference/billing trong CI |
| E: Chrome ngoài source cuối | Codex QA / user browser access | BLOCKED | Đã test draft, preview counter/reset, console và mobile trước các sửa cuối. Quyền Local browser use lại bị disabled; user báo bật nhưng công cụ vẫn từ chối. Không thay bằng headless/API |
| E: Packaging / Git / hosted CI | Codex release | Candidate publication; gate riêng | Kit 98 file allowlist; SHA từng file đối chiếu source và test từ ZIP. Xem remote SHA/Actions của commit; không tạo production release/tag khi Chrome còn blocked |

## Runtime evidence 2026-11-08

- Local chat tiếng Việt hoạt động. Local MiMo thực sự viết greet proposal hai vòng nhưng sai Node test contract; Codex từ chối cả hai. Không áp dụng mã lỗi. Explicit fallback Codex tạo proposal, review mới approve/uiChanged=false, apply đúng SHA; 4/4 Node tests đạt. Nghiệm thu module pure-library qua API, không dùng làm bằng chứng UI HUB.
- Score workflow: apply đúng SHA, 5/5 Node tests đạt; nghiệm thu non-UI đã ghi. Cả hai dự án smoke chỉ phục vụ QA, không phải sản phẩm người dùng.
- CLI Codex adapter trả lời được; gpt-6-luna riêng cho HUB. Tắt remote plugins/apps/shell/tool pipe trong adapter; review độc lập các boundary không còn findings tại lượt review cuối (không phải chứng nhận bảo mật tuyệt đối).
- Antigravity trả lời qua CLI plan mode; quyền tool/OS isolation chưa được nghiệm thu. Không giao quyền tự ghi source cho adapter này.
- OpenAI API: form key/model và DPAPI đã test bằng dummy key, chưa có key thật hoặc paid call. ChatGPT web/C2C hiện không có session active được xác minh; cần ghép lại đúng workspace, không suy ra từ plugin installed.
- MCP: Blender/Blockbench/Godot tiếp tục dùng binding và asset handoff. Godot port/project cũ không tự đổi; installed/local-ready không bằng remote task verified.

## Handoff còn lại

Task: final Chrome acceptance. Owner: Codex QA khi quyền browser có hiệu lực. Scope: đúng source candidate, project placeholder/không chọn sai project, draft + hai auto flags, workflow checks/accept, source/board optimistic save, preview start/reuse/stop, provider validation không key thật, responsive/keyboard/console/network. Evidence: screenshot + steps/expected/actual. Không sửa trạng thái production hoặc ghi UI passed trước gate này.

Vận hành và cài cho dự án khác: docs/HUB-OPERATIONS.vi.md, docs/HUB-WEB.vi.md, docs/HUB-ACCEPTANCE.vi.md. Quy tắc kỹ thuật: AGENTS.md và docs/TEAM-CONTRACT.vi.md.
