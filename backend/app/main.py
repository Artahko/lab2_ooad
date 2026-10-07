import json
import os
from datetime import datetime, timedelta
import boto3
from fastapi import APIRouter, Depends, FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import text

from app.auth import get_current_user
from app.config import settings
from app.db import SessionDep
from app.reports.weekly import build_weekly_report
from app.routers import me, meetings, participants

app = FastAPI(
    title="Meetings API",
    docs_url="/api/docs",
    redoc_url=None,
    openapi_url="/api/openapi.json",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_methods=["*"],
    allow_headers=["*"],
)

s3_client = boto3.client("s3")
BUCKET_NAME = os.getenv("REPORTS_BUCKET_NAME", "lab3-meetings-reports-480747229600")


def get_previous_iso_week() -> str:
    """Повертає попередній ISO тиждень у форматі YYYY-Www (наприклад, 2026-W40)."""
    today = datetime.utcnow().date()
    prev_week_date = today - timedelta(days=7)
    year, week, _ = prev_week_date.isocalendar()
    return f"{year}-W{week:02d}"


@app.get("/")
async def root_health() -> dict[str, str]:
    return {"status": "ok"}


@app.post("/events")
async def handle_sqs_events(request: Request, session: SessionDep) -> dict[str, str]:
    body = await request.json()
    print("Received raw event:", body)

    records = body.get("Records", [])

    if records:
        for record in records:
            try:
                raw_message = record.get("body", "{}")
                message_body = json.loads(raw_message) if isinstance(raw_message, str) else raw_message

                week = message_body.get("week")
                if not week:
                    week = get_previous_iso_week()

                print(f"Processing report for week from SQS: {week}")

                csv_data = await build_weekly_report(week, session)

                s3_key = f"reports/{week}.csv"
                s3_client.put_object(
                    Bucket=BUCKET_NAME,
                    Key=s3_key,
                    Body=csv_data,
                    ContentType="text/csv",
                )
                print(f"Successfully uploaded {s3_key} to s3://{BUCKET_NAME}/{s3_key}")

            except Exception as e:
                print(f"Error processing SQS record: {e}")
                raise e
    else:
        week = body.get("week")
        if not week:
            week = get_previous_iso_week()

        print(f"Processing direct week parameter: {week}")

        csv_data = await build_weekly_report(week, session)
        s3_key = f"reports/{week}.csv"

        s3_client.put_object(
            Bucket=BUCKET_NAME,
            Key=s3_key,
            Body=csv_data,
            ContentType="text/csv",
        )
        print(f"Successfully uploaded {s3_key} to s3://{BUCKET_NAME}/{s3_key}")

    return {"status": "success"}


api = APIRouter(prefix="/api")


@api.get("/health", tags=["health"])
async def health(session: SessionDep) -> dict[str, str]:
    await session.execute(text("SELECT 1"))
    return {"status": "ok"}


api.include_router(me.router)
api.include_router(meetings.router)
api.include_router(participants.router, dependencies=[Depends(get_current_user)])
app.include_router(api)
