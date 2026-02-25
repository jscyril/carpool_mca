"""
WebSocket Connection Manager — manages per-ride rooms.
"""
from fastapi import WebSocket
from typing import Dict, List


class ConnectionManager:
    """Manages WebSocket connections grouped by ride_id."""

    def __init__(self):
        self.active_connections: Dict[str, List[WebSocket]] = {}

    async def connect(self, ride_id: str, websocket: WebSocket):
        """Accept and add a WebSocket to a ride room."""
        await websocket.accept()
        if ride_id not in self.active_connections:
            self.active_connections[ride_id] = []
        self.active_connections[ride_id].append(websocket)

    async def disconnect(self, ride_id: str, websocket: WebSocket):
        """Remove a WebSocket from a ride room."""
        if ride_id in self.active_connections:
            if websocket in self.active_connections[ride_id]:
                self.active_connections[ride_id].remove(websocket)
            if not self.active_connections[ride_id]:
                del self.active_connections[ride_id]

    async def broadcast(self, ride_id: str, data: dict):
        """Send JSON data to all connected clients in a ride room."""
        if ride_id in self.active_connections:
            dead = []
            for ws in self.active_connections[ride_id]:
                try:
                    await ws.send_json(data)
                except Exception:
                    dead.append(ws)
            # Clean up dead connections
            for ws in dead:
                await self.disconnect(ride_id, ws)

    def get_connection_count(self, ride_id: str) -> int:
        """Get number of active connections for a ride."""
        return len(self.active_connections.get(ride_id, []))


# Singleton instance
manager = ConnectionManager()
