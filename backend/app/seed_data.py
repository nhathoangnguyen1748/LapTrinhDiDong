import json
import datetime
from sqlalchemy.orm import Session
from .models import User, Exam, ExamSession, Submission
from .security import get_password_hash

def init_seed_data(db: Session):
    # 1. Khởi tạo tài khoản giảng viên mặc định
    teacher = db.query(User).filter(User.email == "teacher@localquiz.edu.vn").first()
    if not teacher:
        teacher = User(
            email="teacher@localquiz.edu.vn",
            hashed_password=get_password_hash("123456"),
            full_name="ThS. Nguyễn Văn Hùng",
        )
        db.add(teacher)
        db.commit()
        db.refresh(teacher)
        print("[Seed] Đã tạo tài khoản giảng viên: teacher@localquiz.edu.vn / 123456")

    admin = db.query(User).filter(User.email == "admin@localquiz.edu.vn").first()
    if not admin:
        admin = User(
            email="admin@localquiz.edu.vn",
            hashed_password=get_password_hash("admin123"),
            full_name="TS. Trần Đức Minh (Trưởng Bộ Môn)",
        )
        db.add(admin)
        db.commit()
        db.refresh(admin)
        print("[Seed] Đã tạo tài khoản quản trị: admin@localquiz.edu.vn / admin123")

    # 2. Đề thi mẫu 1: BLE & Mạng Không Dây
    exam1 = db.query(Exam).filter(Exam.id == "EXAM_2026_09").first()
    if not exam1:
        sample_questions_1 = [
            {
                "id": 1,
                "content": "Giao thức Bluetooth Low Energy (BLE) hoạt động ở dải băng tần vô tuyến nào?",
                "options": [
                    {"id": "A", "text": "2.4 GHz ISM Band"},
                    {"id": "B", "text": "5.0 GHz UNII Band"},
                    {"id": "C", "text": "900 MHz Sub-GHz"},
                    {"id": "D", "text": "433 MHz RFID"}
                ],
                "correct_option_id": "A"
            },
            {
                "id": 2,
                "content": "Giá trị RSSI (Received Signal Strength Indicator) đo bằng đơn vị nào?",
                "options": [
                    {"id": "A", "text": "Milliwatt (mW)"},
                    {"id": "B", "text": "Decibel-milliwatts (dBm)"},
                    {"id": "C", "text": "Microvolt (μV)"},
                    {"id": "D", "text": "Hertz (Hz)"}
                ],
                "correct_option_id": "B"
            },
            {
                "id": 3,
                "content": "Trong kiến trúc GATT của BLE, vai trò của thiết bị đóng vai trò lưu trữ cơ sở dữ liệu thuộc tính và phục vụ các yêu cầu đọc/ghi được gọi là gì?",
                "options": [
                    {"id": "A", "text": "GATT Client / Central"},
                    {"id": "B", "text": "GATT Server / Peripheral"},
                    {"id": "C", "text": "Broadcaster Observer"},
                    {"id": "D", "text": "Master Beacon"}
                ],
                "correct_option_id": "B"
            },
            {
                "id": 4,
                "content": "Kích thước gói tin mặc định ATT MTU trong chuẩn BLE 4.0/4.1 trước khi đàm phán mở rộng (MTU Exchange) là bao nhiêu bytes?",
                "options": [
                    {"id": "A", "text": "23 bytes (Payload thực tế 20 bytes)"},
                    {"id": "B", "text": "64 bytes"},
                    {"id": "C", "text": "128 bytes"},
                    {"id": "D", "text": "512 bytes"}
                ],
                "correct_option_id": "A"
            },
            {
                "id": 5,
                "content": "Khi mức tín hiệu RSSI suy giảm từ -70 dBm xuống -90 dBm, điều này phản ánh điều gì về mặt vật lý?",
                "options": [
                    {"id": "A", "text": "Thiết bị đang tiến lại gần bộ phát sóng hơn"},
                    {"id": "B", "text": "Thiết bị đang di chuyển ra xa hoặc bị vật cản lớn che chắn"},
                    {"id": "C", "text": "Băng thông BLE đang được tự động tăng gấp đôi"},
                    {"id": "D", "text": "Pin của thiết bị sắp hết"}
                ],
                "correct_option_id": "B"
            },
            {
                "id": 6,
                "content": "Mục đích của việc tính mã kiểm tra toàn vẹn CRC32/MD5 sau khi ghép các Chunk BLE là gì?",
                "options": [
                    {"id": "A", "text": "Tăng tốc độ truyền tải gói tin qua không trung"},
                    {"id": "B", "text": "Đảm bảo dữ liệu nhận được không bị mất mát hay sai lệch bit trong quá trình truyền BLE"},
                    {"id": "C", "text": "Tự động sửa lỗi bit mà không cần truyền lại"},
                    {"id": "D", "text": "Xác thực sinh trắc học của thí sinh"}
                ],
                "correct_option_id": "B"
            }
        ]

        exam1 = Exam(
            id="EXAM_2026_09",
            title="Kiểm tra Chuyên đề Mạng Không Dây & BLE",
            duration_seconds=1200,
            rssi_threshold=-80,
            room_pin="1234",
            questions_json=json.dumps(sample_questions_1, ensure_ascii=False),
            created_by_user_id=teacher.id,
        )
        db.add(exam1)
        db.commit()
        print("[Seed] Đã tạo đề thi mẫu 1: EXAM_2026_09")

    # 3. Đề thi mẫu 2: Kiến Trúc IoT
    exam2 = db.query(Exam).filter(Exam.id == "EXAM_IOT_2026").first()
    if not exam2:
        sample_questions_2 = [
            {
                "id": 1,
                "content": "Giao thức truyền thông nào sau đây hoạt động theo mô hình Publish/Subscribe nhẹ trên nền TCP/IP dành cho IoT?",
                "options": [
                    {"id": "A", "text": "HTTP/1.1"},
                    {"id": "B", "text": "MQTT"},
                    {"id": "C", "text": "FTP"},
                    {"id": "D", "text": "SMTP"}
                ],
                "correct_option_id": "B"
            },
            {
                "id": 2,
                "content": "Đặc điểm nổi bật nhất của mạng cảm biến không dây Zigbee (IEEE 802.15.4) so với Wi-Fi là gì?",
                "options": [
                    {"id": "A", "text": "Băng thông cực lớn lên đến 1Gbps"},
                    {"id": "B", "text": "Tiêu thụ năng lượng cực thấp và hỗ trợ mạng Mesh"},
                    {"id": "C", "text": "Khoảng cách truyền tải hàng ngàn km"},
                    {"id": "D", "text": "Không cần anten phát sóng"}
                ],
                "correct_option_id": "B"
            },
            {
                "id": 3,
                "content": "Trong Flutter, package nào được sử dụng phổ biến nhất để quản lý kết nối Bluetooth Low Energy?",
                "options": [
                    {"id": "A", "text": "flutter_blue_plus"},
                    {"id": "B", "text": "path_provider"},
                    {"id": "C", "text": "shared_preferences"},
                    {"id": "D", "text": "flutter_svg"}
                ],
                "correct_option_id": "A"
            }
        ]

        exam2 = Exam(
            id="EXAM_IOT_2026",
            title="Trắc Nghiệm Kiến Trúc IoT & Thiết Bị Di Động",
            duration_seconds=900,
            rssi_threshold=-82,
            room_pin="5678",
            questions_json=json.dumps(sample_questions_2, ensure_ascii=False),
            created_by_user_id=teacher.id,
        )
        db.add(exam2)
        db.commit()
        print("[Seed] Đã tạo đề thi mẫu 2: EXAM_IOT_2026")

    # 4. Đề thi mẫu 3: Lập Trình Di Động Flutter & Kiosk
    exam3 = db.query(Exam).filter(Exam.id == "EXAM_FLUTTER_01").first()
    if not exam3:
        sample_questions_3 = [
            {
                "id": 1,
                "content": "Trong Flutter, Widget nào sau đây là Widget bất biến (immutable) không lưu giữ trạng thái thay đổi?",
                "options": [
                    {"id": "A", "text": "StatelessWidget"},
                    {"id": "B", "text": "StatefulWidget"},
                    {"id": "C", "text": "InheritedNotifier"},
                    {"id": "D", "text": "StatefulElement"}
                ],
                "correct_option_id": "A"
            },
            {
                "id": 2,
                "content": "Phương thức vòng đời nào của State chỉ được gọi đúng một lần khi Widget được chèn vào Element Tree?",
                "options": [
                    {"id": "A", "text": "build()"},
                    {"id": "B", "text": "initState()"},
                    {"id": "C", "text": "didUpdateWidget()"},
                    {"id": "D", "text": "dispose()"}
                ],
                "correct_option_id": "B"
            },
            {
                "id": 3,
                "content": "Mục đích chính của cờ FLAG_SECURE trên hệ điều hành Android trong ứng dụng thi cử là gì?",
                "options": [
                    {"id": "A", "text": "Tăng tốc độ kết nối BLE lên tối đa"},
                    {"id": "B", "text": "Chặn chụp ảnh màn hình và cấm quay video màn hình chứa đề thi"},
                    {"id": "C", "text": "Ép thiết bị chạy ở độ phân giải cao nhất"},
                    {"id": "D", "text": "Tự động kết nối Wi-Fi phòng thi"}
                ],
                "correct_option_id": "B"
            },
            {
                "id": 4,
                "content": "Trong Riverpod 2.x, loại Notifier nào quản lý state bất đồng bộ có hỗ trợ xử lý Loading/Error tự động?",
                "options": [
                    {"id": "A", "text": "AsyncNotifierProvider"},
                    {"id": "B", "text": "StateProvider"},
                    {"id": "C", "text": "ChangeNotifier"},
                    {"id": "D", "text": "ValueNotifier"}
                ],
                "correct_option_id": "A"
            }
        ]

        exam3 = Exam(
            id="EXAM_FLUTTER_01",
            title="Lập Trình Di Động Flutter & Riverpod Kiến Trúc",
            duration_seconds=1200,
            rssi_threshold=-80,
            room_pin="9999",
            questions_json=json.dumps(sample_questions_3, ensure_ascii=False),
            created_by_user_id=teacher.id,
        )
        db.add(exam3)
        db.commit()
        print("[Seed] Đã tạo đề thi mẫu 3: EXAM_FLUTTER_01")

    # 5. Ca thi mẫu (ExamSession)
    session = db.query(ExamSession).filter(ExamSession.exam_id == "EXAM_2026_09").first()
    if not session:
        session = ExamSession(
            exam_id="EXAM_2026_09",
            room_name="Phòng Lab IoT A101 (BLE Room)",
            is_closed=False,
        )
        db.add(session)
        db.commit()
        print("[Seed] Đã tạo ca thi mẫu: Phòng Lab IoT A101")

    # 6. Danh sách bài nộp mẫu (Submissions) giúp sẵn sàng xem báo cáo & phổ điểm
    existing_submissions = db.query(Submission).filter(Submission.exam_id == "EXAM_2026_09").count()
    if existing_submissions == 0:
        now = datetime.datetime.utcnow()
        sample_submissions = [
            Submission(
                exam_id="EXAM_2026_09",
                student_id="TS-2026-001",
                student_name="Nguyễn Nhật Hoàng",
                classroom="CNTT-K18A",
                answers_json=json.dumps({"1": "A", "2": "B", "3": "B", "4": "A", "5": "B", "6": "B"}),
                score=6,
                total_questions=6,
                time_taken_seconds=480,
                violation_count=0,
                room_name="Phòng Lab IoT A101 (BLE Room)",
                submitted_at=now - datetime.timedelta(minutes=30),
            ),
            Submission(
                exam_id="EXAM_2026_09",
                student_id="TS-2026-002",
                student_name="Trần Thị Mai",
                classroom="CNTT-K18A",
                answers_json=json.dumps({"1": "A", "2": "B", "3": "B", "4": "A", "5": "B", "6": "A"}),
                score=5,
                total_questions=6,
                time_taken_seconds=550,
                violation_count=0,
                room_name="Phòng Lab IoT A101 (BLE Room)",
                submitted_at=now - datetime.timedelta(minutes=25),
            ),
            Submission(
                exam_id="EXAM_2026_09",
                student_id="TS-2026-003",
                student_name="Lê Văn Tuấn",
                classroom="CNTT-K18B",
                answers_json=json.dumps({"1": "A", "2": "B", "3": "A", "4": "A", "5": "B", "6": "C"}),
                score=4,
                total_questions=6,
                time_taken_seconds=620,
                violation_count=1,
                room_name="Phòng Lab IoT A101 (BLE Room)",
                submitted_at=now - datetime.timedelta(minutes=20),
            ),
            Submission(
                exam_id="EXAM_2026_09",
                student_id="TS-2026-004",
                student_name="Phạm Minh Đức",
                classroom="CNTT-K18B",
                answers_json=json.dumps({"1": "A", "2": "C", "3": "D", "4": "A", "5": "A", "6": "D"}),
                score=2,
                total_questions=6,
                time_taken_seconds=700,
                violation_count=3,
                room_name="Phòng Lab IoT A101 (BLE Room)",
                submitted_at=now - datetime.timedelta(minutes=15),
            ),
            Submission(
                exam_id="EXAM_2026_09",
                student_id="TS-2026-005",
                student_name="Đặng Hải Yến",
                classroom="CNTT-K18A",
                answers_json=json.dumps({"1": "A", "2": "B", "3": "B", "4": "B", "5": "B", "6": "B"}),
                score=5,
                total_questions=6,
                time_taken_seconds=450,
                violation_count=0,
                room_name="Phòng Lab IoT A101 (BLE Room)",
                submitted_at=now - datetime.timedelta(minutes=10),
            ),
        ]
        db.add_all(sample_submissions)
        db.commit()
        print(f"[Seed] Đã nạp sẵn {len(sample_submissions)} bài nộp mẫu cho đề EXAM_2026_09")
