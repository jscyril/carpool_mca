"""
Console Notification Provider — prints notifications to stdout for development.
"""


class ConsoleNotificationProvider:
    """Prints notifications to console instead of sending FCM push."""

    async def send_notification(
        self, fcm_token: str, title: str, body: str, data: dict = None
    ) -> bool:
        """Send a single push notification (console output in dev)."""
        print(f"[NOTIFICATION] To: {fcm_token}")
        print(f"  Title: {title}")
        print(f"  Body: {body}")
        if data:
            print(f"  Data: {data}")
        return True

    async def send_to_multiple(
        self, tokens: list, title: str, body: str, data: dict = None
    ) -> int:
        """Send notification to multiple tokens. Returns count of successful sends."""
        sent = 0
        for token in tokens:
            if await self.send_notification(token, title, body, data):
                sent += 1
        return sent
