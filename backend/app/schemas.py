from typing import List, Optional, Dict, Any
from pydantic import BaseModel, EmailStr, Field
import datetime

# --- Auth Schemas ---
class Token(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user: "UserOut"

class TokenData(BaseModel):
    email: Optional[str] = None
    user_id: Optional[int] = None

class UserRegister(BaseModel):
    email: str = Field(..., min_length=3)
    password: str = Field(..., min_length=6)
    full_name: str = Field(..., min_length=2)

class UserLogin(BaseModel):
    email: str
    password: str

class UserOut(BaseModel):
    id: int
    email: str
    full_name: str
    created_at: datetime.datetime

    class Config:
        from_attributes = True

# --- Exam & Question Schemas ---
class OptionSchema(BaseModel):
    id: str # 'A', 'B', 'C', 'D'
    text: str

class QuestionSchema(BaseModel):
    id: int
    content: str
    options: List[OptionSchema]
    correct_option_id: Optional[str] = None
    image_url: Optional[str] = None

class ExamCreate(BaseModel):
    id: str = Field(..., description="Mã đề thi, e.g. EXAM_2026_09")
    title: str
    duration_seconds: int = 1200
    rssi_threshold: int = -80
    room_pin: Optional[str] = "1234"
    questions: List[QuestionSchema]

class ExamOut(BaseModel):
    id: str
    title: str
    duration_seconds: int
    rssi_threshold: int
    room_pin: Optional[str] = "1234"
    question_count: int
    created_at: datetime.datetime

    class Config:
        from_attributes = True

class ExamPackageOut(BaseModel):
    exam_id: str
    title: str
    duration_seconds: int
    rssi_threshold: int
    room_pin: Optional[str] = "1234"
    questions: List[QuestionSchema]
    server_start_time: datetime.datetime

# --- Submission Sync Schemas ---
class SubmissionSyncItem(BaseModel):
    student_id: str
    student_name: str
    classroom: Optional[str] = None
    answers: Dict[str, str]
    score: int
    total_questions: int
    time_taken_seconds: int
    violation_count: int = 0
    submitted_at: datetime.datetime

class BatchSyncRequest(BaseModel):
    exam_id: str
    room_name: Optional[str] = "Phòng Thi BLE"
    submissions: List[SubmissionSyncItem]

class BatchSyncResponse(BaseModel):
    success: bool
    message: str
    exam_id: str
    synced_count: int
    total_received: int

# --- Report Schemas ---
class StudentReportItem(BaseModel):
    student_id: str
    student_name: str
    classroom: Optional[str] = None
    score: int
    total_questions: int
    score_scale_10: float
    time_taken_seconds: int
    violation_count: int
    submitted_at: datetime.datetime

class ExamReportOut(BaseModel):
    exam_id: str
    title: str
    total_submissions: int
    average_score: float
    highest_score: float
    lowest_score: float
    pass_rate_percent: float # >= 5.0 / 10
    total_violations: int
    submissions: List[StudentReportItem]
