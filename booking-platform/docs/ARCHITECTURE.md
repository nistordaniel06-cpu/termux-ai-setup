# Booking & Growth Platform — Architecture

Status: Phase 1 (Core) in progress. This document is the proposal called for in
the product brief, section 17 and 20, written before implementation and kept
up to date as phases land.

## 1. Product framing

`Booking App + Local Marketplace + Growth Engine`. Phase 1 (this repo, right
now) builds only the **Core**: auth, business/professional/service/schedule
management, real availability, booking with no double-booking, cancel /
reschedule, and a minimal dashboard. Marketplace discovery, growth (empty-slot
discounts, referrals, loyalty, rebooking), and the business-OS features
(CRM, analytics, kiosk mode, subscriptions) are designed for in the schema
and module boundaries below, but their logic is deliberately **not**
implemented yet — no mocked UI for features that don't work end-to-end.

## 2. Tech stack

| Concern | Choice | Why |
|---|---|---|
| Backend language/runtime | TypeScript on Node.js 22 | Type-safe, one language across API and (later) mobile via React Native/Expo. |
| API framework | Express | Small, unopinionated, easy to test with Supertest; module boundaries come from our own folder structure, not framework magic. |
| Database | PostgreSQL | Relational integrity for bookings (foreign keys, unique constraints, transactions) matters more here than NoSQL flexibility. |
| ORM / migrations | Prisma | Typed client, first-class migrations, easy to seed, good fit for a modular schema with many entities. |
| Auth | JWT (access + refresh) + bcrypt | Stateless, simple to run in tests, no external auth provider dependency for MVP. |
| Testing | Jest + Supertest, against a real Postgres (docker) | Booking correctness (double-booking, race conditions) needs a real DB with real constraints, not a mock. |
| Web client (Phase 1) | Next.js (App Router) + TypeScript + Tailwind CSS | One codebase for the public web flows (booking must "work from the browser," section 12/13); mobile-first responsive layout gets us most of the UX goal in section 19 without committing to native yet. |
| Mobile app | Deferred | Native (React Native/Expo) client consumes the same REST API once Phase 2 discovery flows exist; building it now would duplicate Phase 1 UI for no additional coverage. |
| Push notifications | Deferred (Phase 3) | `NotificationService` interface exists in the schema/module boundary now; provider (FCM/APNs/web push) wired in when Phase 3 notification events are implemented. |
| Maps / geolocation | Deferred (Phase 2) | Businesses store `latitude`/`longitude` from day one; distance search and PostGIS-vs-haversine tradeoff is a Phase 2 decision. |
| Image storage | Deferred (Phase 2) | `photoUrl` fields exist; object storage (S3-compatible) wiring happens with the portfolio/marketplace UI. |
| Payments | Deferred (Phase 3/4) | No payment fields required for Phase 1 booking (services store price only, no checkout). |

Rationale for deferrals: the brief explicitly asks for architecture that
*allows* these later (sections 6, 10, 11, 15) without requiring them in the
MVP, and warns against building fictional features just to make the UI look
complete (section 20).

## 3. Repository layout

```
booking-platform/
  docs/
    ARCHITECTURE.md          # this file
  packages/
    api/                     # Express + TypeScript + Prisma backend
      prisma/
        schema.prisma
        migrations/
        seed.ts
      src/
        modules/
          auth/
          business/
          professional/
          service/
          schedule/
          booking/
          marketplace/        # Phase 2 stub (routes return 501 for now)
          growth/             # Phase 3 stub
          notifications/      # Phase 3 stub
          analytics/          # Phase 1: dashboard read-model only
        middleware/
        lib/                  # prisma client, jwt, errors
        app.ts
        server.ts
      tests/
      package.json
      tsconfig.json
    web/                      # Next.js mobile-first client
      src/
        app/
        lib/
      package.json
  package.json                # npm workspaces root
```

Each module under `src/modules/*` owns its routes, service (business logic),
and validation — separated per the brief's "Nu crea un monolit imposibil de
întreținut" (section 17: client / business / marketplace / booking / growth /
notifications / analytics are separate concerns).

## 4. Database schema (Phase 1 entities in full, later-phase entities stubbed)

All entities from section 18 are modeled now so migrations don't need
breaking changes later; only Phase 1 entities have business logic behind
them.

```
User            id, email, passwordHash, role (CLIENT | PROFESSIONAL | SALON_OWNER),
                name, phone, referralCode, referredById, createdAt

Business        id, ownerId (-> User), name, slug, description, address,
                city, latitude, longitude, createdAt

Professional    id, userId (-> User), businessId (-> Business), displayName,
                bio, active

Service         id, businessId, name, durationMinutes, priceCents, active

Schedule        id, professionalId, dayOfWeek (0-6), startTime, endTime
                -- weekly recurring working hours

Availability    id, professionalId, date, startTime, endTime, isBlocked
                -- one-off overrides: extra hours or blocked time off

Booking         id, customerId (-> User), professionalId, serviceId,
                startTime, endTime, status (PENDING|CONFIRMED|CANCELLED|COMPLETED|NO_SHOW),
                createdAt
                -- UNIQUE (professionalId, startTime) + serializable
                   transaction is what prevents double-booking

Customer        id, userId, businessId, firstVisitAt, lastVisitAt, visitCount
                -- per-business relationship record, distinct from User

Review          id, bookingId, rating, comment, createdAt          -- Phase 2
Offer           id, businessId, discountPercent, startsAt, endsAt   -- Phase 3
Referral        id, referrerUserId, referredUserId, status, rewardedAt -- Phase 3
Reward          id, userId, type, amount, redeemedAt                -- Phase 3
Notification    id, userId, type, payload, readAt, createdAt        -- Phase 3
AnalyticsEvent  id, businessId, type, payload, createdAt             -- Phase 1 writes events; Phase 4 builds reporting on them
```

Full field-level definitions live in `packages/api/prisma/schema.prisma`
(source of truth — this doc is the map, not the territory).

Double-booking / race-condition strategy: a unique index on
`(professionalId, startTime)` plus wrapping the availability-check +
insert in a single `SERIALIZABLE` Prisma transaction. Two concurrent
requests for the same slot: one commits, the other gets a unique-constraint
violation (or serialization failure) that the API turns into a `409
Conflict`. Covered by an integration test that fires concurrent booking
requests at the same slot.

## 5. API surface (Phase 1)

All routes under `/api/v1`. Auth via `Authorization: Bearer <accessToken>`.

```
POST   /auth/register              { email, password, name, role, referralCode? }
POST   /auth/login                 { email, password } -> { accessToken, refreshToken }
POST   /auth/refresh                { refreshToken }

GET    /businesses/me               (owner) current user's business
POST   /businesses                  create business (SALON_OWNER/PROFESSIONAL)
PATCH  /businesses/:id               update
GET    /businesses/:id               public read (no auth)

POST   /businesses/:id/professionals
GET    /businesses/:id/professionals
PATCH  /professionals/:id

POST   /businesses/:id/services
GET    /businesses/:id/services
PATCH  /services/:id
DELETE /services/:id

POST   /professionals/:id/schedule          set weekly working hours
GET    /professionals/:id/schedule
POST   /professionals/:id/availability      block/add a one-off interval
GET    /professionals/:id/availability?date=YYYY-MM-DD&serviceId=   computed open slots

POST   /bookings                    { professionalId, serviceId, startTime } -> 201 | 409
GET    /bookings/me                 customer's bookings
GET    /bookings/business/:id       business's bookings (owner/professional)
PATCH  /bookings/:id/cancel
PATCH  /bookings/:id/reschedule     { startTime }

GET    /dashboard/:businessId       today's occupancy %, empty slots, upcoming bookings
```

Marketplace/growth/notifications/analytics-reporting routes are added as
stubs returning `501 Not Implemented` so the API surface documented in
section 17 exists, without a fake response pretending the feature works.

## 6. Core user flows (Phase 1)

**Professional/salon owner onboarding**
1. Register (`role: PROFESSIONAL` or `SALON_OWNER`).
2. Create business (name, address, city, geo).
3. Add services (name, duration, price).
4. Set weekly schedule per professional.
5. Business is now bookable via its id/slug (marketplace listing is Phase 2).

**Client booking**
1. Register or log in (`role: CLIENT`).
2. `GET /professionals/:id/availability?date=...&serviceId=...` for open slots.
3. `POST /bookings` with a chosen slot -> confirmed or `409` if it was just taken.
4. Cancel or reschedule from `GET /bookings/me`.

**Business dashboard**
1. Owner opens dashboard -> today's occupancy %, empty slots, upcoming list.

## 7. Implementation plan

- **Phase 1 — Core** (this iteration): auth, business/professional/service/schedule
  CRUD, availability computation, booking with no double-booking, cancel/reschedule,
  minimal dashboard, Next.js client covering the flows above, integration tests
  for all of it including a concurrency test for booking.
- **Phase 2 — Discovery**: marketplace homepage, search/filters, public SEO
  pages, reviews, favorites, Discovery Score (modular weights).
- **Phase 3 — Growth**: empty-slot detection + bounded discounts, offers surfaced
  in marketplace, referral system, loyalty, rebooking prompts, notifications
  (with opt-out).
- **Phase 4 — Business OS**: CRM, revenue/acquisition analytics, multi-employee
  dashboards, kiosk/tablet mode, subscription billing, acquisition-channel
  tracking.

Each phase lands as its own set of commits with tests passing before merge,
per the brief's "MVP mic care funcționează end-to-end" priority over a large
app full of non-functional mocks.
