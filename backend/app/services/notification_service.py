"""
Notification Service — sends push notifications for ride events.

Uses provider pattern (console in dev, Firebase in production).
"""
from services.providers.console_notification import ConsoleNotificationProvider


class NotificationService:
    """Handles push notifications for ride lifecycle events."""

    def __init__(self, provider=None):
        self.provider = provider or ConsoleNotificationProvider()

    async def notify_ride_request(
        self, driver_fcm_token: str, passenger_name: str, ride_id: str
    ):
        """Notify driver of new ride request."""
        await self.provider.send_notification(
            driver_fcm_token,
            "New Ride Request",
            f"{passenger_name} wants to join your ride",
            {"type": "ride_request", "ride_id": ride_id},
        )

    async def notify_request_accepted(
        self, passenger_fcm_token: str, ride_id: str
    ):
        """Notify passenger their request was accepted."""
        await self.provider.send_notification(
            passenger_fcm_token,
            "Request Accepted!",
            "Your ride request has been accepted",
            {"type": "request_accepted", "ride_id": ride_id},
        )

    async def notify_request_rejected(
        self, passenger_fcm_token: str, ride_id: str
    ):
        """Notify passenger their request was rejected."""
        await self.provider.send_notification(
            passenger_fcm_token,
            "Request Rejected",
            "Your ride request was not accepted",
            {"type": "request_rejected", "ride_id": ride_id},
        )

    async def notify_ride_starting(
        self, participant_tokens: list, ride_id: str
    ):
        """Notify all participants that ride is starting."""
        await self.provider.send_to_multiple(
            participant_tokens,
            "Ride Starting!",
            "Your ride is about to begin",
            {"type": "ride_starting", "ride_id": ride_id},
        )

    async def notify_ride_completed(
        self, participant_tokens: list, ride_id: str
    ):
        """Notify all participants that ride is completed."""
        await self.provider.send_to_multiple(
            participant_tokens,
            "Ride Completed",
            "Your ride has been completed. Please rate your experience.",
            {"type": "ride_completed", "ride_id": ride_id},
        )


# Singleton instance
notification_service = NotificationService()
