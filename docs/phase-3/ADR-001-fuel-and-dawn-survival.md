# ADR-001: Chuyển đổi mô hình trạng thái đèn cạn dầu và luật thắng giữ đảo tới bình minh

- **Trạng thái**: Accepted
- **Ngày**: 2026-11-20
- **Tác giả**: Nguyen Truong Duy (2A202603589)
- **Phạm vi**: Ticket-03 (Phase 3 — Contract v1.2)

---

## 1. Ngữ cảnh & Vấn đề (Context)

Trong Phase 1 và Phase 2, mục tiêu của người chơi là "thắp sáng toàn bộ số đèn trên đảo". Khi tất cả đèn được thắp sáng (`all_lit`), game ngay lập tức kết thúc thắng cuộc. Dữ liệu playtest cho thấy người chơi giỏi có thể hoàn thành việc thắp đèn chỉ trong khoảng 2 phút, dẫn tới việc thiếu căng thẳng và không có thử thách ở giai đoạn cuối Đêm.

Nhà thiết kế quyết định ban hành **TICKET-03 — Change Request "Đèn cạn dầu"**, chuyển đổi mô hình gameplay cốt lõi từ "thắp hết đèn để thắng sớm" sang "quản lý nhiên liệu và bảo vệ đảo sáng tới bình minh".

---

## 2. Quyết định Thiết kế (Decisions)

### 2.1. Mô hình trạng thái Đèn (Lantern State Machine)
- **Trước đây (Phase 1-2)**: Đèn có 2 trạng thái nhị phân: `unlit` ($deposited < 10$) và `lit` ($deposited = 10$). Đèn đã thắp sáng sẽ vĩnh viễn không tắt và không thể nhận thêm đom đóm.
- **Mới (Phase 3 - v1.2)**:
  - Đèn bổ sung biến trạng thái nhiên liệu `fuel` (tối đa 100) và cờ ghi nhớ `ever_lit` (đã từng sáng).
  - Khi được thắp sáng (lần đầu hoặc thắp lại): `fuel = 100`.
  - Khi đang sáng: tiêu hao tự nhiên $1.0$ đơn vị/giây ($\frac{1}{60}$ mỗi tick).
  - Đèn đang sáng có thể nhận thêm đom đóm để châm dầu (`refuel`): mỗi đom đóm hồi phục $+10$ fuel (tối đa 100).
  - Khi `fuel <= 0`: Đèn chuyển sang tắt, `deposited = 0`, phát sinh sự kiện `lantern_out`, mất ánh sáng và vùng an toàn.
  - Thắp lại đèn đã tắt (`ever_lit == true`): chỉ cần **5 đom đóm** (thay vì 10).

### 2.2. Hành vi Bóng Mực (Shade Target & Drain State)
- Đèn có `fuel < 30` bị mất vùng an toàn 6m (bằng 30 thì vẫn còn).
- Bóng Mực lang thang (`wander`) tự động nhắm tới đèn sáng yếu (`fuel < 30`) gần nhất (hoặc đèn tắt gần nhất).
- Khi tiếp cận đèn yếu $\le 2\text{ m}$, Bóng Mực chuyển sang trạng thái mới `drain`, đứng yên và hút $5.0$ fuel/giây.
- Đánh Tỏa Sáng (Pulse) vào Bóng Mực đang `drain` mang lại phần thưởng điểm cao hơn ($+15$ thay vì $+5$).

### 2.3. Luật Thắng/Thua và Đóng gói Thời gian (Win Condition & Survival)
- **Bãi bỏ hoàn toàn điều kiện thắng sớm `all_lit`**. Thắp đủ toàn bộ đèn không làm dừng game.
- Thời gian Đêm rút ngắn: Đêm 1 (240s), Đêm 2 (270s), Đêm 3 (300s).
- **Thắng (`dawn_survived`)**: Người chơi còn sống khi hết giờ và số đèn đang sáng tại tick cuối $\ge \lceil 0.6 \times \text{tổng đèn} \rceil$ (Đêm 1: 3/5, Đêm 2: 4/6, Đêm 3: 5/7).
- **Thua**: Hết Ngọn Lửa (`no_flames`) hoặc hết giờ mà không đủ số đèn sáng tối thiểu (`dawn`).
- Thứ tự trong tick: Trừ dầu ở đầu tick -> Tắt đèn nếu `fuel <= 0` -> Di chuyển/tương tác -> Đánh giá thắng/thua ở cuối tick (hết Ngọn Lửa luôn ưu tiên xử thua `no_flames` trước).

---

## 3. Hệ quả (Consequences)

- **Test Suite**: Các test giả định thắng sớm khi thắp hết đèn (`all_lit`) và công thức tính điểm cũ (thưởng thời gian còn lại) không còn hợp lệ và phải được thay thế bằng kịch bản bình minh sống sót `dawn_survived`.
- **Độ chính xác**: Toàn bộ tính toán hao hụt dầu được xử lý theo số nguyên tick $\frac{1}{60}$ để tránh sai số dấu phẩy động lũy kế.
- **Trải nghiệm người chơi**: Tạo ra vòng lặp tuần tra, phân bổ đom đóm giữa thắp đèn mới, châm dầu đèn cũ và xua đuổi Bóng Mực hút trộm dầu.
