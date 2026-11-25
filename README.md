# StaffSync: Where Staff and Strategy Aligns

A mobile app for college staff to coordinate, communicate and track student progress in one place.

Built with **Flutter** (frontend), **FastAPI** (backend) and **PostgreSQL** (database).

---

## Features

| Module | What it does |
|---|---|
| **Auth** | Staff registration, login, JWT access and refresh tokens |
| **Profile** | LinkedIn-style profile with achievements, patents, journals and subject expertise; account settings (notifications, availability visibility) |
| **Groups and chat** | Create groups and chat in real time over WebSockets |
| **Availability** | Staff set their availability so others can see when they are free |
| **Meetings** | Create meetings, view details, invite staff |
| **Reminders** | Create reminders, send urgent notifications, AI-assisted reminders |
| **Resources** | Share notes and files, share resources to groups |
| **Games** | Staff games with a leaderboard |
| **Student Details** | Create student lists, add students, collect their details through a Google Form, sync responses, see rankings |

### Student Details module

1. Staff create a **student list** (for example "CSE 2024 Batch A").
2. Staff **add students** to the list (name, register number, email).
3. Staff create a **Google Form** and link its URL and Google Sheet ID to the list.
4. Staff **share the form link**. Students open it in any browser, no app needed.
5. Staff tap **Sync**. The backend reads the Google Sheet and saves each student's data to Postgres.
6. The **Summary** screen shows:
   - Top 3 students by overall CGPA
   - Top 3 students by overall activity (CGPA, best semester GPA, patents, journals, conferences)

**Activity score formula**

```
score = (CGPA x 4) + (best semester GPA x 2)
        + (patents x 10) + (journals x 8) + (conferences x 5)
```

---

## Tech stack

- **Frontend:** Flutter, `google_fonts`, `intl`, `http`, `share_plus`, `url_launcher`
- **Backend:** FastAPI, SQLAlchemy 2 (async), asyncpg, Alembic, Pydantic v2
- **Database:** PostgreSQL
- **Integrations:** Google Sheets API (student form sync), Firebase Cloud Messaging (push notifications)

---

## Project structure

```
StaffSync/
├── backend/
│   ├── app/
│   │   ├── core/        config.py, security.py
│   │   ├── db/          session.py
│   │   ├── models/      SQLAlchemy models (staff, group, meeting, student, ...)
│   │   ├── routers/     API endpoints (auth, groups, meetings, students, ...)
│   │   ├── schemas/     Pydantic schemas
│   │   ├── services/    business logic (sheets_sync_service, fcm_service, ...)
│   │   └── main.py
│   ├── alembic/         database migrations
│   ├── Dockerfile
│   └── requirements.txt
└── frontend/
    └── lib/
        ├── constants/   api_constants.dart
        ├── models/
        ├── services/
        ├── screens/     auth, groups, meetings, reminders, resources,
        │                games, profile, students, home
        ├── theme/
        ├── widgets/
        └── main.dart
```

---

## Getting started

### Prerequisites

- Python 3.10 or newer
- PostgreSQL 14 or newer
- Flutter SDK (stable)
- A Google Cloud project with the Google Sheets API enabled (only for the Student Details sync)

### 1. Backend

```bash
cd backend

# create and activate a virtual environment (Windows)
python -m venv venv
venv\Scripts\activate

# install dependencies
pip install -r requirements.txt

# create your environment file
copy .env.example .env      # then edit .env with your values

# create the database tables
alembic upgrade head

# run the server
uvicorn app.main:app --reload
```

The API runs at `http://127.0.0.1:8000`. Interactive docs are at `http://127.0.0.1:8000/docs`.

### 2. Frontend

```bash
cd frontend
flutter pub get
```

Set the backend address in `lib/constants/api_constants.dart`:

```dart
class ApiConstants {
  // Android emulator: http://10.0.2.2:8000
  // Real device on same Wi-Fi: http://<your-pc-ip>:8000
  // Deployed: https://your-app.up.railway.app
  static const String baseUrl = 'http://10.0.2.2:8000';
}
```

Then run:

```bash
flutter run
```

---

## Environment variables

Create `backend/.env` (never commit this file):

```env
DATABASE_URL=postgresql+asyncpg://postgres:yourpassword@localhost:5432/staffsync
SECRET_KEY=change-this-to-a-long-random-string
ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=60
REFRESH_TOKEN_EXPIRE_DAYS=30

# Student Details sync: the full service account JSON on one line
GOOGLE_SERVICE_ACCOUNT_JSON={"type":"service_account","project_id":"..."}
```

---

## Google Form setup (Student Details)

### One-time Google Cloud setup

1. Go to [console.cloud.google.com](https://console.cloud.google.com) and create a project.
2. Enable the **Google Sheets API**.
3. Create a **Service Account** and download its JSON key.
4. Paste the JSON (on one line) into `GOOGLE_SERVICE_ACCOUNT_JSON`.

### For every student list

1. Create a Google Form with these questions **in this order**:

   | # | Question | Type | Format |
   |---|---|---|---|
   | 1 | Register Number | Short answer | Must match the number staff added |
   | 2 | Overall CGPA | Number | 0 to 10 |
   | 3 | Semester 1 GPA | Number | Add one question per semester, named `Semester N GPA` |
   | ... | Semester N GPA | Number | |
   | n+1 | Patents | Paragraph | One per line: `Title \| Application Number` |
   | n+2 | Journals | Paragraph | One per line: `Title \| Journal Name \| YYYY-MM-DD` |
   | n+3 | Conferences | Paragraph | One per line: `Name \| Paper Title \| YYYY-MM-DD \| Location` |

2. In the form, open **Responses** and click the Google Sheets icon to create the response sheet.
3. Click **Share** on the sheet and add the service account email as a **Viewer**.
4. Copy the Sheet ID from the sheet URL: `docs.google.com/spreadsheets/d/<SHEET_ID>/edit`.
5. In StaffSync, open the list, tap **Link form**, and paste the Form URL and Sheet ID.

---

## API overview

All routes except auth require `Authorization: Bearer <access_token>`.

| Method | Route | Description |
|---|---|---|
| GET / PATCH | `/profile/me` | Get or update the logged-in staff profile |
| GET / POST | `/students/lists` | List or create student lists |
| PATCH / DELETE | `/students/lists/{list_id}` | Update (including Google Form link) or delete a list |
| GET / POST | `/students/lists/{list_id}/students` | List or add students |
| DELETE | `/students/lists/{list_id}/students/{student_id}` | Remove a student |
| POST | `/students/lists/{list_id}/sync` | Import responses from the linked Google Sheet |
| GET | `/students/lists/{list_id}/summary` | Top 3 by CGPA and top 3 by activity |

Full interactive documentation is available at `/docs` when the server is running.

---

## Deployment

**Backend (Railway)**

1. Push the `backend` folder to a GitHub repository.
2. On [railway.app](https://railway.app), create a project from the GitHub repo. The included `Dockerfile` is detected automatically.
3. Add a **PostgreSQL** service and set the environment variables above. Use `postgresql+asyncpg://` at the start of `DATABASE_URL`.
4. Generate a public domain, then run `alembic upgrade head` from the Railway shell.

**Flutter app**

1. Set `baseUrl` in `api_constants.dart` to your Railway URL.
2. Build the APK:

```bash
flutter clean
flutter pub get
flutter build apk --release
```

The APK is created at `build/app/outputs/flutter-apk/app-release.apk`.

---

## Troubleshooting

| Problem | Fix |
|---|---|
| `Table '...' is already defined for this MetaData instance` | A SQLAlchemy model is defined twice. Keep models only in `app/models/` and Pydantic classes only in `app/schemas/`. |
| Server fails with `SyntaxError` in `main.py` | Check `app.include_router(...)`. The students router already sets its own `/students` prefix, so do not pass an empty `prefix=`. |
| "Failed to create list" | Make sure the student models are imported in `main.py` and `alembic/env.py`, and that migrations have been applied. |
| Sync returns a Google API error | Confirm the Sheet is shared with the service account email and `GOOGLE_SERVICE_ACCOUNT_JSON` is valid. |
| App cannot reach the backend | Check `baseUrl`. Use `10.0.2.2` for the Android emulator, not `localhost`. |

---

## Roadmap

- PDF export of the student summary report
- Scheduled job that counts missed monthly updates and highlights students who miss three or more
- Scheduled auto-sync from Google Sheets

---

## License

Add your license here (for example MIT).
