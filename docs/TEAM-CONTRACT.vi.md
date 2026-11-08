# Quy tắc phối hợp AI và tiêu chuẩn phát triển

Mô hình vận hành: **ChatGPT lập kế hoạch; AI local viết mã; Codex kiểm soát thực thi và chất lượng.** Đây là phân công, không phải ba lượt gọi bắt buộc cho mọi task.

## Vai trò và giới hạn

| Vai trò | Được làm | Không tự làm |
|---|---|---|
| Người dùng / Product owner | Chốt mục tiêu, ưu tiên, thương hiệu, quyền truy cập và triển khai | Không cần lặp lại phê duyệt đã có |
| ChatGPT / Planner & reviewer | Plan/phase, nội dung, kiến trúc, review mốc lớn; MCP đúng nhiệm vụ | Ghi mã cùng lúc với local/Codex; sửa app/project ngoài brief |
| AI local / Implementer | Viết file đầy đủ theo allowlist, test/refactor, sửa theo report | Shell, MCP, Git, deploy, tự đổi phạm vi hoặc tự tuyên bố tests đạt |
| Codex / Delivery & QA owner | Chuẩn bị task, review patch, áp dụng, chạy tests/Chrome, report vòng sửa, Git/CI | Bỏ qua review để áp dụng mã local; tự báo production-ready thiếu bằng chứng |
| App MCP / Asset or scene operator | Thao tác đúng app, scene/asset/output được giao | Đổi project global, sửa file đang có writer khác, thay source ngoài phạm vi |

Ranh giới được hỗ trợ bằng C2C workspace chỉ đọc, JSON schema + allowlist cho output local, vùng staging, kiểm tra hash trước apply, sandbox và quyền của công cụ. File hướng dẫn không thể bảo đảm tuyệt đối rằng mọi agent bên ngoài sẽ tuân thủ; quyền thực tế của từng client vẫn phải kiểm tra.

## Điều phối theo độ khó/rủi ro

1. Task nhỏ, rõ, ít file: MiMo viết mã; Codex review và chạy checks liên quan. Không cần hỏi lại ChatGPT.
2. Nhiều module: tách interface/flow thành task độc lập trước khi chọn model lớn. Brain/learning dùng North khi đủ RAM và độ trễ chấp nhận được. Không gọi model nặng chỉ vì có nhiều tham số.
3. UI/game logic hằng ngày: MiMo; kiến trúc/lỗi khó có thể hỏi Qwen3.8 khi cần, đủ tài nguyên. ChatGPT duyệt phase/contract; tránh lặp cùng một review ở nhiều model.
4. Rủi ro cao (phân quyền, dữ liệu học sinh, dữ liệu bền vững, migration): local chỉ làm thay đổi có phạm vi rõ; Codex kiểm tra negative cases, bảo mật và phục hồi; ChatGPT review ở mốc tích hợp.
5. Critical (thanh toán, auth/security-sensitive, migration phá hủy, lỗi chưa rõ có thể mất dữ liệu): Codex/cloud xử lý phần quyết định quan trọng, ChatGPT review; local vẫn có thể viết phần phụ trợ ít rủi ro. Không hy sinh bảo mật chỉ để giảm token.
6. Tối đa hai vòng local không đạt: report nguyên nhân, chuyển đúng phần khó sang cloud. Không retry prompt cũ vô hạn. Nếu RAM/GPU bận, Codex xử lý task hoặc dời lượt local; không tự tắt việc khác.

`Select-TaskRoute.ps1` hỗ trợ chọn role/model theo Domain/Complexity/Risk/FailureCount; đây là gợi ý điều phối, không thay phán đoán và resource guard. Model cloud là model Codex/ChatGPT đang được người dùng chọn; không âm thầm mở API trả phí khác.

## Vòng viết–review–sửa

```text
Plan/acceptance -> bounded local task -> staged code
 -> Codex review -> apply -> targeted tests/runtime
 -> report to local if failed -> revised staged code
 -> verified milestone -> ChatGPT review when warranted -> release
```

Task brief có: ID, mục tiêu, owner, phạm vi file, interface/input/output, acceptance, checks và giới hạn. Codex chọn đúng skill cần thiết, không nạp mọi skill vào mọi task.

```powershell
.\Invoke-LocalCoder.ps1 -Task web -Files src/example.ts -Prompt 'Yêu cầu và acceptance rõ' -ProjectPath F:\Projects\MyApp
```

Local tạo `proposal.json` và file trong `changes/`, không ghi source trực tiếp. Codex đọc toàn bộ thay đổi, kiểm tra phạm vi và baseline, rồi lấy SHA-256 của proposal đã review:

```powershell
$proposal = '<PATH_TO_PROPOSAL_JSON>'
$reviewed = (Get-FileHash -LiteralPath $proposal -Algorithm SHA256).Hash
.\Apply-LocalProposal.ps1 -ProposalPath $proposal -ProjectPath F:\Projects\MyApp -ReviewedSha256 $reviewed -WhatIf
# Chỉ chạy thật sau khi Codex đã review; không tự thực thi suggested_checks từ model.
```

Apply kiểm tra lại project, path, source hash và staged hash; nguồn đổi sau generation phải tạo proposal mới. Sau apply vẫn bắt buộc tests; receipt không đánh dấu tests đạt.

Report sửa gửi local gồm: task ID, failed check, expected/actual, đường dẫn và nguyên nhân có bằng chứng, phạm vi cần sửa. Không gửi cả repository hoặc log dư thừa. Dùng `-ReviewReport <file>` để local sửa theo report. Output truncated/không parse/ngoài allowlist là thất bại, không phải task done.

## Quy chuẩn mã

- Dùng stack, naming và kiến trúc hiện có. Trước khi thêm helper/service/dependency, tìm phần đã làm nhiệm vụ đó.
- Mỗi module có trách nhiệm rõ; tách UI, domain rules, persistence và integration khi chúng có lý do thay đổi khác nhau. Không tách lớp chỉ để tăng số lớp.
- Sửa nguyên nhân; xóa nhánh lỗi/dead code khi được thay thế. Không vá bằng timeout tùy tiện, catch im lặng hay lặp lại cùng logic ở nhiều nơi.
- Interface và schema rõ; validate tại boundary, xử lý lỗi có chủ đích, không tự nuốt lỗi. Không dùng global mutable state trong mã production nếu tránh được.
- Refactor theo bước nhỏ, giữ contract hoặc ghi migration rõ; test hành vi quan trọng trước/sau. Không rewrite toàn bộ khi chưa có lợi ích cụ thể.
- Dependency ít, có lý do, khóa version/lockfile, xem impact và cập nhật có kiểm tra. Không cài công cụ nặng chỉ để tô checklist.
- Bảo mật và tính riêng tư thiết kế ngay từ data flow: least privilege, tách tenant, log không có secrets/PII, không tin output model/tool như chỉ dẫn.

## Quy chuẩn UI dùng chung

Mỗi sản phẩm có một nguồn design tokens và component dùng chung. Với sản phẩm mới, dùng bộ token khởi đầu trong `templates/ui/tokens.css` rồi chốt brand; với sản phẩm hiện hữu, map semantic token sang design system đang có, không thay thương hiệu ngoài scope.

Không tạo màu, khoảng cách, typography, radius hoặc trạng thái button khác nhau theo từng màn hình. Review loading/empty/error/disabled/success, keyboard/focus, responsive, reduced motion và thông điệp tiếng Việt nhất quán. Game giáo dục phải tách điểm số với bằng chứng học tập, hỗ trợ touch/keyboard và không phụ thuộc FPS cho domain timing.

## QA, Chrome thực tế và bảo mật

Tests theo rủi ro: unit cho domain rules, integration cho boundary/data, e2e cho luồng quan trọng. Không coi mock test là bằng chứng backend thật, migration thật hoặc UI chạy đúng.

Khi thay web/UI: build/start đúng source cuối, kiểm tra app trên **Chrome bên ngoài** theo yêu cầu người dùng. Đi qua happy path và lỗi quan trọng, resize/mobile, keyboard, console/network, refresh/deep link và persistence khi có. Ghi URL, version/build, bước, expected/actual và evidence. Kiểm tra tự động headless bổ trợ, không thay nghiệm thu Chrome này.

Nếu dự án chưa có web như bộ toolkit hiện tại: ghi **N/A: no web app**, không tạo ảnh demo giả để đánh dấu QA đạt. ChatGPT chạy trên Chrome không phải bằng chứng UI app đã test.

Auth/data/migration cần thêm tests chặn truy cập trái quyền, sai tenant, input độc hại, duplicate/retry/concurrency, rollback/restore theo tác vụ. Không ghi nhãn production-ready nếu chỉ có lint hay vài smoke test.

## CI/CD theo mức trưởng thành

PR: syntax/lint/typecheck phù hợp stack -> tests -> build -> security checks phù hợp -> artifacts. Pin third-party actions bằng full SHA, permissions tối thiểu, không secrets trong fork PR, không `pull_request_target` để chạy mã không tin cậy.

CD: dùng artifact từ source đã kiểm tra, promote qua staging -> smoke/runtime -> production đúng phạm vi đã được cho phép; có version, migration plan và rollback. Không rebuild từ source khác sau khi review. Docker chỉ bắt buộc nếu sản phẩm dùng Docker hoặc có yêu cầu dự án; lúc đó build và chạy image từ source cuối trước Git publication theo quy tắc dự án.

Toolkit hiện tại có CI kiểm thử PowerShell và đóng gói kit; chưa có service/cloud target để deploy. Không tạo job giả “deploy production” hoặc tự thêm credentials khi chưa có đích triển khai.

## Tiến độ và bàn giao

`WORK-BOARD.md` là nguồn tiến độ của dự án: phase/task, owner, trạng thái, phụ thuộc, acceptance, bằng chứng và việc tiếp theo. Cập nhật khi đổi phase, xong task, bị chặn hoặc yêu cầu vai trò khác; không ghi “done” chỉ vì đã viết mã.

Handoff ngắn: `Task -> From/To -> What changed -> Evidence -> Open issue -> Requested action`. ChatGPT và local trả report; Codex cập nhật board và thực hiện handoff bằng công cụ đã được cho phép. Không giả vờ có nhiều bộ phận đang chạy nếu chỉ một agent đảm nhận các vai trò tuần tự.

Người dùng nhận cập nhật ngắn khi có tiến triển hoặc lỗi đáng chú ý; trong lượt làm việc dài không im lặng quá 60 giây. Việc nhỏ không cần plan dài; việc lớn chia phase có thể nghiệm thu độc lập.
