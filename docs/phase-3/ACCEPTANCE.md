# Phase 3 Acceptance Status

Theo dõi tiến độ nghiệm thu Ticket-03 (Phase 3 — Contract v1.2):

| Khu vực | Tiêu chí nghiệm thu | Trạng thái / Bằng chứng |
|---|---|---|
| Contract v1.2 | Tuning đầy đủ, CLI validation, snapshot & event schema mới | Complete; `game.contract.json` v1.2, xác thực qua `tests/test_phase3_contract.py` (10/10 PASS) |
| Nhiên liệu đèn | Hao $1.0\text{ fuel/s}$, tắt đèn khi $\le 0$, phát `lantern_out`, `ever_lit = true` | Complete; trace `proof/fuel-decay.jsonl`, xác thực trong unit test và runtime checks |
| Châm dầu & Thắp lại | Tương tác châm dầu, thắp lại tốn 5 motes, phát `refuel` & `lantern_lit` (`relight: true`) | Complete; traces `proof/refuel.jsonl`, `proof/relight.jsonl`, xác thực runtime Godot |
| Bóng Mực hút dầu | Tìm đèn `fuel < 30`, trạng thái `drain` hút $5\text{ fuel/s}$, sự kiện `fuel_drain` | Complete; trace `proof/shade-drain.jsonl`, xác thực trong contract test và runtime checks |
| Pulse ngắt drain | Pulse trúng bóng đang `drain` cộng +15 điểm, đẩy an toàn khi fuel $\ge 30$ | Complete; xác thực trong `test_phase3_contract.py` và `run_godot_phase3_runtime_checks.py` |
| Sức chứa tăng dần | Tăng $+2$ mỗi lần thắp thành công, tối đa 20 | Complete; xác thực trong `test_phase3_contract.py` và `run_godot_phase3_runtime_checks.py` |
| Luật thắng bình minh | Thắng `dawn_survived` khi $\ge 60\%$ đèn sáng lúc hết giờ, không còn thắng sớm | Complete; trace `proof/dawn-survive.jsonl`, xác thực không thắng sớm khi time_left > 0 |
| Luật thua | Hết ngọn lửa thua `no_flames` (kể cả tick cuối), thiếu đèn thua `dawn` | Complete; xác thực trong test suite v1.2 |
| Công thức điểm mới | +5 nạp mote, +100 thắp đầu, +40 thắp lại, +5/+15 stun, điểm bình minh | Complete; áp dụng toàn diện trên `game/headless.py` và `game/main.gd` |
| Chế độ mù màu | Bảng màu dễ phân biệt, màu viền/mắt xanh, biểu tượng ⚠ cảnh báo, đèn xẹp/rách | Complete; lưu `settings.cfg`, kiểm tra runtime trong `run_godot_phase3_runtime_checks.py` |
| Kiểm thử tự động | Test suite v1.2 & Godot runtime checks | Complete; `test_phase3_contract.py` (10/10 PASS), `run_godot_phase3_runtime_checks.py` (PASS) |
| Bằng chứng nghiệm thu | Scenario traces & benchmark 21,600 ticks | Complete; 21,600 ticks trong ~0.26s, SHA-256 khớp tuyệt đối (`DD37CBEBADA1E9263BDD3954B9BE84CF01C76E664EF0162FB4B41B727368CCB8`), 180 FPS tại 1280x720 |

Toàn bộ các tiêu chí nghiệm thu của Phase 3 đã hoàn thành với đầy đủ bằng chứng và test tự động.
