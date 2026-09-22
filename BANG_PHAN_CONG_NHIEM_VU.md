# BẢNG PHÂN CÔNG NHIỆM VỤ DỰ ÁN "LOCALQUIZ BLE"

* **Tên đề tài:** LocalQuiz BLE – Hệ Thống Thi Trắc Nghiệm Ngoại Tuyến Qua Bluetooth Low Energy & Giới Hạn Phạm Vi Làm Bài Bằng RSSI Geofencing.
* **Nền tảng phát triển:** Flutter (SDK >= 3.22, Dart >= 3.4).
* **Số lượng thành viên:** 03 người.
* **Repository:** [https://github.com/nhathoangnguyen1748/LapTrinhDiDong.git](https://github.com/nhathoangnguyen1748/LapTrinhDiDong.git)

---

## 1. TỔNG QUAN PHÂN CHIA VAI TRÒ & TỈ LỆ ĐÓNG GÓP

| STT | Thành Viên | Nhánh Git | Vai Trò Chuyên Môn | Tỉ Lệ Hoàn Thành |
|---|---|---|---|:---:|
| 1 | **Nguyễn Nhật Hoàng** | `HoangNhat` | **Trưởng nhóm / Core BLE & Security Protocol** | 100% |
| 2 | **Trung Lương** | `TrungLuong` | **Kỹ sư RSSI Geofencing & Kiosk Anti-Cheat** | 100% |
| 3 | **Quang Minh** | `QuangMinh` | **Kỹ sư UI/UX & Flow Screens Engineering** | 100% |

---

## 2. CHI TIẾT NHIỆM VỤ TỪNG THÀNH VIÊN

### 1. NGUYỄN NHẬT HOÀNG (Nhánh: `HoangNhat`)
> **Vai trò:** Team Leader – Chịu trách nhiệm kiến trúc mạng BLE, giao thức phân mảnh dữ liệu và bảo mật mã hóa.

* **Nhiệm vụ đảm nhận:**
  1. **Quản trị Git & Kiến trúc hệ thống:** Khởi tạo cấu trúc dự án, quản lý mã nguồn trên GitHub, review code và thực hiện merge Pull Request vào nhánh `main`.
  2. **Giao thức Packet Chunking (Phân mảnh MTU):**
     - Đóng gói dữ liệu đề thi nhị phân với Header 8 bytes: `[ChunkIndex, TotalChunks, CRC32, Payload]`.
     - Xây dựng bộ đệm `ReassemblyBuffer` tại Client để ghép nối các chunk theo thứ tự bất đồng bộ.
  3. **Mã hóa & Kiểm tra toàn vẹn:**
     - Tích hợp nén dữ liệu đề thi JSON bằng **GZip**.
     - Mã hóa và giải mã đề thi sử dụng chuẩn **AES-256-CBC**.
     - Kiểm tra toàn vẹn bit bằng mã băm **CRC32** và **MD5**, chống giả mạo hoặc mất gói tin.
  4. **Dịch vụ mạng BLE hai chiều:**
     - **Central (Thí sinh):** Quét tín hiệu theo `SERVICE_UUID`, đàm phán MTU 512 bytes, nhận chunk qua Notification `CHAR_EXAM_DATA`, ghi bài nộp vào `CHAR_SUBMIT_RESULT`.
     - **Peripheral (Giám thị):** Khởi tạo GATT Server phát sóng đề thi và tiếp nhận kết quả nộp bài.
     - **BLE Simulator:** Tạo môi trường mô phỏng để kiểm thử ứng dụng độc lập trên 1 thiết bị hoặc Emulator.
* **Các file & module phụ trách chính:**
  - `lib/core/constants/ble_constants.dart`
  - `lib/core/security/aes_encryption_service.dart`
  - `lib/core/security/compression_service.dart`
  - `lib/core/security/chunk_protocol.dart`
  - `lib/services/ble_central_service.dart`
  - `lib/services/ble_peripheral_service.dart`
  - `lib/services/mock_ble_service.dart`
  - `test/chunk_protocol_test.dart` (Bộ 11 unit tests kiểm thử giao thức)

---

### 2. TRUNG LƯƠNG (Nhánh: `TrungLuong`)
> **Vai trò:** Security & Systems Engineer – Chịu trách nhiệm thuật toán RSSI Geofencing, cơ chế đóng băng bài thi và chế độ Kiosk chống gian lận.

* **Nhiệm vụ đảm nhận:**
  1. **Đo lường & Phân loại sóng BLE (RSSI Geofencing):**
     - Xây dựng cơ chế Heartbeat ping định kỳ mỗi 3 giây đọc giá trị `readRssi()`.
     - Phân loại ngưỡng sóng:
       - `RSSI >= -75 dBm`: Vùng thi đạt chuẩn (Xanh lá).
       - `-85 dBm <= RSSI < -75 dBm`: Cảnh báo quá xa nguồn phát (Vàng hổ phách).
       - `RSSI < -85 dBm` hoặc mất kết nối quá 10 giây: Vi phạm phạm vi (Đỏ).
     - Ước tính khoảng cách thực tế (mét) dựa trên mô hình toán học suy hao Log-distance path loss.
  2. **Cơ chế đóng băng khẩn cấp (Exam Freezing):**
     - Đóng băng đồng hồ đếm ngược khi thí sinh vi phạm ngưỡng khoảng cách.
     - Kích hoạt màn hình khóa phủ mờ `OutOfBoundsOverlay`, tự động mở khóa tiếp tục khi quay lại vị trí an toàn.
  3. **Kiosk Mode & Chống gian lận:**
     - Kích hoạt cấm chụp màn hình và quay video (`FLAG_SECURE` trên Android qua `flutter_windowmanager`).
     - Bắt sự kiện vòng đời `AppLifecycleState`: Phát hiện hành vi chuyển app, bật đa nhiệm hoặc chia đôi màn hình; tự động thu bài nộp nếu vi phạm quá 3 lần.
  4. **Bộ nhớ lưu trữ ngoại tuyến (Local Storage):**
     - Tự động lưu nháp câu trả lời bài thi theo thời gian thực vào bộ nhớ mã hóa, chống mất bài khi sập nguồn đột ngột.
* **Các file & module phụ trách chính:**
  - `lib/core/utils/ble_rssi_helper.dart`
  - `lib/core/security/kiosk_manager.dart`
  - `lib/core/storage/local_exam_storage.dart`
  - `lib/providers/proximity_geofence_provider.dart`
  - `lib/providers/exam_session_provider.dart` (Đồng hồ đếm ngược & cơ chế vi phạm)
  - `lib/ui/common/out_of_bounds_overlay.dart`

---

### 3. QUANG MINH (Nhánh: `QuangMinh`)
> **Vai trò:** UI/UX Engineer – Chịu trách nhiệm thiết kế hệ thống giao diện Glassmorphism & Neumorphism, animation và toàn bộ luồng người dùng (Screen Flow).

* **Nhiệm vụ đảm nhận:**
  1. **Thiết kế Hệ thống Giao diện (Design System):**
     - Xây dựng bảng màu Glassmorphism tối sâu kết hợp đổ bóng nổi Neumorphic 3D.
     - Tích hợp typography hiện đại qua Google Fonts (Plus Jakarta Sans).
     - Xây dựng các widget dùng chung: `GlassCard`, `NeumorphicButton`, `RssiBadge` (4 vạch sóng đổi màu).
  2. **Hoạt ảnh Radar & Tìm phòng thi:**
     - Xây dựng `RadarPulseWidget`: Hoạt ảnh sóng xung kích và tia quét xoay 360 độ tìm kiếm phòng thi BLE.
     - Giao diện nhập thông tin thí sinh và danh sách phòng thi lân cận.
  3. **Tiến trình tải đề & Ghép Chunk:**
     - Vòng tròn tiến độ tải đề thời gian thực, hiển thị trạng thái xác thực CRC32 và giải mã AES-256.
  4. **Giao diện Làm bài thi & Điều hướng câu hỏi:**
     - Header tròn hiển thị đồng hồ và huy hiệu sóng Live RSSI.
     - Thanh Palette câu hỏi dạng lưới chấm tròn vuốt nhanh (đã làm / chưa làm / cờ xem lại).
     - Card câu hỏi và phương án A, B, C, D với hiệu ứng xúc giác `flutter_animate`.
  5. **Màn hình Nộp bài & Bảng điều khiển Giám thị:**
     - Xác nhận mã ACK thành công từ Giám thị, biểu đồ tròn tỉ lệ điểm số và phân tích kết quả.
     - Dashboard Giám thị: Quản lý phòng thi, mở phát sóng và theo dõi danh sách bài nộp theo thời gian thực.
* **Các file & module phụ trách chính:**
  - `lib/core/constants/app_colors.dart` & `lib/core/theme/app_theme.dart`
  - `lib/ui/common/glass_card.dart` & `lib/ui/common/neumorphic_button.dart`
  - `lib/ui/common/radar_pulse_widget.dart` & `lib/ui/common/rssi_badge.dart`
  - `lib/ui/screens/home_role_select_screen.dart`
  - `lib/ui/screens/student/discovery_radar_screen.dart`
  - `lib/ui/screens/student/exam_download_screen.dart`
  - `lib/ui/screens/student/exam_taking_screen.dart`
  - `lib/ui/screens/student/exam_result_screen.dart`
  - `lib/ui/screens/host/host_dashboard_screen.dart`

---

## 3. QUY TRÌNH PHỐI HỢP GIT GIỮA CÁC THÀNH VIÊN

1. **Nhận nhiệm vụ và checkout đúng nhánh cá nhân:**
   - Hoàng Nhật làm việc trên nhánh `HoangNhat`.
   - Trung Lương làm việc trên nhánh `TrungLuong`.
   - Quang Minh làm việc trên nhánh `QuangMinh`.
2. **Quy tắc Commit:**
   - Đặt commit rõ ràng theo chuẩn Conventional Commits: `feat:`, `fix:`, `docs:`, `test:`.
3. **Cập nhật và Gộp code:**
   - Mỗi khi một nhánh hoàn thành tính năng mới, tạo **Pull Request** từ nhánh cá nhân vào `main`.
   - Trưởng nhóm kiểm tra tính hợp lệ qua lệnh kiểm thử:
     ```bash
     flutter analyze  # Đảm bảo 0 lỗi lint
     flutter test     # Đảm bảo pass 100% unit tests
     ```
   - Sau khi merge vào `main`, các thành viên gõ `git pull origin main` để đồng bộ code mới nhất về nhánh của mình.

---

## 4. KỊCH BẢN THUYẾT TRÌNH BÁO CÁO VỚI GIẢNG VIÊN

* **Phần 1 – Nguyễn Nhật Hoàng (3-4 phút):**
  - Giới thiệu tổng quan bài toán: Nhu cầu thi trắc nghiệm ngoại tuyến không phụ thuộc Internet.
  - Phân tích kiến trúc mạng BLE GATT Server / Client và giải pháp Packet Chunking vượt qua rào cản MTU bằng nén GZip + mã hóa AES-256 + CRC32.
* **Phần 2 – Trung Lương (3-4 phút):**
  - Trình bày giải thuật Geofencing qua RSSI và mô hình suy hao tín hiệu theo khoảng cách.
  - Demo trực tiếp tính năng: Khi thí sinh di chuyển ra xa (hoặc chỉnh slider giả lập $< -85\text{ dBm}$), màn hình lập tức phủ mờ và đóng băng đồng hồ.
  - Demo tính năng Kiosk: Thoát app quá 3 lần bị tự động thu bài, cấm chụp màn hình.
* **Phần 3 – Quang Minh (3-4 phút):**
  - Trình bày phong cách thiết kế Neumorphism kết hợp Glassmorphism.
  - Demo luồng sử dụng: Quét radar tìm phòng $\rightarrow$ Tải đề $\rightarrow$ Trải nghiệm làm bài trên Palette chấm tròn $\rightarrow$ Nộp bài và nhận phản hồi ACK tức thì từ Giám thị.
