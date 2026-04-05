import asyncio
import os
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from app.core.config import settings
from app.db.session import engine, Base
from app.services.fcm_service import init_firebase
from app.services.scheduler import start_reminder_scheduler

from app.routers import auth,group, availability,meetings,profile,resource,reminders,games,student

@asynccontextmanager
async def lifespan(app: FastAPI):
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

    for folder in [
        "uploads/avatars",
        "uploads/resources/pdf",
        "uploads/resources/ppt",
        "uploads/resources/image",
        "uploads/resources/video",
        "uploads/resources/document",
    ]:
        os.makedirs(folder, exist_ok=True)

    init_firebase()
    scheduler_task = asyncio.create_task(start_reminder_scheduler())

    yield

    scheduler_task.cancel()
    await engine.dispose()


app = FastAPI(
    title=settings.APP_NAME,
    version=settings.APP_VERSION,
    description="Backend API for Staff Sync — College Staff Management App",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins = ["*"],
    allow_credentials =False,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.mount("/static/avatars", StaticFiles(directory="uploads/avatars"), name="avatars")
app.mount("/static/resources", StaticFiles(directory="uploads/resources"), name="resources")

PREFIX = "/api/v1"
app.include_router(auth.router,         prefix=PREFIX)
app.include_router(group.router,       prefix=PREFIX)
app.include_router(availability.router, prefix=PREFIX)
app.include_router(meetings.router,     prefix=PREFIX)
app.include_router(reminders.router,    prefix=PREFIX)
app.include_router(resource.router,    prefix=PREFIX)
app.include_router(games.router,        prefix=PREFIX)
app.include_router(profile.router, prefix=PREFIX )
app.include_router(student.router, prefix=PREFIX)


@app.get("/")
async def health_check():
    return {"status": "ok", "app": settings.APP_NAME, "version": settings.APP_VERSION}