"""
fireflies_service.py — Fireflies.ai API Integration
─────────────────────────────────────────────────────
Replaces recall_service.py entirely.

Handles:
  - Deploying Fireflies bot into a live meeting (addToLiveMeeting mutation)
  - Fetching full transcript after webhook fires (transcript query)
  - Extracting transcript text from webhook payload
"""

import logging
import httpx
from typing import Optional

from app.core.config import settings

logger = logging.getLogger(__name__)

FIREFLIES_URL = "https://api.fireflies.ai/graphql"


def _headers() -> dict:
    return {
        "Authorization": f"Bearer {settings.FIREFLIES_API_KEY}",
        "Content-Type": "application/json",
    }


# ─── Deploy Bot ───────────────────────────────────────────────────────────────

async def deploy_fireflies_bot(
    meeting_link: str,
    bot_name: str = "StaffSync AI Bot",
    duration_minutes: int = 60,
    meeting_title: Optional[str] = None,
) -> bool:
    """
    Send the Fireflies bot into a live meeting.
    Called from meeting_service.py when staff is unavailable.

    Rate limit: 3 requests per 20 minutes.
    Returns True if bot was successfully deployed.
    """
    query = """
    mutation AddToLiveMeeting(
        $meetingLink: String!,
        $title: String,
        $duration: Int
    ) {
      addToLiveMeeting(
        meeting_link: $meetingLink,
        title: $title,
        duration: $duration
      ) {
        success
      }
    }
    """
    try:
        async with httpx.AsyncClient(timeout=15.0) as client:
            resp = await client.post(
                FIREFLIES_URL,
                headers=_headers(),
                json={
                    "query": query,
                    "variables": {
                        "meetingLink": meeting_link,
                        "title": meeting_title or bot_name,
                        "duration": duration_minutes,
                    },
                },
            )
            resp.raise_for_status()
            data = resp.json()

            errors = data.get("errors")
            if errors:
                logger.error(f"Fireflies GraphQL errors: {errors}")
                return False

            success = (
                data.get("data", {})
                .get("addToLiveMeeting", {})
                .get("success", False)
            )
            if not success:
                logger.error(f"Fireflies bot deploy returned success=False: {data}")
            return success

    except httpx.HTTPStatusError as e:
        logger.error(f"Fireflies API HTTP error: {e.response.status_code} — {e.response.text}")
        return False
    except Exception as e:
        logger.error(f"Fireflies deploy_bot unexpected error: {e}")
        return False


# ─── Fetch Transcript ─────────────────────────────────────────────────────────

async def fetch_fireflies_transcript(transcript_id: str) -> Optional[str]:
    """
    Fetch full transcript text from Fireflies after webhook fires.
    Called from routers/meetings.py webhook handler.

    Returns plain text: "[Speaker Name]: sentence text"
    Returns None on failure.
    """
    query = """
    query GetTranscript($transcriptId: String!) {
      transcript(id: $transcriptId) {
        id
        title
        sentences {
          index
          speaker_name
          text
          start_time
          end_time
        }
      }
    }
    """
    try:
        async with httpx.AsyncClient(timeout=20.0) as client:
            resp = await client.post(
                FIREFLIES_URL,
                headers=_headers(),
                json={
                    "query": query,
                    "variables": {"transcriptId": transcript_id},
                },
            )
            resp.raise_for_status()
            data = resp.json()

            errors = data.get("errors")
            if errors:
                logger.error(f"Fireflies transcript fetch errors: {errors}")
                return None

            transcript_data = data.get("data", {}).get("transcript", {})
            if not transcript_data:
                logger.warning(f"No transcript data for ID: {transcript_id}")
                return None

            sentences = transcript_data.get("sentences", [])
            if not sentences:
                return None

            lines = [
                f"[{s.get('speaker_name', 'Unknown')}]: {s.get('text', '').strip()}"
                for s in sentences
                if s.get("text", "").strip()
            ]
            return "\n".join(lines)

    except httpx.HTTPStatusError as e:
        logger.error(f"Fireflies transcript HTTP error: {e.response.status_code} — {e.response.text}")
        return None
    except Exception as e:
        logger.error(f"Fireflies fetch_transcript unexpected error: {e}")
        return None


# ─── Webhook Helpers ──────────────────────────────────────────────────────────

def extract_transcript_from_webhook(payload: dict) -> Optional[str]:
    """
    Fireflies webhook payload:
    {
        "meetingId": "ASxwZxCstx",
        "eventType": "Transcription completed"
    }

    Fireflies does NOT embed the transcript in the webhook.
    We return a sentinel so the router calls fetch_fireflies_transcript().
    """
    meeting_id = payload.get("meetingId")
    if not meeting_id:
        return None
    return f"__FIREFLIES_TRANSCRIPT_ID__{meeting_id}"


def is_fireflies_sentinel(text: str) -> bool:
    return isinstance(text, str) and text.startswith("__FIREFLIES_TRANSCRIPT_ID__")


def extract_fireflies_id(text: str) -> str:
    return text.replace("__FIREFLIES_TRANSCRIPT_ID__", "")