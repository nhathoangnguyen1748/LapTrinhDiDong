import os
import sys
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)

def test_full_cloud_sync_lifecycle():
    # 1. Health check
    res = client.get("/")
    assert res.status_code == 200
    assert res.json()["status"] == "ONLINE"

    # 2. Login as teacher
    login_res = client.post(
        "/api/v1/auth/login",
        json={"email": "teacher@localquiz.edu.vn", "password": "123456"}
    )
    assert login_res.status_code == 200
    token = login_res.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}

    # 3. Get exams list
    exams_res = client.get("/api/v1/exams", headers=headers)
    assert exams_res.status_code == 200
    exams = exams_res.json()
    assert len(exams) >= 1
    exam_id = exams[0]["id"]

    # 4. Download exam package
    pkg_res = client.get(f"/api/v1/exams/{exam_id}/package", headers=headers)
    assert pkg_res.status_code == 200
    pkg = pkg_res.json()
    assert "questions" in pkg
    assert len(pkg["questions"]) > 0
    assert "room_pin" in pkg

    # 5. Simulate Batch Sync from Flutter
    sync_payload = {
        "exam_id": exam_id,
        "room_name": "Phòng Thi B-205 (IoT & BLE)",
        "submissions": [
            {
                "student_id": "TS-2026-001",
                "student_name": "Nguyễn Văn An",
                "classroom": "CNTT-K18A",
                "answers": {"1": "A", "2": "B", "3": "B", "4": "A"},
                "score": 4,
                "total_questions": 4,
                "time_taken_seconds": 950,
                "violation_count": 0,
                "submitted_at": "2026-10-12T10:15:00"
            },
            {
                "student_id": "TS-2026-002",
                "student_name": "Trần Thị Mai",
                "classroom": "CNTT-K18B",
                "answers": {"1": "A", "2": "C", "3": "B", "4": "D"},
                "score": 2,
                "total_questions": 4,
                "time_taken_seconds": 1100,
                "violation_count": 1,
                "submitted_at": "2026-10-12T10:18:00"
            }
        ]
    }
    sync_res = client.post(f"/api/v1/exams/{exam_id}/sync-submissions", json=sync_payload, headers=headers)
    assert sync_res.status_code == 200
    sync_data = sync_res.json()
    assert sync_data["success"] is True
    assert sync_data["synced_count"] == 2

    # 6. Check report
    report_res = client.get(f"/api/v1/exams/{exam_id}/report", headers=headers)
    assert report_res.status_code == 200
    report = report_res.json()
    assert report["total_submissions"] >= 2
    assert "average_score" in report

    # 7. Export Excel
    excel_res = client.get(f"/api/v1/exams/{exam_id}/export-excel", headers=headers)
    assert excel_res.status_code == 200
    assert "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" in excel_res.headers["content-type"]
    assert len(excel_res.content) > 1000

    print("ALL 7 LIFECYCLE STEPS PASSED SUCCESSFULLY!")

if __name__ == "__main__":
    test_full_cloud_sync_lifecycle()
