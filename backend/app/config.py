import os

class Settings:
    PROJECT_NAME: str = "LocalQuiz BLE & Cloud Sync API"
    VERSION: str = "2.0.0"
    API_V1_PREFIX: str = "/api/v1"
    
    SECRET_KEY: str = os.getenv("SECRET_KEY", "LocalQuizBLE_SuperSecretKey_2026_ExamCloudSync!#@")
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60 * 24 * 7  # 7 days
    
    _db_url: str = os.getenv("DATABASE_URL", "sqlite:///./localquiz.db")
    if _db_url.startswith("postgres://"):
        _db_url = _db_url.replace("postgres://", "postgresql://", 1)
    DATABASE_URL: str = _db_url

settings = Settings()
