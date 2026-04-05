"""
ai_service.py — Powered by Groq AI
────────────────────────────────────
Groq is free, fast, and uses the same OpenAI-compatible API.
Sign up at https://console.groq.com to get a free API key.

Models used:
  - llama-3.3-70b-versatile  (best quality, free tier)
  - mixtral-8x7b-32768       (fast, good for summaries)
"""

import json
import re
import httpx
import logging
from typing import Optional

from app.core.config import settings

logger = logging.getLogger(__name__)

GROQ_API_URL = "https://api.groq.com/openai/v1/chat/completions"
GROQ_MODEL = "llama-3.3-70b-versatile"


# ─── Core Groq Request ────────────────────────────────────────────────────────

async def groq_chat(
    prompt: str,
    max_tokens: int = 1000,
    system: str = "You are a helpful assistant for a college staff management app called StaffSync.",
) -> Optional[str]:
    """
    Send a prompt to Groq API and return the response text.
    Returns None if the API key is not set or request fails.
    """
    if not settings.GROQ_API_KEY:
        logger.warning("GROQ_API_KEY not set — AI features disabled.")
        return None

    try:
        async with httpx.AsyncClient(timeout=30.0) as client:
            response = await client.post(
                GROQ_API_URL,
                headers={
                    "Authorization": f"Bearer {settings.GROQ_API_KEY}",
                    "Content-Type": "application/json",
                },
                json={
                    "model": GROQ_MODEL,
                    "messages": [
                        {"role": "system", "content": system},
                        {"role": "user", "content": prompt},
                    ],
                    "max_tokens": max_tokens,
                    "temperature": 0.7,
                },
            )
            response.raise_for_status()
            data = response.json()
            return data["choices"][0]["message"]["content"].strip()

    except httpx.HTTPStatusError as e:
        logger.error(f"Groq API error: {e.response.status_code} — {e.response.text}")
        return None
    except Exception as e:
        logger.error(f"Groq request failed: {e}")
        return None


def parse_json_response(raw: str) -> Optional[dict]:
    """Extract JSON from Groq response, handles markdown code blocks."""
    if not raw:
        return None
    # Remove markdown code blocks if present
    clean = re.sub(r"```(?:json)?", "", raw).strip()
    try:
        return json.loads(clean)
    except json.JSONDecodeError:
        # Try to find JSON object in the response
        match = re.search(r"\{.*\}", clean, re.DOTALL)
        if match:
            try:
                return json.loads(match.group())
            except Exception:
                pass
    return None


# ─── Meeting Summary ──────────────────────────────────────────────────────────

async def generate_meeting_summary(
    transcript: str,
    meeting_title: Optional[str] = None,
) -> dict:
    """
    Generate a structured meeting summary from transcript using Groq AI.
    Returns { summary, key_points, action_items }
    """
    title_context = f'Meeting Title: "{meeting_title}"' if meeting_title else ""

    prompt = f"""{title_context}

MEETING TRANSCRIPT:
{transcript}

Analyze this meeting transcript and respond ONLY with valid JSON in this exact format (no markdown, no extra text):
{{
  "summary": "A clear 2-4 sentence summary of what was discussed and decided.",
  "key_points": [
    "Key point 1",
    "Key point 2",
    "Key point 3"
  ],
  "action_items": [
    "Action item 1 — assigned to person if mentioned",
    "Action item 2"
  ]
}}"""

    raw = await groq_chat(prompt, max_tokens=1000)

    if not raw:
        return {
            "summary": "AI summary unavailable. Please check your Groq API key.",
            "key_points": [],
            "action_items": [],
        }

    result = parse_json_response(raw)
    if result:
        return {
            "summary": result.get("summary", ""),
            "key_points": result.get("key_points", []),
            "action_items": result.get("action_items", []),
        }

    return {"summary": raw, "key_points": [], "action_items": []}


# ─── Bot Availability Notification ────────────────────────────────────────────

async def check_availability_and_decide_bot(
    unavailable_staff: list[dict],
    meeting_title: str,
    scheduled_at: str,
) -> str:
    """
    Generate a professional notification explaining that an AI bot
    will attend the meeting on behalf of unavailable staff.
    """
    if not unavailable_staff:
        return "All invited staff are available for this meeting."

    names = ", ".join([s["full_name"] for s in unavailable_staff])

    prompt = f"""The following staff members are unavailable for the meeting "{meeting_title}" at {scheduled_at}: {names}

Write a short, friendly 2-3 sentence message telling them that an AI bot will attend the meeting on their behalf and send them a summary afterwards. Be professional and reassuring."""

    result = await groq_chat(prompt, max_tokens=200)
    return result or f"An AI bot will attend '{meeting_title}' on behalf of {names} and send a summary after."


# ─── AI Meeting Reminder ──────────────────────────────────────────────────────

async def generate_ai_reminder_message(
    meeting_title: str,
    scheduled_at,
    platform: str,
    staff_name: str,
) -> dict:
    """
    Generate a personalized push notification reminder for a meeting
    that is 10 minutes away.
    """
    try:
        time_str = scheduled_at.strftime("%I:%M %p")
    except Exception:
        time_str = str(scheduled_at)

    platform_display = platform.replace("_", " ").title()

    prompt = f"""Generate a short push notification reminder for {staff_name}.
Meeting: "{meeting_title}" starts at {time_str} on {platform_display} (10 minutes from now).

Respond ONLY with JSON (no markdown):
{{
  "title": "Short title (max 8 words)",
  "body": "Friendly reminder body (max 15 words)"
}}"""

    raw = await groq_chat(prompt, max_tokens=150)
    result = parse_json_response(raw) if raw else None

    return {
        "title": result.get("title", f"Meeting in 10 minutes: {meeting_title}") if result else f"Meeting in 10 mins",
        "body": result.get("body", f"Your {platform_display} meeting starts soon. Get ready!") if result else f"{meeting_title} starts soon on {platform_display}.",
    }


# ─── Urgent Notify Enhancement ────────────────────────────────────────────────

async def generate_urgent_notify_message(
    sender_name: str,
    title: str,
    location: str = None,
) -> str:
    """
    Enhance an urgent notification message to be clear and action-oriented.
    """
    location_text = f"Location: {location}" if location else ""

    prompt = f"""{sender_name} is sending an urgent notification to all college staff.
Title: {title}
{location_text}

Write a concise, urgent push notification body. Maximum 20 words. Plain text only, no markdown."""

    result = await groq_chat(prompt, max_tokens=100)
    return result or f"URGENT from {sender_name}: {title}. Please respond immediately."


# ─── AI Game Question Generator ──────────────────────────────────────────────

async def generate_game_question(
    game_type: str,
    difficulty: str,
    category: str = "general",
) -> dict:
    """
    Generate a game question/puzzle using Groq AI.
    """
    prompts = {
        "quiz": f"""Create a {difficulty} difficulty multiple choice quiz question about {category} for college staff.
Respond ONLY with JSON (no markdown):
{{
  "title": "Quiz: {category.title()}",
  "question": "The full question text?",
  "options": ["A. First option", "B. Second option", "C. Third option", "D. Fourth option"],
  "answer": "A",
  "explanation": "Brief explanation of why this is correct"
}}""",

        "word_scramble": f"""Create a {difficulty} difficulty word scramble about {category}.
Pick a single word related to college or {category}.
Respond ONLY with JSON (no markdown):
{{
  "title": "Word Scramble",
  "word": "SINGLEWORD",
  "hint": "Hint about what the word means",
  "category": "{category}"
}}""",

        "hangman": f"""Create a {difficulty} difficulty hangman word about {category} for college staff.
Respond ONLY with JSON (no markdown):
{{
  "title": "Hangman",
  "word": "SINGLEWORD",
  "hint": "Hint about what the word means",
  "category": "{category}"
}}""",
    }

    prompt = prompts.get(game_type, prompts["quiz"])
    raw = await groq_chat(prompt, max_tokens=500)
    result = parse_json_response(raw) if raw else None
    return result or {}