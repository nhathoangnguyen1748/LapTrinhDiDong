import datetime
from sqlalchemy import Column, Integer, String, Text, Boolean, DateTime, ForeignKey
from sqlalchemy.orm import relationship
from .database import Base

class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    email = Column(String(255), unique=True, index=True, nullable=False)
    hashed_password = Column(String(255), nullable=False)
    full_name = Column(String(255), nullable=False)
    created_at = Column(DateTime, default=datetime.datetime.utcnow)

    exams = relationship("Exam", back_populates="creator", cascade="all, delete-orphan")


class Exam(Base):
    __tablename__ = "exams"

    id = Column(String(64), primary_key=True, index=True) # e.g. EXAM_2026_09
    title = Column(String(255), nullable=False)
    duration_seconds = Column(Integer, default=1200)
    rssi_threshold = Column(Integer, default=-80)
    room_pin = Column(String(32), default="1234")
    questions_json = Column(Text, nullable=False) # JSON encoded questions list
    created_by_user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    created_at = Column(DateTime, default=datetime.datetime.utcnow)

    creator = relationship("User", back_populates="exams")
    sessions = relationship("ExamSession", back_populates="exam", cascade="all, delete-orphan")
    submissions = relationship("Submission", back_populates="exam", cascade="all, delete-orphan")


class ExamSession(Base):
    __tablename__ = "exam_sessions"

    id = Column(Integer, primary_key=True, index=True)
    exam_id = Column(String(64), ForeignKey("exams.id"), nullable=False)
    room_name = Column(String(255), nullable=False)
    started_at = Column(DateTime, default=datetime.datetime.utcnow)
    is_closed = Column(Boolean, default=False)

    exam = relationship("Exam", back_populates="sessions")


class Submission(Base):
    __tablename__ = "submissions"

    id = Column(Integer, primary_key=True, index=True)
    exam_id = Column(String(64), ForeignKey("exams.id"), nullable=False, index=True)
    student_id = Column(String(64), nullable=False, index=True)
    student_name = Column(String(255), nullable=False)
    classroom = Column(String(64), nullable=True)
    answers_json = Column(Text, nullable=False)
    score = Column(Integer, nullable=False)
    total_questions = Column(Integer, nullable=False)
    time_taken_seconds = Column(Integer, default=0)
    violation_count = Column(Integer, default=0)
    room_name = Column(String(255), nullable=True)
    submitted_at = Column(DateTime, default=datetime.datetime.utcnow)
    synced_at = Column(DateTime, default=datetime.datetime.utcnow)

    exam = relationship("Exam", back_populates="submissions")
