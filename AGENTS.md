# LocalQuiz BLE & Cloud Sync - Agent Guidelines & Context

Tài liệu này cung cấp hướng dẫn, kiến trúc kỹ thuật và quy chuẩn phát triển dành cho các AI Coding Agents (Antigravity, Cursor, Claude Code, Windsurf, Copilot,...) khi đọc và làm việc trên codebase này.

---

## 1. TỔNG QUAN HỆ THỐNG: MÔ HÌNH HYBRID ONLINE - OFFLINE - ONLINE
**LocalQuiz BLE & Cloud Sync** là hệ sinh thái tổ chức thi trắc nghiệm ngoại tuyến kết hợp đồng bộ điện toán đám mây:
1. **Khâu 1: Trước ca thi (ONLINE - Có mạng):**
   - Giảng viên đăng nhập tài khoản qua **FastAPI Backend** (`/api/v1/auth/login`).
   - Tải gói đề thi trọn gói (`/api/v1/exams/{id}/package`) và lưu mã hóa AES-256 cục bộ vào điện thoại.
   - Thí sinh **không cần tài khoản, không cần Internet**, chỉ mở app sẵn sàng.
2. **Khâu 2: Trong ca thi (OFFLINE 100% - Không cần Internet):**
   - Giảng viên tắt mạng (hoặc phòng thi mất sóng), mở **BLE Peripheral (GATT Server)** phát sóng đề thi mã hóa phân mảnh (Chunking MTU 512).
   - Thí sinh mở app, nhập SBD và Họ tên, đóng vai trò **BLE Central** quét radar tìm phòng thi, nhận đề thi phân mảnh, làm bài thi.
   - Hệ thống tự động đo **RSSI Geofencing** (ngưỡng -85 dBm đóng băng bài thi) và bật chế độ **Kiosk Anti-Cheat** (`FLAG_SECURE`, cấm thoát app quá 3 lần).
   - Thí sinh nộp bài ngược về máy Giảng viên qua BLE và nhận gói tin ACK xác nhận.
3. **Khâu 3: Sau ca thi (ONLINE - Có mạng trở lại):**
   - Giảng viên bật lại Wi-Fi/4G.
   - Bấm nút **"ĐỒNG BỘ LÊN CLOUD (Sync to Server)"** trên `HostDashboardScreen`.
   - Toàn bộ danh sách bài nộp và điểm số được gửi qua RESTful API (`POST /api/v1/exams/{id}/sync-submissions`) lên **FastAPI Backend** để lưu DB, tính điểm TB, xuất file Excel (`.xlsx`).

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

## 4. CẤU TRÚC TOÀN BỘ CODEBASE

```
LapTrinhDiDong/
├── backend/                                   # FastAPI Backend (Python)
│   ├── app/
│   │   ├── config.py                          # Cấu hình Secret Key, DB URL, JWT
│   │   ├── database.py                        # SQLAlchemy Session & Engine
│   │   ├── models.py                          # User, Exam, ExamSession, Submission
│   │   ├── schemas.py                         # Pydantic Schemas
│   │   ├── security.py                        # JWT Auth & Bcrypt Hashing
│   │   ├── seed_data.py                       # Dữ liệu mẫu (teacher@localquiz.edu.vn / 123456)
│   │   ├── main.py                            # FastAPI App & CORS
│   │   └── routes/
│   │       ├── auth.py                        # Đăng ký, Đăng nhập Giảng viên
│   │       └── exams.py                       # Đề thi, Tải package, Sync bài nộp, Báo cáo & Excel
│   ├── run_server.py                          # Khởi chạy máy chủ backend (Port 8000)
│   ├── requirements.txt                       # Thư viện Python
│   └── tests/test_api.py                      # Bộ test tự động FastAPI (7/7 pass)
└── apptracngiem/                              # Flutter Mobile App
    ├── lib/
    │   ├── core/constants/                    # BleConstants, AppColors
    │   ├── core/security/                     # AES, GZip, Chunk Protocol, Kiosk Manager
    │   ├── core/storage/                      # LocalExamStorage (Multi-exam caching & Drafts)
    │   ├── services/                          # ApiService, BleCentral, BlePeripheral, MockBle
    │   ├── providers/                         # AuthNotifier, GeofenceNotifier, ExamSessionNotifier
    │   └── ui/screens/
    │       ├── home_role_select_screen.dart   # Trang chủ phân luồng Thí sinh & Giảng viên
    │       ├── teacher/                       # TeacherLoginScreen, TeacherExamListScreen
    │       ├── student/                       # DiscoveryRadar, Download, Taking, Review, Result
    │       └── host/                          # HostDashboardScreen (Live BLE & Sync to Cloud)
    └── test/                                  # 23 Automated Flutter Tests (23/23 pass)
```

---

## 5. LỆNH CHUẨN ĐỂ VERIFY TRƯỚC KHI COMMIT (AGENT RUNBOOK)

Mọi thay đổi code của Agent phải thỏa mãn các lệnh kiểm tra sau:

```bash
# 1. Khởi chạy Backend (Terminal 1)
cd backend
python run_server.py
# Chạy bộ test backend:
python tests/test_api.py

# 2. Kiểm tra tĩnh & Chạy tests Flutter (Terminal 2)
cd apptracngiem
flutter analyze   # Phải đạt 0 lỗi, 0 cảnh báo
flutter test      # Phải pass 23/23 tests
```
