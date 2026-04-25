import logging
from contextlib import asynccontextmanager
from datetime import datetime, timezone

from fastapi import FastAPI, Request

logging.basicConfig(level=logging.INFO)
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import HTMLResponse, RedirectResponse

from .database import connect_db, close_db
from .routers import cv, jobs, session


@asynccontextmanager
async def lifespan(app: FastAPI):
    await connect_db()
    yield
    await close_db()


app = FastAPI(
    title="JobSearch API",
    version="1.0.0",
    lifespan=lifespan,
    docs_url="/api/docs",
    openapi_url="/api/openapi.json",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(cv.router, prefix="/api/cv", tags=["cv"])
app.include_router(jobs.router, prefix="/api/jobs", tags=["jobs"])
app.include_router(session.router, prefix="/api/session", tags=["session"])


@app.get("/api/health")
async def health():
    return {
        "status": "OK",
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "service": "jobsearch-backend",
    }


@app.get("/api/oauth/callback")
async def oauth_callback(request: Request):
    """Relay Agnic OAuth callback to the iOS custom URL scheme."""
    params = str(request.url.query)
    return RedirectResponse(url=f"jobsearch://oauth/callback?{params}", status_code=302)


@app.get("/", response_class=HTMLResponse)
async def root():
    return "<h1>JobSearch</h1><p>Web interface coming soon.</p>"
