import asyncio
import json
import logging
import os
from datetime import datetime, timedelta, timezone

import boto3

from app.reports.weekly import build_weekly_report

logger = logging.getLogger()
logger.setLevel(logging.INFO)

s3_client = boto3.client("s3")
BUCKET_NAME = os.environ.get("REPORTS_BUCKET_NAME")


def get_previous_iso_week() -> str:
    """Визначає ISO тиждень за минулий тиждень у UTC (наприклад '2026-W39')."""
    now = datetime.now(timezone.utc)
    prev_week = now - timedelta(days=7)
    year, week, _ = prev_week.isocalendar()
    return f"{year}-W{week:02d}"


def detect_trigger(event: dict) -> str:
    """Визначає джерело тригера: sqs, schedule або direct."""
    if "Records" in event and len(event["Records"]) > 0:
        if event["Records"][0].get("eventSource") == "aws:sqs":
            return "sqs"
    if event.get("source") == "schedule" or "detail-type" in event:
        return "schedule"
    return "direct"


def handler(event, context):
    logger.info("Raw event received: %s", json.dumps(event))

    trigger = detect_trigger(event)
    payload = {}

    # Якщо тригер SQS — парсимо body з першого запису
    if trigger == "sqs":
        body_str = event["Records"][0]["body"]
        try:
            payload = json.loads(body_str)
        except Exception:
            payload = {}
    else:
        payload = event or {}

    week = payload.get("week")
    if not week:
        week = get_previous_iso_week()

    # Обов'язкова залогувана стрічка для здачі лаби!
    logger.info("report-builder triggered", extra={"trigger": trigger, "week": week})
    print(f"report-builder triggered trigger={trigger} week={week}")

    # Запуск асинхронної функції генерації
    csv_bytes = asyncio.run(build_weekly_report(week))

    key = f"reports/{week}.csv"
    s3_client.put_object(
        Bucket=BUCKET_NAME,
        Key=key,
        Body=csv_bytes,
        ContentType="text/csv",
    )

    logger.info("Successfully uploaded report to s3://%s/%s", BUCKET_NAME, key)
    return {"status": "success", "week": week, "key": key}
