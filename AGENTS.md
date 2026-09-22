# LocalQuiz BLE - Agent Guidelines & Context

Tài liệu này cung cấp hướng dẫn, kiến trúc kỹ thuật và quy chuẩn phát triển dành cho các AI Coding Agents (Antigravity, Cursor, Claude Code, Windsurf, Copilot,...) khi đọc và làm việc trên codebase này.

---

## 1. TỔNG QUAN DỰ ÁN & VAI TRÒ HỆ THỐNG
**LocalQuiz BLE** là ứng dụng di động Flutter tổ chức thi trắc nghiệm ngoại tuyến 100% sử dụng **Bluetooth Low Energy (BLE)** giữa hai vai trò:
- **Host (Giám thị):** Đóng vai trò GATT Server (Peripheral) phát tín hiệu quảng bá đề thi và tiếp nhận kết quả nộp bài.
- **Client (Thí sinh):** Đóng vai trò GATT Client (Central) quét tìm phòng thi, tải đề thi mã hóa theo từng chunk, làm bài và nộp bài.
- **Kiểm soát phạm vi (RSSI Geofencing):** Tự động đóng băng đồng hồ và khóa màn hình làm bài khi tín hiệu suy yếu hoặc thí sinh rời khỏi phòng thi.
- **Chế độ Kiosk chống gian lận:** Cấm chụp màn hình (`FLAG_SECURE`), phát hiện chuyển app/bật đa nhiệm, tự động nộp bài sau 3 lần vi phạm.

---

## 2. KIẾN TRÚC MẠNG & THÔNG SỐ BLE BẮT BUỘC

Khi chỉnh sửa hoặc mở rộng mã nguồn BLE, Agent **BẮT BUỘC** tuân thủ các hằng số và chuẩn giao thức sau (được định nghĩa tập trung tại `lib/core/constants/ble_constants.dart`):

```dart
// UUID Chuẩn
static const String serviceUuid = '0000fef0-0000-1000-8000-00805f9b34fb';
static const String charExamDataUuid = '0000fef1-0000-1000-8000-00805f9b34fb';      // Read / Notify
static const String charSubmitResultUuid = '0000fef2-0000-1000-8000-00805f9b34fb';  // Write with Response

// Ngưỡng RSSI (dBm)
static const int rssiOptimalThreshold = -75;     // >= -75 dBm: Tín hiệu tốt
static const int rssiWarningThreshold = -85;     // -85 đến -75 dBm: Cảnh báo xa nguồn
// < -85 dBm hoặc mất kết nối > 10s: Ngoài vùng thi -> Đóng băng bài thi

// ATT MTU & Phân mảnh
static const int requestedMtu = 512;
static const int defaultChunkPayloadSize = 380;
```

---

## 3. GIAO THỨC ĐÓNG GÓI & BẢO MẬT (PACKET CHUNKING PROTOCOL)

Do giới hạn MTU của Bluetooth Low Energy, toàn bộ đề thi được truyền qua giao thức phân mảnh tại `lib/core/security/chunk_protocol.dart`:

1. **Chu trình đóng gói phía Giám thị (Host):**
   `Chuỗi JSON Đề thi` $\rightarrow$ `GZip Compress` $\rightarrow$ `AES-256-CBC Encrypt` $\rightarrow$ `Tính CRC32 trên toàn bộ khối mã hóa` $\rightarrow$ `Chia nhỏ thành các Chunk` kèm Header 8 bytes.
2. **Cấu trúc Binary Header 8 bytes của mỗi Chunk:**
   - Byte 0..1: `chunkIndex` (uint16 big-endian, 0-indexed)
   - Byte 2..3: `totalChunks` (uint16 big-endian)
   - Byte 4..7: `totalCrc32` (uint32 big-endian của toàn bộ khối mã hóa)
   - Byte 8..N: `payload` (Mảng bytes phân mảnh)
3. **Chu trình lắp ghép phía Thí sinh (Client):**
   Nhận từng chunk qua BLE Notification $\rightarrow$ Lưu vào `ReassemblyBuffer` $\rightarrow$ Khi đủ số gói: Khớp `CRC32` (ném `IntegrityException` nếu sai lệch) $\rightarrow$ `AES-256 Decrypt` $\rightarrow$ `GZip Decompress` $\rightarrow$ Parse JSON `ExamModel`.

---

## 4. QUY TRÌNH KIỂM SOÁT RSSI GEOFENCING & KIOSK MODE

- **Chu kỳ Heartbeat:** Gọi `device.readRssi()` mỗi 3 giây trong `lib/services/ble_central_service.dart`.
- **Cơ chế đóng băng:** `proximity_geofence_provider.dart` kích hoạt `isOutOfBounds = true` khi $\text{RSSI} < -85\text{ dBm}$ hoặc mất sóng $> 10\text{s}$. Lúc này `exam_session_provider.dart` lập tức dừng countdown timer và hiển thị `OutOfBoundsOverlay`.
- **Kiosk Anti-Cheat:** `lib/core/security/kiosk_manager.dart` đăng ký `WidgetsBindingObserver`. Khi bắt được `AppLifecycleState.paused`/`inactive`, tăng `violationCount`. Khi đạt $\ge 3$ lần, gọi `submitExam(isAutoSubmit: true)` thu bài tự động.

---

## 5. CẤU TRÚC CODEBASE & NƠI CẦN CAN THIỆP

```
apptracngiem/
├── lib/
│   ├── core/
│   │   ├── constants/        # Hằng số BLE & bảng màu AppColors
│   │   ├── security/         # AES, GZip, Chunk Protocol, Kiosk Manager
│   │   ├── storage/          # Local Encrypted Draft Cache
│   │   ├── theme/            # AppTheme, Neumorphic & Glassmorphic styles
│   │   └── utils/            # RSSI path loss calculations, Permissions
│   ├── models/               # ExamModel, QuestionModel, SubmissionModel, BlePacketModel
│   ├── services/             # BleCentralService, BlePeripheralService, MockBleService
│   ├── providers/            # Riverpod StateNotifiers (Geofence, ExamSession, BLE Streams)
│   └── ui/                   # Screens (Radar, Download, Taking, Result, Host Dashboard)
└── test/
    └── chunk_protocol_test.dart # 11 Unit Tests
```

---

## 6. LỆNH CHUẨN ĐỂ VERIFY TRƯỚC KHI COMMIT (AGENT RUNBOOK)

Mọi thay đổi code của Agent phải thỏa mãn 2 lệnh kiểm tra sau trong thư mục `apptracngiem`:

```bash
cd apptracngiem

# 1. Kiểm tra tĩnh: Phải đạt 0 lỗi, 0 cảnh báo
flutter analyze

# 2. Chạy bộ unit tests tự động: Phải pass 11/11 tests
flutter test
```

---

## 7. LƯU Ý KHI KIỂM THỬ TRÊN MÁY TÍNH / EMULATOR (MOCK SIMULATOR)
- Bluetooth Low Energy vật lý trên Android Emulator / PC thường không hỗ trợ đầy đủ vai trò Peripheral/Central đồng thời.
- Để Agent hoặc người dùng kiểm thử toàn diện giao diện, slider giả lập RSSI và quá trình tải chunk, luôn duy trì và sử dụng `lib/services/mock_ble_service.dart` khi bật toggle "Chế độ Mô phỏng (Simulator)" trên màn hình chính.
