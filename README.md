# LocalQuiz BLE - Ứng Dụng Thi Trắc Nghiệm Ngoại Tuyến Qua Bluetooth Low Energy

## 1. Giới thiệu dự án
**LocalQuiz BLE** là ứng dụng di động Flutter hỗ trợ tổ chức thi và làm bài trắc nghiệm hoàn toàn ngoại tuyến (offline 100%) mà không cần Internet hay Wi-Fi, sử dụng giao thức **Bluetooth Low Energy (BLE)** giữa máy Giám thị (Host / Peripheral) và máy Thí sinh (Client / Central).

Hệ thống tích hợp công nghệ **Geofencing dựa trên cường độ sóng RSSI** để phát hiện thí sinh rời khỏi phòng thi và kích hoạt chế độ **Kiosk Anti-Cheat** chống gian lận.

---

## 2. Điểm nổi bật về công nghệ & Kiến trúc
- **Truyền nhận dữ liệu đề thi & bài nộp qua BLE:**
  - Máy Giám thị (Peripheral): Khởi tạo GATT Server, phát tín hiệu Advertising qua `SERVICE_UUID`.
  - Đặc tính `CHAR_EXAM_DATA` (Read/Notify): Phát đề thi phân mảnh đã nén và mã hóa.
  - Đặc tính `CHAR_SUBMIT_RESULT` (Write with Response): Tiếp nhận kết quả nộp bài từ thí sinh và phản hồi gói tin xác nhận ACK.
- **Phân mảnh gói tin (Packet Chunking Protocol):**
  - Cấu trúc Binary Header 8 bytes: `[ChunkIndex, TotalChunks, CRC32, Payload]`.
  - Nén dữ liệu đề thi JSON bằng **GZip**.
  - Mã hóa an toàn chuẩn quân đội **AES-256-CBC**.
  - Kiểm tra toàn vẹn bit bằng mã băm **CRC32 / MD5**, ném ngoại lệ nếu gói tin bị suy hao hoặc hỏng hóc trên đường truyền.
- **Kiểm soát phạm vi làm bài qua RSSI (Geofencing):**
  - Heartbeat BLE định kỳ đọc RSSI mỗi 3 giây.
  - `RSSI >= -75 dBm`: Vùng an toàn trong phòng thi (Huy hiệu Xanh lá).
  - `-85 dBm <= RSSI < -75 dBm`: Cảnh báo cách xa phòng thi (Huy hiệu Vàng hổ phách).
  - `RSSI < -85 dBm` hoặc mất kết nối quá 10 giây: Kích hoạt modal phủ mờ khóa giao diện và **đóng băng đồng hồ đếm ngược**.
- **Chế độ Kiosk chống gian lận (Anti-Cheat):**
  - Cấm chụp màn hình và quay video (`FLAG_SECURE`).
  - Lắng nghe sự kiện vòng đời `AppLifecycleState`: Đếm số lần thí sinh thoát ứng dụng hoặc bật chia đôi màn hình / đa nhiệm. Tự động nộp bài khi vi phạm quá 3 lần.
  - Đồng hồ làm bài độc lập chống tua giờ hệ điều hành.
- **Hỗ trợ Chế độ Mô phỏng (BLE Simulator Mode):**
  - Cho phép kiểm thử đầy đủ luồng mạng, trượt thanh RSSI giả lập ngay trên 1 thiết bị hoặc Emulator.

---

## 3. Cấu trúc thư mục mã nguồn
Mã nguồn Flutter nằm trong thư mục `apptracngiem/`:
```
apptracngiem/
├── lib/
│   ├── core/
│   │   ├── constants/        # UUIDs, ngưỡng RSSI, màu sắc Neumorphism/Glassmorphism
│   │   ├── security/         # AES-256, GZip, CRC32, Chunk Protocol, Kiosk Manager
│   │   ├── storage/          # Local Encrypted Cache
│   │   ├── theme/            # Dark Theme, Google Fonts
│   │   └── utils/            # RSSI calculations, BLE Permissions
│   ├── models/               # ExamModel, QuestionModel, SubmissionModel, BlePacketModel
│   ├── services/             # BleCentralService, BlePeripheralService, MockBleService
│   ├── providers/            # Riverpod StateNotifiers (Geofence, ExamSession, BLE Streams)
│   └── ui/                   # Screens & Reusable Glassmorphic/Neumorphic Widgets
└── test/
    └── chunk_protocol_test.dart # 11 Unit Tests kiểm thử bảo mật và phân mảnh gói tin
```

---

## 4. Hướng dẫn chạy ứng dụng
1. Cài đặt các thư viện phụ thuộc:
   ```bash
   cd apptracngiem
   flutter pub get
   ```
2. Chạy bộ kiểm thử tự động:
   ```bash
   flutter test
   ```
3. Khởi chạy ứng dụng:
   ```bash
   flutter run
   ```
