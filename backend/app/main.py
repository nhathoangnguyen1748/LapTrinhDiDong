from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager

from .config import settings
from .database import engine, Base, SessionLocal
from .routes import auth, exams
from .seed_data import init_seed_data

# Khởi tạo bảng cơ sở dữ liệu ngay khi import
Base.metadata.create_all(bind=engine)
_init_db = SessionLocal()
try:
    init_seed_data(_init_db)
finally:
    _init_db.close()

@asynccontextmanager
async def lifespan(app: FastAPI):
    yield

app = FastAPI(
    title=settings.PROJECT_NAME,
    version=settings.VERSION,
    description="Backend API cho Hệ sinh thái Thi Trắc Nghiệm Ngoại Tuyến LocalQuiz BLE & Cloud Sync",
    lifespan=lifespan,
)

# Cấu hình CORS để Ứng dụng Flutter di động kết nối dễ dàng
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Đăng ký các Router
app.include_router(auth.router, prefix=settings.API_V1_PREFIX)
app.include_router(exams.router, prefix=settings.API_V1_PREFIX)

@app.get("/")
def root():
    return {
        "project": settings.PROJECT_NAME,
        "version": settings.VERSION,
        "status": "ONLINE",
        "docs_url": "/docs",
        "api_prefix": settings.API_V1_PREFIX,
    }
