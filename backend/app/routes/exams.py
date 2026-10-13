import io
import json
import datetime
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, status, UploadFile, File, Form
from fastapi.responses import StreamingResponse
from sqlalchemy.orm import Session
import pandas as pd

from ..database import get_db
from ..models import User, Exam, ExamSession, Submission
from ..schemas import (
    ExamCreate,
    ExamOut,
    ExamPackageOut,
    QuestionSchema,
    BatchSyncRequest,
    BatchSyncResponse,
    ExamReportOut,
    StudentReportItem,
)
from ..security import get_current_user

router = APIRouter(prefix="/exams", tags=["Exams Management & Sync"])

@router.get("", response_model=List[ExamOut])
def list_exams(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Lấy danh sách các đề thi mà Giảng viên có quyền quản lý"""
    exams = db.query(Exam).filter(Exam.created_by_user_id == current_user.id).all()
    results = []
    for ex in exams:
        try:
            q_list = json.loads(ex.questions_json)
            q_count = len(q_list)
        except Exception:
            q_count = 0
            
        results.append(
            ExamOut(
                id=ex.id,
                title=ex.title,
                duration_seconds=ex.duration_seconds,
                rssi_threshold=ex.rssi_threshold,
                room_pin=getattr(ex, "room_pin", "1234") or "1234",
                question_count=q_count,
                created_at=ex.created_at,
            )
        )
    return results


@router.post("", response_model=ExamOut, status_code=status.HTTP_201_CREATED)
def create_exam(
    exam_in: ExamCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Tạo mới một đề thi trắc nghiệm trên Server"""
    existing = db.query(Exam).filter(Exam.id == exam_in.id).first()
    if existing:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Mã đề thi '{exam_in.id}' đã tồn tại trong hệ thống."
        )

    questions_data = [q.model_dump() for q in exam_in.questions]
    new_exam = Exam(
        id=exam_in.id,
        title=exam_in.title,
        duration_seconds=exam_in.duration_seconds,
        rssi_threshold=exam_in.rssi_threshold,
        room_pin=exam_in.room_pin or "1234",
        questions_json=json.dumps(questions_data, ensure_ascii=False),
        created_by_user_id=current_user.id,
    )
    db.add(new_exam)
    db.commit()
    db.refresh(new_exam)

    return ExamOut(
        id=new_exam.id,
        title=new_exam.title,
        duration_seconds=new_exam.duration_seconds,
        rssi_threshold=new_exam.rssi_threshold,
        room_pin=new_exam.room_pin,
        question_count=len(questions_data),
        created_at=new_exam.created_at,
    )


@router.post("/upload-excel", response_model=ExamOut, status_code=status.HTTP_201_CREATED)
async def upload_exam_excel(
    file: UploadFile = File(...),
    exam_id: str = Form(...),
    title: str = Form(...),
    duration_seconds: int = Form(1200),
    room_pin: str = Form("1234"),
    rssi_threshold: int = Form(-80),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Tạo đề thi mới từ file Excel (.xlsx) tải lên"""
    existing = db.query(Exam).filter(Exam.id == exam_id).first()
    if existing:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Mã đề thi '{exam_id}' đã tồn tại trong hệ thống."
        )

    try:
        content = await file.read()
        df = pd.read_excel(io.BytesIO(content))
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Không thể đọc file Excel: {str(e)}"
        )

    if df.empty:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="File Excel rỗng, không chứa dữ liệu câu hỏi."
        )

    questions_data = []
    # Kiểm tra số cột
    num_cols = len(df.columns)
    for idx, row in df.iterrows():
        # Nếu có từ 7 cột trở lên: [STT, Câu hỏi, A, B, C, D, Đáp án đúng]
        if num_cols >= 7:
            q_text = str(row.iloc[1]).strip() if pd.notna(row.iloc[1]) else ""
            opt_a = str(row.iloc[2]).strip() if pd.notna(row.iloc[2]) else "Phương án A"
            opt_b = str(row.iloc[3]).strip() if pd.notna(row.iloc[3]) else "Phương án B"
            opt_c = str(row.iloc[4]).strip() if pd.notna(row.iloc[4]) else "Phương án C"
            opt_d = str(row.iloc[5]).strip() if pd.notna(row.iloc[5]) else "Phương án D"
            ans = str(row.iloc[6]).strip().upper() if pd.notna(row.iloc[6]) else "A"
        elif num_cols >= 6:
            # 6 cột: [Câu hỏi, A, B, C, D, Đáp án đúng]
            q_text = str(row.iloc[0]).strip() if pd.notna(row.iloc[0]) else ""
            opt_a = str(row.iloc[1]).strip() if pd.notna(row.iloc[1]) else "Phương án A"
            opt_b = str(row.iloc[2]).strip() if pd.notna(row.iloc[2]) else "Phương án B"
            opt_c = str(row.iloc[3]).strip() if pd.notna(row.iloc[3]) else "Phương án C"
            opt_d = str(row.iloc[4]).strip() if pd.notna(row.iloc[4]) else "Phương án D"
            ans = str(row.iloc[5]).strip().upper() if pd.notna(row.iloc[5]) else "A"
        else:
            continue

        if not q_text or q_text.lower() in ["nan", "none"]:
            continue

        # Chuẩn hóa đáp án đúng
        correct_opt = "A"
        for letter in ["A", "B", "C", "D"]:
            if letter in ans:
                correct_opt = letter
                break

        questions_data.append({
            "id": len(questions_data) + 1,
            "content": q_text,
            "options": [
                {"id": "A", "text": opt_a},
                {"id": "B", "text": opt_b},
                {"id": "C", "text": opt_c},
                {"id": "D", "text": opt_d},
            ],
            "correct_option_id": correct_opt,
        })

    if not questions_data:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Không tìm thấy câu hỏi hợp lệ nào trong file Excel."
        )

    new_exam = Exam(
        id=exam_id,
        title=title,
        duration_seconds=duration_seconds,
        rssi_threshold=rssi_threshold,
        room_pin=room_pin or "1234",
        questions_json=json.dumps(questions_data, ensure_ascii=False),
        created_by_user_id=current_user.id,
    )
    db.add(new_exam)
    db.commit()
    db.refresh(new_exam)

    return ExamOut(
        id=new_exam.id,
        title=new_exam.title,
        duration_seconds=new_exam.duration_seconds,
        rssi_threshold=new_exam.rssi_threshold,
        room_pin=new_exam.room_pin,
        question_count=len(questions_data),
        created_at=new_exam.created_at,
    )


@router.get("/{exam_id}/package", response_model=ExamPackageOut)
def get_exam_package(
    exam_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Tải trọn gói đề thi về thiết bị di động (Mobile).
    Được sử dụng ở Khâu 1 trước khi ngắt mạng để lưu trữ offline mã hóa.
    """
    exam = db.query(Exam).filter(Exam.id == exam_id).first()
    if not exam:
        raise HTTPException(status_code=404, detail="Không tìm thấy đề thi yêu cầu.")

    try:
        raw_questions = json.loads(exam.questions_json)
        questions = [QuestionSchema(**q) for q in raw_questions]
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Lỗi phân giải cấu trúc câu hỏi: {str(e)}")

    return ExamPackageOut(
        exam_id=exam.id,
        title=exam.title,
        duration_seconds=exam.duration_seconds,
        rssi_threshold=exam.rssi_threshold,
        room_pin=getattr(exam, "room_pin", "1234") or "1234",
        questions=questions,
        server_start_time=datetime.datetime.utcnow(),
    )


@router.post("/{exam_id}/sync-submissions", response_model=BatchSyncResponse)
def sync_submissions(
    exam_id: str,
    payload: BatchSyncRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Khâu 3: Đồng bộ kết quả sau ca thi.
    Giảng viên upload toàn bộ danh sách bài nộp thu thập được từ Bluetooth lên Server.
    """
    exam = db.query(Exam).filter(Exam.id == exam_id).first()
    if not exam:
        raise HTTPException(status_code=404, detail=f"Không tìm thấy đề thi '{exam_id}'.")

    synced_count = 0
    now = datetime.datetime.utcnow()

    # Ghi nhận phiên thi
    session = ExamSession(
        exam_id=exam_id,
        room_name=payload.room_name or "Phòng Thi BLE",
        started_at=now,
        is_closed=True,
    )
    db.add(session)
    db.commit()

    for item in payload.submissions:
        # Kiểm tra xem bài nộp của sinh viên này đã được sync trước đó chưa
        existing = db.query(Submission).filter(
            Submission.exam_id == exam_id,
            Submission.student_id == item.student_id
        ).first()

        if existing:
            # Cập nhật kết quả mới nhất nếu có
            existing.student_name = item.student_name
            existing.classroom = item.classroom
            existing.answers_json = json.dumps(item.answers, ensure_ascii=False)
            existing.score = item.score
            existing.total_questions = item.total_questions
            existing.time_taken_seconds = item.time_taken_seconds
            existing.violation_count = item.violation_count
            existing.submitted_at = item.submitted_at
            existing.synced_at = now
            existing.room_name = payload.room_name
        else:
            sub = Submission(
                exam_id=exam_id,
                student_id=item.student_id,
                student_name=item.student_name,
                classroom=item.classroom,
                answers_json=json.dumps(item.answers, ensure_ascii=False),
                score=item.score,
                total_questions=item.total_questions,
                time_taken_seconds=item.time_taken_seconds,
                violation_count=item.violation_count,
                room_name=payload.room_name,
                submitted_at=item.submitted_at,
                synced_at=now,
            )
            db.add(sub)
        synced_count += 1

    db.commit()

    return BatchSyncResponse(
        success=True,
        message=f"Đã đồng bộ thành công {synced_count} bài thi lên cơ sở dữ liệu Server.",
        exam_id=exam_id,
        synced_count=synced_count,
        total_received=len(payload.submissions),
    )


@router.get("/{exam_id}/report", response_model=ExamReportOut)
def get_exam_report(
    exam_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Báo cáo phân tích phổ điểm, tỷ lệ đậu và danh sách vi phạm của đề thi"""
    exam = db.query(Exam).filter(Exam.id == exam_id).first()
    if not exam:
        raise HTTPException(status_code=404, detail="Không tìm thấy đề thi.")

    submissions = db.query(Submission).filter(Submission.exam_id == exam_id).all()
    if not submissions:
        return ExamReportOut(
            exam_id=exam.id,
            title=exam.title,
            total_submissions=0,
            average_score=0.0,
            highest_score=0.0,
            lowest_score=0.0,
            pass_rate_percent=0.0,
            total_violations=0,
            submissions=[],
        )

    student_items = []
    scores_scale_10 = []
    total_violations = 0
    passed_count = 0

    for s in submissions:
        scale_10 = round((s.score / s.total_questions) * 10, 2) if s.total_questions > 0 else 0.0
        scores_scale_10.append(scale_10)
        total_violations += s.violation_count
        if scale_10 >= 5.0:
            passed_count += 1

        student_items.append(
            StudentReportItem(
                student_id=s.student_id,
                student_name=s.student_name,
                classroom=s.classroom,
                score=s.score,
                total_questions=s.total_questions,
                score_scale_10=scale_10,
                time_taken_seconds=s.time_taken_seconds,
                violation_count=s.violation_count,
                submitted_at=s.submitted_at,
            )
        )

    avg_score = round(sum(scores_scale_10) / len(scores_scale_10), 2)
    highest = max(scores_scale_10)
    lowest = min(scores_scale_10)
    pass_rate = round((passed_count / len(submissions)) * 100, 1)

    return ExamReportOut(
        exam_id=exam.id,
        title=exam.title,
        total_submissions=len(submissions),
        average_score=avg_score,
        highest_score=highest,
        lowest_score=lowest,
        pass_rate_percent=pass_rate,
        total_violations=total_violations,
        submissions=student_items,
    )


@router.get("/{exam_id}/export-excel")
def export_excel(
    exam_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Xuất file Excel bảng điểm chi tiết của ca thi"""
    exam = db.query(Exam).filter(Exam.id == exam_id).first()
    if not exam:
        raise HTTPException(status_code=404, detail="Không tìm thấy đề thi.")

    submissions = db.query(Submission).filter(Submission.exam_id == exam_id).all()
    
    rows = []
    for idx, s in enumerate(submissions, start=1):
        scale_10 = round((s.score / s.total_questions) * 10, 2) if s.total_questions > 0 else 0.0
        minutes = s.time_taken_seconds // 60
        seconds = s.time_taken_seconds % 60
        rows.append({
            "STT": idx,
            "Mã Sinh Viên / SBD": s.student_id,
            "Họ và Tên": s.student_name,
            "Lớp": s.classroom or "Chưa phân lớp",
            "Số câu đúng": f"{s.score}/{s.total_questions}",
            "Điểm Hệ 10": scale_10,
            "Kết quả": "ĐẠT" if scale_10 >= 5.0 else "CHƯA ĐẠT",
            "Thời gian làm": f"{minutes}p {seconds}s",
            "Số lần vi phạm": s.violation_count,
            "Phòng thi": s.room_name or "Phòng Thi BLE",
            "Thời gian nộp": s.submitted_at.strftime("%Y-%m-%d %H:%M:%S") if s.submitted_at else "",
        })

    df = pd.DataFrame(rows)
    output = io.BytesIO()
    with pd.ExcelWriter(output, engine="openpyxl") as writer:
        df.to_excel(writer, index=False, sheet_name="Bảng Điểm")

    output.seek(0)
    filename = f"BangDiem_{exam_id}_{datetime.datetime.now().strftime('%Y%m%d_%H%M%S')}.xlsx"

    return StreamingResponse(
        output,
        media_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        headers={"Content-Disposition": f"attachment; filename={filename}"}
    )


@router.delete("/{exam_id}", status_code=status.HTTP_200_OK)
def delete_exam(
    exam_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Xóa đề thi khỏi hệ thống"""
    exam = db.query(Exam).filter(Exam.id == exam_id).first()
    if not exam:
        raise HTTPException(status_code=404, detail="Không tìm thấy đề thi cần xóa.")

    if exam.created_by_user_id != current_user.id:
        raise HTTPException(status_code=403, detail="Bạn không có quyền xóa đề thi này.")

    db.query(Submission).filter(Submission.exam_id == exam_id).delete()
    db.query(ExamSession).filter(ExamSession.exam_id == exam_id).delete()
    db.delete(exam)
    db.commit()
    return {"message": f"Đã xóa đề thi '{exam_id}' thành công"}

