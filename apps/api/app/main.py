import os
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.routes import create_router
from app.core.config import settings
from app.db.database import Database

# Sanitize NO_PROXY to prevent httpx from crashing on IPv6 loopback addresses (like ::1)
if "NO_PROXY" in os.environ:
    os.environ["NO_PROXY"] = ",".join(
        [item for item in os.environ["NO_PROXY"].split(",") if "::" not in item]
    )

database = Database(settings.database_path)


@asynccontextmanager
async def lifespan(_: FastAPI):
    database.initialize()
    yield


app = FastAPI(title=settings.app_name, version="0.1.0", lifespan=lifespan)
app.add_middleware(
    CORSMiddleware,
    allow_origins=list(settings.cors_origins),
    allow_credentials=False,
    allow_methods=["GET", "POST", "PUT", "PATCH", "DELETE"],
    allow_headers=["*"],
)
app.include_router(
    create_router(database, access_token=settings.access_token),
    prefix=settings.api_prefix,
)
