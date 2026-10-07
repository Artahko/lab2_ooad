# Spry Architecture & Repository Contract

This document describes the structure and contract for the `spry` monorepo.
It serves as the specification for code generation.

## 1. Directory Structure & Folder Purpose

spry/
├── backend/                  # FastAPI Application
│   ├── alembic/              # Database migration scripts and configuration
│   ├── app/
│   │   ├── api/              # HTTP routing layer and request handlers
│   │   ├── core/             # Application configuration and DB session setup
│   │   ├── models/           # SQLAlchemy ORM models
│   │   └── schemas/          # Pydantic schemas for API request/response validation
│   ├── Dockerfile            # Production multi-stage build for FastAPI
│   ├── pyproject.toml        # Dependencies and Ruff linter configuration
│   └── requirements.txt      # Pinned Python package dependencies
├── frontend/                 # React + Vite Application
│   ├── src/
│   │   ├── components/       # UI components (shadcn/ui, meeting cards, form)
│   │   ├── lib/              # Utility functions and API client setup
│   │   └── types/            # TypeScript interfaces/types matching backend contracts
│   ├── Dockerfile            # Production multi-stage build for React static files
│   ├── package.json          # Node.js dependencies and ESLint scripts
│   └── vite.config.ts        # Vite configuration
└── docker-compose.yml        # Local development orchestrator


---

## 2. Pinned Environment & Technology Versions

- **Python Runtime:** `python:3.12-slim`
- **Node Runtime:** `node:20-alpine`
- **Database Engine:** `postgres:16-alpine`
- **Backend Framework:** FastAPI `0.110.0`, SQLAlchemy `2.0.28`, Alembic `1.13.1`, Pydantic `2.6.4`
- **Frontend Stack:** React `18.2.0`, Vite `5.1.0`, Tailwind CSS `3.4.1`

---

## 3. Docker Compose Configuration & Startup Sequence

Root `docker-compose.yml` manages three services: `postgres`, `backend`, and `frontend`.

### `postgres`
- **Base Image:** `postgres:16-alpine`
- **Listens on:** Internal port `5432`
- **Environment:** `POSTGRES_USER=spry`, `POSTGRES_PASSWORD=spry_password`, `POSTGRES_DB=spry_db`
- **Healthcheck:** Executes `pg_isready -U spry -d spry_db` every 5 seconds.

### `backend`
- **Build Context:** `./backend` (uses `python:3.12-slim`)
- **Listens on:** Host port `8000:8000`
- **Dependencies:** `postgres` with `condition: service_healthy`
- **Startup Command:** Runs `alembic upgrade head` to apply schema migrations before starting the `uvicorn` server.

### `frontend`
- **Build Context:** `./frontend` (uses `node:20-alpine`)
- **Listens on:** Host port `5173:5173`
- **Dependencies:** `backend` (waits for backend service start)

---

## 4. API Contracts (First Slice Scope)

Base Path: `/api`

### Model: `Meeting`
- `id`: Integer (Primary Key, Auto-increment)
- `title`: String (Required, non-empty, max 255 chars)
- `starts_at`: Datetime String (Required, ISO 8601 UTC format: `YYYY-MM-DDTHH:MM:SSZ`)
- `ends_at`: Datetime String (Required, ISO 8601 UTC format: `YYYY-MM-DDTHH:MM:SSZ`)
- `attendee_count`: Integer (Required, non-negative, `>= 0`)

---

### Endpoint 1: List Meetings
- **HTTP Method:** `GET`
- **Path:** `/api/meetings`
- **Request Headers:** `Accept: application/json`
- **Success Response:** `200 OK`
- **Response Body:** Array of `Meeting` objects:
```json
[
  {
    "id": 1,
    "title": "Architecture Sync",
    "starts_at": "2026-10-01T10:00:00Z",
    "ends_at": "2026-10-01T11:00:00Z",
    "attendee_count": 4
  }
]
Endpoint 2: Create Meeting
HTTP Method: POST

Path: /api/meetings

Request Headers: Content-Type: application/json

Request Body:

JSON
{
  "title": "Sprint Planning",
  "starts_at": "2026-10-02T14:00:00Z",
  "ends_at": "2026-10-02T15:00:00Z",
  "attendee_count": 6
}
Success Response: 201 Created

Response Body: Created Meeting object with assigned id.

JSON
{
  "id": 2,
  "title": "Sprint Planning",
  "starts_at": "2026-10-02T14:00:00Z",
  "ends_at": "2026-10-02T15:00:00Z",
  "attendee_count": 6
}
Error Response: 422 Unprocessable Entity for invalid field formats or missing required fields.

5. Frontend Single Page Scope
The frontend consists of a single page rendering:

Header: Title "Spry Meetings".

Meeting Form: Input fields for title, starts_at, ends_at, and attendee_count, with a submit button that calls POST /api/meetings and updates the list upon success.

Meeting List: Fetches data via GET /api/meetings on mount and displays meetings as cards or a table list.


---
