import asyncio
import logging
from datetime import datetime, timezone

from app.db.session import AsyncSessionLocal
from app.services.reminder_service import get_pending_reminders_due_now, dispatch_reminder

logger = logging.getLogger(__name__)


async def process_due_reminders():
    """
    Fetches all pending reminders that are due and dispatches push notifications.
    Runs as a background task every 60 seconds.
    """
    async with AsyncSessionLocal() as db:
        try:
            due_reminders = await get_pending_reminders_due_now(db)
            if due_reminders:
                logger.info(f"Processing {len(due_reminders)} due reminder(s).")
                for reminder in due_reminders:
                    await dispatch_reminder(db, reminder)
                await db.commit()
        except Exception as e:
            await db.rollback()
            logger.error(f"Error processing reminders: {e}")


async def start_reminder_scheduler():
    """
    Infinite loop that runs reminder processing every 60 seconds.
    Started as a background asyncio task in main.py lifespan.
    """
    logger.info("Reminder scheduler started.")
    while True:
        try:
            await process_due_reminders()
        except Exception as e:
            logger.error(f"Scheduler error: {e}")
        await asyncio.sleep(60)