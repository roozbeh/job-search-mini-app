import hashlib
from datetime import datetime, timezone
from typing import Any

from fastapi import APIRouter
from pydantic import BaseModel

from ..database import get_db

router = APIRouter()


class LoadSessionRequest(BaseModel):
    apiKey: str


class SaveSessionRequest(BaseModel):
    apiKey: str
    session: dict[str, Any]


def _session_key(api_key: str) -> str:
    return hashlib.sha256(api_key.encode()).hexdigest()


@router.post("/load")
async def load_session(body: LoadSessionRequest):
    db = get_db()
    key = _session_key(body.apiKey)
    doc = await db.user_sessions.find_one({"_id": key})
    if not doc:
        return {"status": "OK", "data": None}
    return {"status": "OK", "data": doc.get("session")}


@router.post("/save")
async def save_session(body: SaveSessionRequest):
    db = get_db()
    key = _session_key(body.apiKey)
    await db.user_sessions.replace_one(
        {"_id": key},
        {
            "_id": key,
            "session": body.session,
            "updatedAt": datetime.now(timezone.utc),
        },
        upsert=True,
    )
    return {"status": "OK"}
