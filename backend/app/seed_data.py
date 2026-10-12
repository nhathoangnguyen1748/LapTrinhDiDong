import json
import datetime
from sqlalchemy.orm import Session
from .models import User, Exam, Submission
from .security import get_password_hash

def init_seed_data(db: Session):
    # 1. Kiểm tra tài khoản giảng viên mặc định
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

    # 2. Kiểm tra đề thi mẫu BLE
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
            questions_json=json.dumps(sample_questions_1, ensure_ascii=False),
            created_by_user_id=teacher.id,
        )
        db.add(exam1)
        db.commit()
        print("[Seed] Đã tạo đề thi mẫu 1: EXAM_2026_09")

    # 3. Tạo thêm đề thi mẫu 2: IoT
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
            questions_json=json.dumps(sample_questions_2, ensure_ascii=False),
            created_by_user_id=teacher.id,
        )
        db.add(exam2)
        db.commit()
        print("[Seed] Đã tạo đề thi mẫu 2: EXAM_IOT_2026")
