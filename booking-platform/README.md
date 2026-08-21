# Booking & Growth Platform

`Booking App + Local Marketplace + Growth Engine` — see
[`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) for the full product framing,
tech stack rationale, DB schema, API surface, and phased implementation plan.

**Status:** Phase 1 (Core) and Phase 2 (Discovery) are implemented and
tested end-to-end. Phase 1: auth, business/professional/service/schedule
setup, real availability, booking with no double-booking, cancel/reschedule,
and a minimal dashboard. Phase 2: marketplace search (`/discover`) ranked by
a modular Discovery Score, reviews, and favorites. All of it has a
mobile-first Next.js client. Growth features (Phase 3) and the business OS
(Phase 4) are designed for in the schema but not yet built.

## Requirements

- Node.js 22+
- PostgreSQL 14+ (a local install or any reachable instance)

## Setup

```bash
cd booking-platform
npm install

cd packages/api
cp .env.example .env          # edit DATABASE_URL if needed
npx prisma migrate dev        # creates the schema
npm run prisma:seed           # optional: seeds a demo business + client
```

## Running

```bash
# from booking-platform/
npm run api:dev     # API on http://localhost:4000
npm run web:dev      # Web client on http://localhost:3000 (set NEXT_PUBLIC_API_URL if the API isn't on :4000)
```

The seeded demo account is `dan@example.com` / `password123` (professional,
owns "Dan's Barbershop") and `client@example.com` / `password123`.

## Testing

```bash
cd packages/api
cp .env.test.example .env.test   # if you keep a separate test DB (recommended)
DATABASE_URL=... npx prisma migrate deploy   # apply migrations to the test DB
npm test
```

Tests run against a real PostgreSQL database (not mocked) because the
correctness that matters here — no double-booking, no race conditions — only
shows up against real transactions and constraints. One test fires two
concurrent booking requests at the same slot and asserts exactly one
succeeds.

## Project layout

```
booking-platform/
  docs/ARCHITECTURE.md   # stack, schema, API, phased plan
  packages/api/          # Express + TypeScript + Prisma + PostgreSQL
  packages/web/          # Next.js mobile-first client
```

## Known simplifications

- Times are treated as UTC wall-clock; no per-business timezone handling yet.
- No offers, referrals, loyalty, rebooking, or notifications yet — those are
  Phase 3 (see the architecture doc).
- Adding a professional to a salon currently requires that professional's
  raw user id (there's no email-based lookup UI yet).
- "Available today" in marketplace search checks for any open window at all,
  not availability for a specific service's duration (that's checked exactly
  once you open the business page and pick a service).
