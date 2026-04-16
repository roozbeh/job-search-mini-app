import hashlib
import json
from datetime import datetime, timezone, timedelta
from typing import Any

import httpx
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

from ..config import settings
from ..database import get_db

router = APIRouter()

_CACHE_TTL_HOURS = 6


# ── Request bodies ────────────────────────────────────────────────────────────

class JobSearchRequest(BaseModel):
    jobTitles: list[str] = []
    locations: list[str] = []
    isRemote: bool = False
    salaryMin: int | None = None
    salaryMax: int | None = None
    jobType: str = "Any"
    resumeText: str = ""
    apiKey: str


class JobDetailsRequest(BaseModel):
    job_id: str
    apiKey: str


class SalaryRequest(BaseModel):
    job_title: str
    location: str
    apiKey: str


# ── Helpers ───────────────────────────────────────────────────────────────────

def _build_query(req: JobSearchRequest) -> str:
    parts = []
    if req.jobTitles:
        parts.append(" OR ".join(req.jobTitles))
    if req.locations:
        parts.append("in " + " or ".join(req.locations))
    if req.isRemote:
        parts.append("remote")
    if req.jobType and req.jobType != "Any":
        parts.append(req.jobType)
    return " ".join(parts) or "software engineer"


def _cache_key(query: str) -> str:
    return hashlib.md5(query.lower().encode()).hexdigest()


async def _get_cached(query: str) -> list[dict] | None:
    try:
        db = get_db()
        key = _cache_key(query)
        doc = await db.job_cache.find_one({"_id": key})
        if not doc:
            return None
        age = datetime.now(timezone.utc) - doc["cached_at"].replace(tzinfo=timezone.utc)
        if age > timedelta(hours=_CACHE_TTL_HOURS):
            return None
        return doc["jobs"]
    except Exception:
        return None


async def _set_cached(query: str, jobs: list[dict]) -> None:
    try:
        db = get_db()
        key = _cache_key(query)
        await db.job_cache.replace_one(
            {"_id": key},
            {"_id": key, "query": query, "jobs": jobs, "cached_at": datetime.now(timezone.utc)},
            upsert=True,
        )
    except Exception:
        pass


async def _agnic_fetch(url: str, api_key: str) -> Any:
    proxy_url = f"{settings.agnic_fetch_proxy}?url={httpx.URL(url)}"
    async with httpx.AsyncClient(timeout=30) as client:
        resp = await client.post(
            proxy_url,
            headers={"X-Agnic-Token": api_key, "Content-Type": "application/json"},
        )
    resp.raise_for_status()
    return resp.json()


def _normalize_job(raw: dict) -> dict:
    """Convert various job API response shapes to the iOS Job model format."""
    # JSearch / RapidAPI shape
    if "job_id" in raw:
        loc_parts = [raw.get("job_city"), raw.get("job_state"), raw.get("job_country")]
        location = ", ".join(p for p in loc_parts if p) or raw.get("job_location", "")

        sal_min = raw.get("job_min_salary")
        sal_max = raw.get("job_max_salary")
        salary = None
        if sal_min and sal_max:
            salary = f"${sal_min:,.0f} – ${sal_max:,.0f}"
        elif sal_min:
            salary = f"${sal_min:,.0f}+"

        emp_type_map = {
            "FULLTIME": "Full-time",
            "PARTTIME": "Part-time",
            "CONTRACTOR": "Contract",
            "INTERN": "Internship",
        }
        emp_type = raw.get("job_employment_type", "")
        employment_type = emp_type_map.get(emp_type, emp_type)

        return {
            "id": raw["job_id"],
            "title": raw.get("job_title", ""),
            "company": raw.get("employer_name", ""),
            "location": location,
            "salary": salary,
            "description": raw.get("job_description"),
            "postedDate": raw.get("job_posted_at_datetime_utc"),
            "applicationUrl": raw.get("job_apply_link"),
            "companyLogo": raw.get("employer_logo"),
            "isRemote": bool(raw.get("job_is_remote", False)),
            "employmentType": employment_type or None,
        }

    # Already in iOS format (pass-through)
    return {
        "id": raw.get("id", raw.get("job_id", "")),
        "title": raw.get("title", raw.get("job_title", "")),
        "company": raw.get("company", raw.get("employer_name", "")),
        "location": raw.get("location", ""),
        "salary": raw.get("salary"),
        "description": raw.get("description", raw.get("job_description")),
        "postedDate": raw.get("postedDate", raw.get("posted_date")),
        "applicationUrl": raw.get("applicationUrl", raw.get("apply_link")),
        "companyLogo": raw.get("companyLogo", raw.get("employer_logo")),
        "isRemote": bool(raw.get("isRemote", raw.get("is_remote", False))),
        "employmentType": raw.get("employmentType", raw.get("employment_type")),
    }


def _extract_jobs(data: Any) -> list[dict]:
    """Pull job list from whatever shape the upstream API returns."""
    if isinstance(data, list):
        return data
    if isinstance(data, dict):
        for key in ("jobs", "data", "results", "items"):
            val = data.get(key)
            if isinstance(val, list):
                return val
            if isinstance(val, dict):
                inner = _extract_jobs(val)
                if inner:
                    return inner
    return []


# ── Endpoints ─────────────────────────────────────────────────────────────────

@router.post("/search")
async def search_jobs(body: JobSearchRequest):
    query = _build_query(body)

    cached = await _get_cached(query)
    if cached is not None:
        return {"status": "OK", "data": {"jobs": cached}}

    target_url = f"{settings.agnic_job_search_base}/search?query={httpx.URL(query)}"
    try:
        raw_data = await _agnic_fetch(target_url, body.apiKey)
    except httpx.HTTPStatusError as e:
        raise HTTPException(status_code=e.response.status_code, detail="Job search upstream error")
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"Job search failed: {e}")

    raw_jobs = _extract_jobs(raw_data)
    jobs = [_normalize_job(j) for j in raw_jobs]

    await _set_cached(query, jobs)
    return {"status": "OK", "data": {"jobs": jobs}}


@router.post("/details")
async def job_details(body: JobDetailsRequest):
    target_url = f"{settings.agnic_job_search_base}/job-details?job_id={body.job_id}"
    try:
        data = await _agnic_fetch(target_url, body.apiKey)
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"Job details fetch failed: {e}")
    return data


@router.post("/salary")
async def salary_estimate(body: SalaryRequest):
    target_url = (
        f"{settings.agnic_job_search_base}/estimated-salary"
        f"?job_title={httpx.URL(body.job_title)}"
        f"&location={httpx.URL(body.location)}"
        f"&location_type=ANY&years_of_experience=ALL"
    )
    try:
        data = await _agnic_fetch(target_url, body.apiKey)
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"Salary estimate failed: {e}")
    return data
