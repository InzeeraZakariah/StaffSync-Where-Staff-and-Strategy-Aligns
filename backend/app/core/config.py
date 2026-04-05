from pydantic_settings import BaseSettings
from functools import lru_cache
from pydantic import Json
from typing import Optional


class Settings(BaseSettings):
    # Database
    DATABASE_URL: str

    GOOGLE_CLOUD_SERVICE_JSON: Optional[Json[dict]] = None
    
    # JWT
    SECRET_KEY: str
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60
    REFRESH_TOKEN_EXPIRE_DAYS: int = 7

    # App
    APP_NAME: str = "StaffSync"
    APP_VERSION: str = "1.0.0"
    DEBUG: bool = False
    ALLOWED_ORIGINS: str = "http://localhost:3000"

    # File Upload
    MAX_FILE_SIZE_MB: int = 10
    UPLOAD_DIR: str = "uploads/avatars"

    # Recall.ai (legacy — replaced by Symbl.ai)
    RECALL_API_KEY: str = ""
    RECALL_API_BASE: str = "https://api.recall.ai/api/v1"

    # Fireflies.ai (meeting bot — joins Zoom/Meet automatically)
    FIREFLIES_API_KEY: str = ""

    # Public base URL (used for webhook callbacks)
    BASE_URL: str = "http://localhost:8000"

    # Anthropic
    GEMINI_API_KEY: str = ""
    AI_PROVIDER: str = "gemini"

    # Firebase
    FIREBASE_CREDENTIALS_PATH: str = "firebase-credentials.json"

    @property
    def allowed_origins_list(self) -> list[str]:
        return [origin.strip() for origin in self.ALLOWED_ORIGINS.split(",")]

    class Config:
        env_file = ".env"
        case_sensitive = True


@lru_cache()
def get_settings() -> Settings:
    return Settings()


settings = get_settings()