from contextlib import asynccontextmanager

import httpx
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.routes import create_router
from app.core.config import settings
from app.db.database import Database

database = Database(settings.database_path)


@asynccontextmanager
async def lifespan(application: FastAPI):
    database.initialize()
    application.state.video_http_client = httpx.AsyncClient(
        timeout=httpx.Timeout(30, connect=10),
        follow_redirects=True,
        verify=False,
        limits=httpx.Limits(max_connections=100, max_keepalive_connections=30),
    )
    try:
        yield
    finally:
        await application.state.video_http_client.aclose()


app = FastAPI(title=settings.app_name, version="0.1.0", lifespan=lifespan)
app.add_middleware(
    CORSMiddleware,
    allow_origins=list(settings.cors_origins) or ["*"],
    allow_credentials=False,
    allow_methods=["GET", "POST", "PUT", "PATCH", "DELETE"],
    allow_headers=["*"],
)
app.include_router(
    create_router(database, access_token=settings.access_token),
    prefix=settings.api_prefix,
)
