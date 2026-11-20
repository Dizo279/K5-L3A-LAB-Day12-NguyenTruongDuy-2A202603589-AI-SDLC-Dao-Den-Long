# Test Contract — Phase 1 baseline

> Phase 2 supersedes this file with Contract v1.1. It is retained as the
> regression baseline required by Ticket-02.

## Mục đích

Xác nhận project Godot có thể được mở, phân tích và khởi động ở chế độ
headless mà không phụ thuộc vào giao diện người dùng.

## Lệnh chuẩn

Thay đường dẫn executable bằng vị trí Godot trên máy đang kiểm tra:

```powershell
& "D:\Godot_v4.7.2-stable_win64.exe" --headless --path .\game --editor --quit
```

## Tiêu chí nghiệm thu hiện tại

| ID | Hành vi | Kết quả mong đợi |
|---|---|---|
| P1-T01 | Godot quét project ở chế độ headless | Không có lỗi parse project hoặc scene |
| P1-T02 | Project có scene khởi động | `game/project.godot` trỏ tới `res://main.tscn` |
| P1-T03 | Scene khởi động được tải | Scene có node gốc `Main` kiểu `Node3D` |

## Quy tắc bằng chứng

- Lưu nguyên output lệnh, không sửa tay output.
- Ghi commit/tag tương ứng với kết quả kiểm tra.
- Nếu tiêu chí chưa đạt, ghi rõ `chưa đạt` và nguyên nhân.

## Phạm vi chưa có

Contract này chưa kiểm tra gameplay, điều khiển, đồ họa, âm thanh hoặc hiệu
năng. Các yêu cầu đó sẽ được bổ sung khi ticket của phase tương ứng được phát hành.

