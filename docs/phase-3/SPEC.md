# Phase 3 Specification — Change Request "Đèn cạn dầu"

## 1. Nhiên liệu Đèn
- `fuel_max = 100`, đơn vị nguyên mô phỏng `1/60` mỗi tick.
- Khi vừa thắp (lần đầu hoặc thắp lại): `fuel = 100`.
- Đèn đang sáng tiêu hao tự nhiên `1.0` fuel/giây (`1/60` mỗi tick).
- Khi tương tác ở đèn đang sáng:
  - `used = min(carried, ceil((100 - fuel) / 10))`
  - `fuel = min(100, fuel + 10 * used)`
  - Giảm `used` đom đóm trong kho đồ.
  - Đèn đầy dầu (`used == 0`) không được chọn, không phát sự kiện, không cộng điểm.
- Ưu tiên chọn đèn tương tác trong bán kính $\le 2.0\text{ m}$: chỉ xét đèn nhận được (chưa sáng hoặc sáng nhưng chưa đầy dầu), gần nhất; bằng khoảng cách thì chọn `id` nhỏ hơn.
- Khi `fuel <= 0`: Đèn tắt, `deposited = 0`, ghi nhớ `ever_lit = true`, phát sự kiện `lantern_out`.
- Thắp lại đèn (`ever_lit == true`): chỉ tốn 5 đom đóm (thay vì 10).
- Hiển thị: thanh dầu trên đèn đang sáng; khi `fuel < 30` thì nhấp nháy 1 Hz.

## 2. Bóng Mực Hút Dầu
- Đèn có `fuel < 30` mất vùng an toàn 6m.
- Bóng Mực `wander` tự động di chuyển về phía đèn sáng có `fuel < 30` gần nhất (bằng nhau thì chọn `id` nhỏ hơn); nếu không có thì tìm đèn tắt gần nhất.
- Khi cách đèn yếu $\le 2\text{ m}$ (XZ): chuyển sang trạng thái `drain`, đứng yên và hút 5 fuel/giây (cộng dồn nếu nhiều con).
- Phát sự kiện `fuel_drain` mỗi 60 tick đang hút.
- Rời khỏi `drain`: sang `chase` nếu người chơi vào phạm vi 6m; sang `stunned` nếu trúng Pulse; sang `wander` nếu đèn tắt, nếu đèn được châm lên $\ge 30$, hoặc cách đèn $> 2\text{ m}$.
- Châm dầu lên $\ge 30$ khi có Bóng Mực trong vùng 6m: đẩy các con đó ra mép vùng trong tối đa 30 tick và không gây sát thương trong lúc đó.

## 3. Điều Kiện Thắng & Kết Thúc
- Thời gian Đêm 1: 240s, Đêm 2: 270s, Đêm 3: 300s.
- Thắng: Hết giờ (bình minh) mà người chơi còn sống và số đèn đang sáng tại tick cuối $\ge \lceil 0.6 \times \text{tổng đèn} \rceil$ (Đêm 1: 3/5, Đêm 2: 4/6, Đêm 3: 5/7) -> lý do `dawn_survived`.
- Thua: Hết Ngọn Lửa (`no_flames`) hoặc hết giờ mà không đủ số đèn sáng tối thiểu (`dawn`).
- Thứ tự xử lý tick: Trừ dầu (tự nhiên + bị hút) -> Tắt đèn nếu `fuel <= 0` -> Di chuyển/tương tác -> Đánh giá thắng/thua ở cuối tick (hết Ngọn Lửa luôn thua `no_flames` trước).

## 4. Sức Chứa Tăng Dần (Progressive Capacity)
- Sức chứa $= \min(20, 10 + 2 \times \text{successful\_lights})$.
- `successful_lights` = số lần thắp thành công trong Đêm (tính cả thắp mới và thắp lại; đèn đặt sẵn qua scenario không tính). Đặt lại về 0 ở đầu mỗi Đêm.

## 5. Điểm Số Mới
- Mỗi đom đóm nạp (thắp mới, thắp lại hoặc châm dầu): +5
- Thắp lần đầu: +100
- Thắp lại: +40
- Choáng Bóng Mực: +5 thường, +15 nếu đang `drain`
- Bình minh (chỉ khi thắng): mỗi đèn đang sáng $+50 + \lfloor\text{fuel}\rfloor$; mỗi Ngọn Lửa còn lại $+50$
- Thưởng thời gian: 0

## 6. Chế Độ Mù Màu (Colorblind Mode)
- Cài đặt "Bảng màu dễ phân biệt" (được lưu vào `settings.cfg`):
  - Viền và mắt Bóng Mực: đổi từ `#7A3CFF` sang `#00B3FF`.
  - Màu cảnh báo UI: đổi từ `#FF5A5F` sang `#FFFFFF`, kèm biểu tượng ⚠.
  - Đèn tắt bị xẹp 20% và giấy có vết rách; đèn sắp hết dầu nhấp nháy.
