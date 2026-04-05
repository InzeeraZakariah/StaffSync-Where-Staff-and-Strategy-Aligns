"""
reminder_ai_service.py — Powered by Groq AI
"""
from datetime import datetime
from app.services.ai_service import generate_ai_reminder_message, generate_urgent_notify_message

# Re-export so existing imports work unchanged
__all__ = ["generate_ai_reminder_message", "generate_urgent_notify_message"]