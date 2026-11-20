# Phase 3 Changelog — Breaking Changes (Ticket-03)

Phiên bản hợp đồng: `v1.2` (thay thế `v1.1`).

## 1. Thay đổi phá vỡ tương thích (Breaking Changes)

### 1.1. Điều kiện thắng cuộc
- **Cũ (v1.1)**: Game kết thúc thắng ngay lập tức với lý do `all_lit` khi đèn cuối cùng được thắp sáng.
- **Mới (v1.2)**: Không còn thắng sớm. Thắp đủ đèn vẫn tiếp tục chơi cho tới khi hết thời gian đêm. Thắng cuộc đạt được khi hết giờ (bình minh) với lý do `dawn_survived` nếu số đèn đang sáng $\ge \lceil 0.6 \times \text{tổng đèn} \rceil$.

### 1.2. Trạng thái và vòng đời của Đèn
- **Cũ (v1.1)**: Đèn khi đã thắp sáng sẽ vĩnh viễn sáng, không bao giờ tắt và không nhận thêm đom đóm.
- **Mới (v1.2)**: Đèn tiêu hao dầu liên tục ($1.0$ đơn vị/giây). Đèn hết dầu (`fuel <= 0`) sẽ bị tắt (`deposited = 0`, phát sinh sự kiện `lantern_out`). Đèn sáng có thể nhận thêm đom đóm để châm dầu (`refuel`). Đèn từng sáng chỉ cần 5 đom đóm để thắp lại.

### 1.3. Vùng an toàn và hành vi Bóng Mực
- **Cũ (v1.1)**: Đèn đang sáng luôn tạo vùng an toàn bán kính 6m ngăn chặn tuyệt đối Bóng Mực.
- **Mới (v1.2)**: Đèn có `fuel < 30` bị mất vùng an toàn. Bóng Mực lang thang sẽ chủ động tìm tới đèn yếu này và chuyển sang trạng thái mới `drain`, hút $5.0$ fuel/giây.

### 1.4. Công thức tính điểm
- **Cũ (v1.1)**: $+10$ điểm mỗi đom đóm nạp; $+100$ khi thắp đèn; $+5$ khi làm choáng; $+2$ điểm mỗi giây còn lại khi thắng sớm; $+50$ mỗi ngọn lửa còn lại.
- **Mới (v1.2)**:
  - $+5$ điểm mỗi đom đóm nạp (thắp mới, thắp lại hoặc châm dầu).
  - $+100$ điểm khi thắp lần đầu.
  - $+40$ điểm khi thắp lại.
  - $+5$ điểm khi làm choáng thường; $+15$ điểm khi làm choáng Bóng Mực đang ở trạng thái `drain`.
  - Bỏ hoàn toàn thưởng thời gian còn lại ($0$ điểm).
  - Khi bình minh và thắng cuộc: mỗi đèn đang sáng nhận $+50 + \lfloor\text{fuel}\rfloor$ điểm; mỗi Ngọn Lửa còn lại nhận $+50$ điểm.

### 1.5. Thời lượng Đêm
- Đêm 1: giảm từ $300\text{ s} \to 240\text{ s}$.
- Đêm 2: giảm từ $330\text{ s} \to 270\text{ s}$.
- Đêm 3: giảm từ $360\text{ s} \to 300\text{ s}$.

### 1.6. Schema Snapshot & Event của Test Contract
- Snapshot `lanterns[]`: thêm `fuel` (float 1 chữ số thập phân), `ever_lit` (bool), `relit_count` (int).
- Snapshot `player`: thêm `capacity` (int).
- Snapshot `shades[]`: trạng thái có thêm `"drain"`.
- Sự kiện mới:
  - `refuel`: `{"lantern_id": String, "amount": int, "fuel": float}`
  - `lantern_out`: `{"lantern_id": String}`
  - `fuel_drain`: `{"lantern_id": String, "shade_id": String, "fuel": float}` (ghi mỗi 60 tick khi đang hút)
  - `lantern_lit`: thêm trường `relight: bool`
  - `game_over`: `reason` có thêm `"dawn_survived"`, loại bỏ `"all_lit"`.
