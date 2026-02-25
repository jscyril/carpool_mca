"""
Tracking Router — WebSocket for real-time ride location sharing.

WebSocket endpoint:
  ws://host/ws/rides/{ride_id}/track?token=JWT

Flow:
  1. Client connects with JWT token in query param
  2. Server validates token, adds to ride room
  3. Client sends location updates as JSON
  4. Server broadcasts to all connected clients in the room
"""
from fastapi import APIRouter, WebSocket, WebSocketDisconnect, Query
from datetime import datetime, timezone

from core.ws_manager import manager
from core.security import decode_token, TokenType

router = APIRouter(tags=["Tracking"])


@router.websocket("/ws/rides/{ride_id}/track")
async def track_ride(
    websocket: WebSocket,
    ride_id: str,
    token: str = Query(...)
):
    """
    WebSocket endpoint for real-time ride tracking.
    
    Auth: JWT access token passed as query parameter.
    
    Messages IN (from client):
      {"type": "location_update", "lat": float, "lng": float}
    
    Messages OUT (broadcast to room):
      {"type": "location_update", "lat": float, "lng": float, "user_id": str, "timestamp": str}
    """
    # Authenticate via JWT
    payload = decode_token(token, expected_type=TokenType.ACCESS)
    if not payload:
        await websocket.close(code=4001, reason="Invalid or expired token")
        return

    user_id = payload.get("sub")
    if not user_id:
        await websocket.close(code=4001, reason="Invalid token payload")
        return

    # Join ride room
    await manager.connect(ride_id, websocket)

    try:
        while True:
            data = await websocket.receive_json()

            msg_type = data.get("type")

            if msg_type == "location_update":
                # Broadcast location to all connected clients
                broadcast_data = {
                    "type": "location_update",
                    "user_id": user_id,
                    "lat": data.get("lat"),
                    "lng": data.get("lng"),
                    "timestamp": datetime.now(timezone.utc).isoformat()
                }
                await manager.broadcast(ride_id, broadcast_data)

            elif msg_type == "ping":
                await websocket.send_json({"type": "pong"})

    except WebSocketDisconnect:
        await manager.disconnect(ride_id, websocket)
    except Exception:
        await manager.disconnect(ride_id, websocket)
