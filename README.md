# Camera-First Expense Tracker

A Flutter mobile application that lets users capture expenses by photographing receipts. The camera is the primary entry point — point, shoot, tag, and move on.

## Live API

**Base URL:** `https://expense-tracker-production-2d65.up.railway.app`

## Tech Stack

| Component | Technology | Why |
|-----------|-----------|-----|
| Mobile App | Flutter (Dart) | Cross-platform, single codebase |
| State Management | Riverpod v3 (Notifier) | Modern, testable, no boilerplate |
| Local Database | SQLite via Drift ORM | Type-safe queries, compile-time verification, offline-first |
| Backend | Node.js + Express | Lightweight, fast to build REST APIs |
| Database | PostgreSQL (Supabase) | Relational data, SQL aggregation for summaries, proper indexing |
| Image Storage | Supabase Storage | Integrated with DB, free tier, public URLs |
| Auth | Custom JWT (bcrypt + jsonwebtoken) | Full control over auth flow, portable |

### Why PostgreSQL over Firebase/Firestore?
Expenses are structured, relational data with a fixed schema. SQL gives powerful aggregation (`SUM`, `GROUP BY`) for the summary feature, and `WHERE` clauses with `ILIKE` for search. Firestore would require manual aggregation in application code.

### Why Drift over sqflite/Hive?
Drift provides type-safe queries with compile-time verification. Table definitions are Dart classes, not raw SQL strings. Migrations are handled automatically. It sits on top of sqflite (still SQLite underneath).

### Why Riverpod over Bloc/Provider?
Riverpod v3's Notifier pattern handles dependency injection cleanly via the `build()` method. No boilerplate, no context dependency, and `select()` enables granular widget rebuilds.

## Architecture

The app follows **Clean Architecture** with strict dependency rules:

```
lib/
├── core/               # DI, constants, theme, error types
├── domain/             # Pure business logic (zero dependencies)
│   ├── entities/       # ExpenseEntity, SummaryEntity
│   ├── repositories/   # Abstract interfaces
│   └── usecases/       # GetExpenses, AddExpense, DeleteExpense, SyncExpenses, etc.
├── data/               # Implementations
│   ├── models/         # ExpenseModel (extends entity, adds conversions)
│   ├── datasources/    # LocalDatasource (Drift), RemoteDatasource (Dio)
│   └── repositories/   # ExpenseRepositoryImpl, AuthRepositoryImpl
├── database/           # Drift table definitions + generated code
└── presentation/       # UI layer
    ├── providers/      # Riverpod Notifiers
    ├── screens/        # Login, Signup, Home, Capture, Detail
    └── widgets/        # ExpenseCard, SummaryBar, EmptyState
```

**Dependency rule:** `Presentation → Domain ← Data`. Domain has zero external imports. Presentation never imports from data layer. DI container wires everything.

## Sync Architecture

The app uses **delta sync** with cursor-based pagination:

1. **Push** — unsynced local expenses are POSTed to server. Pending deletes are processed.
2. **Pull** — `GET /expenses/changes?since=<timestamp>` returns only records changed after last sync.
3. **Apply** — upsert new/updated expenses locally, delete removed ones.

Sync triggers: app open, every 60s (foreground only), WiFi reconnect, after save, manual button, pull-to-refresh.

**Key decisions:**
- Server returns both `upserted` (active) and `deleted` (soft-deleted IDs) in one response
- Client uses `INSERT OR REPLACE` to handle updates from other devices
- Delete is idempotent — succeeds even if already deleted (prevents retry loops)
- Pending delete queue for offline deletes
- `_isSyncing` lock prevents concurrent sync operations

## API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/auth/signup` | Create account (email, password, name) |
| POST | `/api/auth/login` | Login, returns JWT |
| POST | `/api/expenses` | Create expense (multipart: image + metadata) |
| GET | `/api/expenses` | List expenses (paginated, filterable) |
| GET | `/api/expenses/summary` | Get spend totals (today/week/month) |
| GET | `/api/expenses/changes` | Delta sync — changes since timestamp |
| DELETE | `/api/expenses/:id` | Soft delete expense |

**Query params for GET /expenses:** `page`, `limit`, `category`, `search`

## Features

**Core:**
- Camera/gallery as primary action
- Receipt image preview while filling details
- Amount, category, note, date fields
- Scrollable expense list with thumbnails
- Detail view with receipt image
- Delete with confirmation dialog
- JWT authentication (signup/login)

**Sync:**
- Offline-first — works without internet
- Delta sync with cursor-based pagination
- Pending delete queue for offline deletes
- Auto-sync on connectivity change
- Cross-device sync (multi-device support)
- Idempotent operations (safe retries)

**Bonus:**
- Summary bar (today/week/month) — server-side SQL aggregation
- Pinch-to-zoom on receipt images — frosted glass overlay
- Search by note keywords — server-side with debounce
- Filter by category — server-side with pagination
- Infinite scroll pagination

## Running Locally

### Backend

```bash
cd backend
npm install
npx prisma generate
```

Create `.env`:
```
PORT=3000
DATABASE_URL="your_supabase_pooled_url"
DIRECT_URL="your_supabase_direct_url"
JWT_SECRET="your_jwt_secret"
SUPABASE_URL="your_supabase_project_url"
SUPABASE_SERVICE_KEY="your_supabase_service_key"
```

Push schema to database:
```bash
npx prisma db push
```

Start server:
```bash
npm run dev
```

### Flutter App

```bash
cd expense_tracker
flutter pub get
flutter pub run build_runner build
flutter run
```

Update `lib/core/constants.dart` with your backend URL if running locally.

### Prerequisites
- Node.js 18+
- Flutter 3.41+
- Supabase account (free tier)
- Supabase Storage bucket named `receipts` (public)

## What I Would Improve

- WebSocket/SSE for real-time sync instead of polling
- Batch sync API to push multiple expenses in one request
- Access + refresh token rotation
- CDN for image delivery
- Server-side image thumbnails for list view
- Rate limiting on auth endpoints
- Exponential backoff on failed retries
- Background sync via Workmanager when app is closed
- Cache eviction for local DB (keep recent 90 days)
