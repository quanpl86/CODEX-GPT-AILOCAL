# Codex · ChatGPT · AI Local

Bộ công cụ Windows/PowerShell để **ChatGPT lập kế hoạch, AI local viết mã, Codex review và kiểm thử**. Giảm gọi cloud cho task nhỏ, giữ kiểm soát phạm vi, chất lượng và tài nguyên.

Đây cũng là hub quản trị chung: [kiến trúc dự án tổng](docs/HUB-ARCHITECTURE.vi.md),
[quy trình asset 2D/3D](docs/ASSET-PIPELINE.vi.md). Đăng ký dự án bằng registry local;
New-HubTask tạo handoff đúng root/role, không giả định agent đã chạy.
Ensure-ProjectService tự mở dịch vụ theo nhu cầu và chờ readiness có thời hạn.
Ask-Local tự khởi động Ollama nếu API chưa chạy. Credential/consent lần đầu do người dùng xử lý.

## Bắt đầu

Yêu cầu: PowerShell 7, Ollama đang chạy; Node 20+ và Codex with ChatGPT nếu dùng C2C. Không tự tải model hay đổi provider Codex toàn máy.

```powershell
./Test-ProjectAI.ps1             # Offline, không nạp model
./Setup-Profiles.ps1             # Alias từ model đã tải
./Select-TaskRoute.ps1 -Domain web -Complexity medium -Risk low
```

| Tác vụ | Alias | Model gốc |
|---|---|---|
| Web/UI | local-web | MiMo V2.6 9B Q4_K_M |
| Game giáo dục | local-game | MiMo V2.6 9B Q4_K_M |
| Mã tổng quát/tooling | local-code | Qwen3-Coder 30B |
| Agent/AI brain | local-brain | North Mini Code 1.0 |
| Learning system | local-learning | North Mini Code 1.0 |
| Review/kiến trúc khó | local-review | Qwen3.8 27B |

Model lớn cần RAM và có thể rất chậm trên GPU 8 GB. Guard chặn khi thiếu RAM, ComfyUI có job, queue không xác minh được hoặc Ollama có model khác đang nạp. Không tự dừng client khác. `ollama run` trực tiếp không có guard này.

## Local viết mã, Codex kiểm soát

```powershell
./Invoke-LocalCoder.ps1 -Task web -ProjectPath 'F:\Projects\MyApp' `
  -Files 'src/example.ts' -Prompt 'Yêu cầu nhỏ và acceptance rõ ràng'
```

Local tạo proposal và mã trong staging, chưa ghi source. Codex review đầy đủ, lấy SHA-256 rồi dùng `Apply-LocalProposal.ps1` để áp dụng. Applier kiểm tra project, đường dẫn, source/staging hash; sau apply vẫn phải test. `New-ReviewReport.ps1` và `-ReviewReport` gửi lỗi cụ thể cho local sửa. Hai vòng local không đạt thì chuyển đúng phần khó sang cloud.

Chỉ cần tham khảo: `Invoke-LocalAdvice.ps1 -Task web -Prompt 'Câu hỏi cụ thể' -ContextFile .\file.ps1`. Lệnh trả `advice.md`; prompt không lưu mặc định. Generated code/answers có thể chứa dữ liệu nguồn nên không gửi secrets. Logs/model outputs giữ local và ignored.

## Quy trình và skill

- [Vai trò, điều phối, code/UI/QA và CI/CD](docs/TEAM-CONTRACT.vi.md).
- [Cài đặt/tái triển khai chi tiết](docs/DEPLOYMENT-GUIDE.vi.md).
- [Blender, Blockbench, Godot và cloud MCP](docs/MCP-OPERATIONS.vi.md).
- [Bằng chứng và giới hạn](docs/VERIFICATION.vi.md).
- [Phase/task/owner](WORK-BOARD.md).

Bảy skill ở `skills/`: delivery, UI/UX, backend, database, QA/QC, security và CI/CD. Cài bằng `Install-TeamSkills.ps1`; skill mới có thể cần chat Codex mới để tự khám phá. Chat đang chạy đọc file cần thiết trực tiếp.

UI dùng một design system/tokens của sản phẩm; mẫu tại `templates/ui/tokens.css`. Task web/UI phải kiểm tra app thật trên **Chrome bên ngoài**. Toolkit này chưa có ứng dụng web nên không tuyên bố đã nghiệm thu UI app.

## Triển khai cho dự án khác

```powershell
./Install-ProjectAI.ps1 -ProjectPath 'F:\Projects\MyApp' -WhatIf
./Install-ProjectAI.ps1 -ProjectPath 'F:\Projects\MyApp'
```

Installer ghép AGENTS.md và tạo `.ai-local`, không ghi đè config khác biệt nếu chưa dùng `-Force`. ChatGPT cần connector/Project riêng; không sao chép credentials, chat URL hay Godot binding cũ. Xem guide để ghép C2C và xác minh workspace_info.

## CI và đóng gói

```powershell
./Test-ProjectAI.ps1
./New-DeploymentPackage.ps1
```

GitHub Actions chạy tests offline trên Windows và tạo kit allowlist kèm checksum, không yêu cầu GPU/đăng nhập. Actions pin full SHA, token read-only. Chưa có service/hosting target nên chưa có deploy production. Push, CI xanh và deploy là ba trạng thái riêng.
