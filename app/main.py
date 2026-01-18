from contextlib import asynccontextmanager
from ipaddress import ip_address

from fastapi import FastAPI, HTTPException
from fastapi.responses import JSONResponse
from pydantic import BaseModel, field_validator
from psycopg2 import errors

from app import db


class ServerBase(BaseModel):
    hostname: str
    ip_address: str
    state: str

    @field_validator("ip_address")
    @classmethod
    def valid_ip(cls, value: str) -> str:
        ip_address(value)
        return value

    @field_validator("state")
    @classmethod
    def valid_state(cls, value: str) -> str:
        allowed = {"active", "offline", "retired"}
        if value not in allowed:
            raise ValueError("state must be one of: active, offline, retired")
        return value


class ServerCreate(ServerBase):
    pass


class ServerUpdate(ServerBase):
    pass


class ServerOut(ServerBase):
    id: int


@asynccontextmanager
async def lifespan(_app: FastAPI):
    db.init_db()
    yield


app = FastAPI(title="Inventory API", lifespan=lifespan)


@app.post("/servers", response_model=ServerOut, status_code=201)
def create_server(payload: ServerCreate):
    try:
        row = db.insert_one(payload.hostname, payload.ip_address, payload.state)
    except errors.UniqueViolation:
        return JSONResponse(
            status_code=400, content={"detail": "hostname must be unique"}
        )
    return row


@app.get("/servers", response_model=list[ServerOut])
def list_servers():
    return db.fetch_all()


@app.get("/servers/{server_id}", response_model=ServerOut)
def get_server(server_id: int):
    row = db.fetch_one(server_id)
    if not row:
        raise HTTPException(status_code=404, detail="server not found")
    return row


@app.put("/servers/{server_id}", response_model=ServerOut)
def update_server(server_id: int, payload: ServerUpdate):
    try:
        row = db.update_one(server_id, payload.hostname, payload.ip_address, payload.state)
    except errors.UniqueViolation:
        return JSONResponse(
            status_code=400, content={"detail": "hostname must be unique"}
        )
    if not row:
        raise HTTPException(status_code=404, detail="server not found")
    return row


@app.delete("/servers/{server_id}", status_code=204)
def delete_server(server_id: int):
    deleted = db.delete_one(server_id)
    if not deleted:
        raise HTTPException(status_code=404, detail="server not found")
    return None
