# app/services/sheets_sync_service.py
#
# Reads Google Form responses from a Google Sheet and upserts them
# into the student_profiles table in Postgres.
#
# SETUP (one-time, takes 5 minutes):
#   1. Go to https://console.cloud.google.com
#   2. Create a project → Enable "Google Sheets API"
#   3. Create a Service Account → download the JSON key file
#   4. Save the JSON content as GOOGLE_SERVICE_ACCOUNT_JSON in your .env
#   5. In the Google Sheet: Share → add the service account email as Viewer
#
# GOOGLE FORM COLUMNS EXPECTED (staff sets up the form with these exact questions):
#   Column A: Timestamp          (auto)
#   Column B: Register Number    (short answer, required)
#   Column C: Overall CGPA       (number)
#   Column D: Semester 1 GPA     (number)   \
#   Column E: Semester 2 GPA     (number)    |  staff adds as many as needed
#   ...                                      /
#   Column ?: Patent Title(s)    (paragraph — one per line: "Title | AppNo")
#   Column ?: Journal Title(s)   (paragraph — one per line: "Title | Journal | YYYY-MM-DD")
#   Column ?: Conference(s)      (paragraph — one per line: "Name | Paper | YYYY-MM-DD | Location")

import json
import os
from datetime import datetime, timezone, date as date_type
from typing import Optional

from google.oauth2.service_account import Credentials
from googleapiclient.discovery import build
from googleapiclient.errors import HttpError
from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.student import (
    Student, StudentList, StudentProfile,
    SemesterGPA, StudentPatent, StudentJournal, StudentConference,
)


# ── Google API setup ──────────────────────────────────────────────────────────

SCOPES = ["https://www.googleapis.com/auth/spreadsheets.readonly"]


def _get_sheets_service():
    """Build Google Sheets API client from service account JSON in env."""
    sa_json = os.getenv("GOOGLE_SERVICE_ACCOUNT_JSON")
    if not sa_json:
        raise RuntimeError(
            "GOOGLE_SERVICE_ACCOUNT_JSON env var not set. "
            "See setup instructions in this file."
        )
    info = json.loads(sa_json)
    creds = Credentials.from_service_account_info(info, scopes=SCOPES)
    return build("sheets", "v4", credentials=creds)


# ── Parse helpers ─────────────────────────────────────────────────────────────

def _safe_float(val: str) -> Optional[float]:
    try:
        return float(val.strip()) if val.strip() else None
    except (ValueError, AttributeError):
        return None


def _safe_date(val: str) -> Optional[date_type]:
    for fmt in ("%Y-%m-%d", "%d/%m/%Y", "%m/%d/%Y", "%d-%m-%Y"):
        try:
            return datetime.strptime(val.strip(), fmt).date()
        except (ValueError, AttributeError):
            continue
    return None


def _parse_pipe_lines(cell: str) -> list[list[str]]:
    """
    Parse a paragraph cell where each line is pipe-separated values.
    e.g. "Machine Learning | ML-2024-001\nDeep Learning | DL-2024-002"
    → [["Machine Learning", "ML-2024-001"], ["Deep Learning", "DL-2024-002"]]
    """
    if not cell or not cell.strip():
        return []
    rows = []
    for line in cell.strip().split("\n"):
        line = line.strip()
        if line:
            rows.append([part.strip() for part in line.split("|")])
    return rows


# ── Column layout parser ───────────────────────────────────────────────────────
#
# The staff sets up the Google Form with these sections IN ORDER:
#   [0]  Timestamp
#   [1]  Register Number
#   [2]  Overall CGPA
#   [3…N] Semester GPA columns  (1 column per semester, named "Semester X GPA")
#   [N+1] Patents    (paragraph, pipe-separated)
#   [N+2] Journals   (paragraph, pipe-separated)
#   [N+3] Conferences (paragraph, pipe-separated)
#
# We detect semester columns by checking the header row.

def _parse_headers(headers: list[str]) -> dict:
    """
    Returns a dict describing column indices for each field type.
    Detects any number of "Semester X GPA" columns automatically.
    """
    layout = {
        "register_number": 1,
        "overall_cgpa": 2,
        "semesters": [],   # list of (semester_number, col_index)
        "patents": None,
        "journals": None,
        "conferences": None,
    }
    for i, h in enumerate(headers):
        h_lower = h.lower().strip()
        if "semester" in h_lower and "gpa" in h_lower:
            # Extract number: "Semester 3 GPA" → 3
            parts = h_lower.replace("gpa", "").replace("semester", "").strip()
            try:
                sem_num = int(parts)
            except ValueError:
                sem_num = len(layout["semesters"]) + 1
            layout["semesters"].append((sem_num, i))
        elif "patent" in h_lower:
            layout["patents"] = i
        elif "journal" in h_lower:
            layout["journals"] = i
        elif "conference" in h_lower:
            layout["conferences"] = i
    return layout


# ── Main sync function ────────────────────────────────────────────────────────

async def sync_sheet_to_db(
    student_list: StudentList,
    db: AsyncSession,
) -> dict:
    """
    Reads all rows from the Google Sheet linked to this StudentList,
    matches each row to a Student by register_number,
    and upserts their StudentProfile.

    Returns a summary dict: {synced: int, skipped: int, errors: list[str]}
    """
    if not student_list.google_sheet_id:
        return {"synced": 0, "skipped": 0,
                "errors": ["No Google Sheet ID set for this list."]}

    # ── Fetch sheet data ──────────────────────────────────────────────────
    try:
        service = _get_sheets_service()
        tab = student_list.sheet_tab_name or "Form Responses 1"
        result = (
            service.spreadsheets()
            .values()
            .get(
                spreadsheetId=student_list.google_sheet_id,
                range=f"'{tab}'",
            )
            .execute()
        )
    except HttpError as e:
        return {"synced": 0, "skipped": 0,
                "errors": [f"Google Sheets API error: {str(e)}"]}
    except Exception as e:
        return {"synced": 0, "skipped": 0,
                "errors": [f"Failed to connect to Google Sheets: {str(e)}"]}

    rows = result.get("values", [])
    if len(rows) < 2:
        return {"synced": 0, "skipped": 0, "errors": ["Sheet has no response rows."]}

    headers = rows[0]
    layout  = _parse_headers(headers)
    data_rows = rows[1:]   # skip header

    # ── Load all students in this list (for register_number lookup) ────────
    students_result = await db.execute(
        select(Student)
        .where(Student.list_id == student_list.id)
        .options(
            selectinload(Student.profile)
            .selectinload(StudentProfile.semesters),
            selectinload(Student.profile)
            .selectinload(StudentProfile.patents),
            selectinload(Student.profile)
            .selectinload(StudentProfile.journals),
            selectinload(Student.profile)
            .selectinload(StudentProfile.conferences),
        )
    )
    students = {s.register_number.strip().lower(): s
                for s in students_result.scalars().all()}

    synced  = 0
    skipped = 0
    errors  = []
    now     = datetime.now(timezone.utc)

    for row in data_rows:
        # Pad row to header length so index access never throws
        row = row + [""] * (len(headers) - len(row))

        reg_num = row[layout["register_number"]].strip()
        if not reg_num:
            skipped += 1
            continue

        student = students.get(reg_num.lower())
        if not student:
            skipped += 1
            errors.append(f"Register number '{reg_num}' not found in list — skipped.")
            continue

        # ── Parse academic data ───────────────────────────────────────────
        overall_cgpa = _safe_float(row[layout["overall_cgpa"]])

        sem_gpas = []
        for sem_num, col_idx in layout["semesters"]:
            if col_idx < len(row):
                gpa = _safe_float(row[col_idx])
                if gpa is not None:
                    sem_gpas.append((sem_num, gpa))

        patents = []
        if layout["patents"] is not None and layout["patents"] < len(row):
            for parts in _parse_pipe_lines(row[layout["patents"]]):
                if parts:
                    patents.append({
                        "title": parts[0],
                        "application_number": parts[1] if len(parts) > 1 else None,
                    })

        journals = []
        if layout["journals"] is not None and layout["journals"] < len(row):
            for parts in _parse_pipe_lines(row[layout["journals"]]):
                if parts:
                    journals.append({
                        "title": parts[0],
                        "journal_name": parts[1] if len(parts) > 1 else None,
                        "publish_date": _safe_date(parts[2]) if len(parts) > 2 else None,
                    })

        conferences = []
        if layout["conferences"] is not None and layout["conferences"] < len(row):
            for parts in _parse_pipe_lines(row[layout["conferences"]]):
                if parts:
                    conferences.append({
                        "conference_name": parts[0],
                        "paper_title": parts[1] if len(parts) > 1 else None,
                        "attended_date": _safe_date(parts[2]) if len(parts) > 2 else None,
                        "location": parts[3] if len(parts) > 3 else None,
                    })

        # ── Upsert profile ────────────────────────────────────────────────
        try:
            if student.profile is None:
                profile = StudentProfile(
                    student_id=student.id,
                    overall_cgpa=overall_cgpa,
                    submission_count=1,
                    last_submitted_at=now,
                )
                db.add(profile)
                await db.flush()
            else:
                profile = student.profile
                profile.overall_cgpa      = overall_cgpa
                profile.submission_count += 1
                profile.last_submitted_at = now
                # Clear old data
                await db.execute(delete(SemesterGPA).where(SemesterGPA.profile_id == profile.id))
                await db.execute(delete(StudentPatent).where(StudentPatent.profile_id == profile.id))
                await db.execute(delete(StudentJournal).where(StudentJournal.profile_id == profile.id))
                await db.execute(delete(StudentConference).where(StudentConference.profile_id == profile.id))

            for sem_num, gpa in sem_gpas:
                db.add(SemesterGPA(profile_id=profile.id, semester_number=sem_num, gpa=gpa))
            for p in patents:
                db.add(StudentPatent(profile_id=profile.id, **p))
            for j in journals:
                db.add(StudentJournal(profile_id=profile.id, **j))
            for c in conferences:
                db.add(StudentConference(profile_id=profile.id, **c))

            student.missed_updates_this_month = 0
            student.last_updated_at = now
            synced += 1

        except Exception as e:
            errors.append(f"Error saving {reg_num}: {str(e)}")
            await db.rollback()
            continue

    await db.commit()
    return {"synced": synced, "skipped": skipped, "errors": errors}