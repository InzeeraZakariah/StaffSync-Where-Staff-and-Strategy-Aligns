import logging
from typing import Optional
import firebase_admin
from firebase_admin import credentials, messaging
from firebase_admin.exceptions import FirebaseError

from app.core.config import settings

logger = logging.getLogger(__name__)

_firebase_initialized = False


def init_firebase():
    global _firebase_initialized
    if not _firebase_initialized:
        try:
            cred = credentials.Certificate(settings.FIREBASE_CREDENTIALS_PATH)
            firebase_admin.initialize_app(cred)
            _firebase_initialized = True
            logger.info("Firebase Admin SDK initialized.")
        except Exception as e:
            logger.error(f"Failed to initialize Firebase: {e}")


async def send_push_notification(
    fcm_token: str,
    title: str,
    body: str,
    data: Optional[dict] = None,
) -> bool:
    if not fcm_token:
        return False

    try:
        message = messaging.Message(
            notification=messaging.Notification(title=title, body=body),
            data={k: str(v) for k, v in (data or {}).items()},
            token=fcm_token,
            android=messaging.AndroidConfig(
                priority="high",
                notification=messaging.AndroidNotification(
                    sound="default",
                    channel_id="staffsync_reminders",
                ),
            ),
            apns=messaging.APNSConfig(
                payload=messaging.APNSPayload(
                    aps=messaging.Aps(sound="default", badge=1)
                )
            ),
        )
        messaging.send(message)
        return True
    except FirebaseError as e:
        logger.error(f"FCM send failed for token {fcm_token[:20]}...: {e}")
        return False
    except Exception as e:
        logger.error(f"Unexpected error sending push notification: {e}")
        return False


async def send_multicast_notification(
    fcm_tokens: list[str],
    title: str,
    body: str,
    data: Optional[dict] = None,
) -> tuple[int, int]:
    if not fcm_tokens:
        return 0, 0

    chunk_size = 500
    total_success = 0
    total_failed = 0

    for i in range(0, len(fcm_tokens), chunk_size):
        chunk = fcm_tokens[i:i + chunk_size]
        try:
            multicast_message = messaging.MulticastMessage(
                notification=messaging.Notification(title=title, body=body),
                data={k: str(v) for k, v in (data or {}).items()},
                tokens=chunk,
                android=messaging.AndroidConfig(
                    priority="high",
                    notification=messaging.AndroidNotification(
                        sound="default",
                        channel_id="staffsync_urgent",
                    ),
                ),
                apns=messaging.APNSConfig(
                    payload=messaging.APNSPayload(
                        aps=messaging.Aps(sound="default", badge=1)
                    )
                ),
            )
            response = messaging.send_each_for_multicast(multicast_message)
            total_success += response.success_count
            total_failed += response.failure_count
        except FirebaseError as e:
            logger.error(f"Multicast FCM error: {e}")
            total_failed += len(chunk)

    return total_success, total_failed