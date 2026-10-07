import csv
import io
from datetime import datetime, timedelta, timezone
from typing import Optional

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

# Залежно від того, як у вашому app/db.py називається асинхронна сесія:
from app.db import SessionLocal  # або async_session_maker
from app.models import Meeting


def parse_iso_week(week_str: str):
    """Перетворює рядок типу '2026-W40' у часові межі (UTC)."""
    year, week_num = week_str.split("-W")
    year_int, week_int = int(year), int(week_num)

    curr_start = datetime.fromisocalendar(year_int, week_int, 1).replace(
        hour=0, minute=0, second=0, microsecond=0, tzinfo=timezone.utc
    )
    curr_end = curr_start + timedelta(days=7)

    prev_start = curr_start - timedelta(days=7)
    prev_end = curr_start

    return curr_start, curr_end, prev_start, prev_end


async def build_weekly_report(week: str, db: Optional[AsyncSession] = None) -> bytes:
    """Формує CSV-звіт за вказаний ISO тиждень (асинхронно)."""
    close_db = False
    if db is None:
        db = SessionLocal()
        close_db = True

    try:
        curr_start, curr_end, prev_start, prev_end = parse_iso_week(week)

        # 1. Поточний тиждень
        curr_stmt = select(Meeting).where(
            Meeting.starts_at >= curr_start,
            Meeting.starts_at < curr_end
        )
        curr_res = await db.execute(curr_stmt)
        curr_meetings = list(curr_res.scalars().all())

        # 2. Попередній тиждень
        prev_stmt = select(Meeting).where(
            Meeting.starts_at >= prev_start,
            Meeting.starts_at < curr_start
        )
        prev_res = await db.execute(prev_stmt)
        prev_meetings = list(prev_res.scalars().all())

        # Підрахунок статистик
        curr_count = len(curr_meetings)
        curr_duration_hours = sum(
            (m.ends_at - m.starts_at).total_seconds() / 3600.0 for m in curr_meetings
        )

        prev_count = len(prev_meetings)
        prev_duration_hours = sum(
            (m.ends_at - m.starts_at).total_seconds() / 3600.0 for m in prev_meetings
        )

        count_change = curr_count - prev_count
        duration_change = curr_duration_hours - prev_duration_hours

        # Топ-5 найдовших зустрічей
        sorted_meetings = sorted(
            curr_meetings,
            key=lambda m: (m.ends_at - m.starts_at).total_seconds(),
            reverse=True
        )[:5]

        # Генерація CSV
        output = io.StringIO()
        writer = csv.writer(output)

        writer.writerow(["Metric", f"Current Week ({week})", "Previous Week", "Change"])
        writer.writerow([
            "Total Meetings",
            curr_count,
            prev_count,
            f"{'+' if count_change >= 0 else ''}{count_change}"
        ])
        writer.writerow([
            "Total Duration (Hours)",
            f"{curr_duration_hours:.2f}",
            f"{prev_duration_hours:.2f}",
            f"{'+' if duration_change >= 0 else ''}{duration_change:.2f}"
        ])

        writer.writerow([])
        writer.writerow(["Top 5 Longest Meetings This Week"])
        writer.writerow(["Title", "Start Time (UTC)", "Duration (Minutes)", "Place"])

        for m in sorted_meetings:
            duration_minutes = int((m.ends_at - m.starts_at).total_seconds() / 60)
            writer.writerow([
                m.title,
                m.starts_at.strftime("%Y-%m-%d %H:%M:%S"),
                duration_minutes,
                m.place or "-"
            ])

        return output.getvalue().encode("utf-8")

    finally:
        if close_db:
            await db.close()
