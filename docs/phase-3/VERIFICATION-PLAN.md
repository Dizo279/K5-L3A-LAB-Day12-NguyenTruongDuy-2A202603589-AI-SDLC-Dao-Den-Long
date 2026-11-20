# Phase 3 Verification Plan

| Khu vực kiểm tra | Kịch bản / Công cụ kiểm tra | Kết quả mong đợi |
|---|---|---|
| Nhiên liệu & Hao hụt | Scenario test headless | Đèn sáng hao $1.0\text{ fuel/s}$, hết dầu tắt đèn, phát sự kiện `lantern_out`, `ever_lit = true` |
| Châm dầu (Refuel) | Scenario test tương tác | Tương tác châm dầu chính xác công thức, trừ đom đóm, phát `refuel`, bỏ qua đèn đầy dầu |
| Thắp lại (Relight) | Scenario test relight | Đèn đã từng sáng thắp lại chỉ tốn 5 đom đóm, phát `lantern_lit` với `relight: true`, cộng +40 điểm |
| Bóng Mực hút dầu | Scenario test drain | Bóng lang thang tìm tới đèn `fuel < 30`, chuyển `drain` khi $\le 2\text{m}$, hút $5.0\text{ fuel/s}$, phát `fuel_drain` mỗi 60 tick |
| Pulse ngắt drain | Scenario test pulse drain | Pulse làm choáng Bóng đang `drain` mang lại +15 điểm thay vì +5 |
| Đẩy an toàn khi châm dầu | Scenario test safe push | Châm dầu đèn lên $\ge 30$ đẩy bóng trong 6m ra mép vùng |
| Sức chứa tăng dần | Scenario test capacity | Thắp thành công tăng capacity $+2$ (tối đa 20), đặt lại về 10 khi bắt đầu Đêm mới |
| Luật thắng mới | Scenario test dawn | Hết giờ đủ $\ge 60\%$ đèn sáng: thắng với `dawn_survived`, cộng điểm đèn + floor(fuel) + ngọn lửa |
| Luật thua mới | Scenario test no_flames & dawn | Hết Ngọn Lửa thua `no_flames` (kể cả tick cuối); hết giờ thiếu đèn thua `dawn` |
| Test Contract v1.2 | Unittest suite `tests/test_phase3_contract.py` | Kiểm thử toàn diện 100% logic hợp đồng v1.2 |
| Runtime Godot Suite | `tests/run_godot_phase3_runtime_checks.py` | 100% assertions đồ họa, thanh nhiên liệu, nhấp nháy, chế độ mù màu và flow |
| Hiệu năng & Tất định | Benchmark 21,600 ticks | Hoàn thành $< 30\text{ s}$, mã băm lặp lại trùng khớp |
