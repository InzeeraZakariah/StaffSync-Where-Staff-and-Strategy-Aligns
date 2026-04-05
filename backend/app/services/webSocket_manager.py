from typing import Dict, Set, List, Optional
from fastapi import WebSocket
import json
import logging

logger = logging.getLogger(__name__)


 
class ConnectionManager:
    def __init__(self):
        # group_id -> list of (websocket, staff_id)
        self.active: Dict[int, List[tuple]] = {}
 
    async def connect(self, websocket: WebSocket, group_id: int, staff_id: int):
        await websocket.accept()
        if group_id not in self.active:
            self.active[group_id] = []
        self.active[group_id].append((websocket, staff_id))
 
    def disconnect(self, websocket: WebSocket, group_id: int, staff_id: int):
        if group_id in self.active:
            self.active[group_id] = [
                (ws, sid) for ws, sid in self.active[group_id]
                if ws != websocket
            ]
 
    async def broadcast(
        self,
        group_id: int,
        event: str,
        data: dict,
        exclude: Optional[WebSocket] = None,
    ):
        if group_id not in self.active:
            return
 
        message = json.dumps({"event": event, "data": data})
        dead = []
 
        for ws, sid in self.active[group_id]:
            if ws == exclude:
                continue
            try:
                await ws.send_text(message)
            except Exception:
                dead.append((ws, sid))
 
        # Clean up dead connections
        for item in dead:
            if item in self.active.get(group_id, []):
                self.active[group_id].remove(item)
 
    def get_online_members(self, group_id: int) -> List[int]:
        return [sid for _, sid in self.active.get(group_id, [])]
 
 
manager = ConnectionManager()
 