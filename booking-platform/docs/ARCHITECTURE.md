# Booking & Growth Platform — Architecture

Status: Phase 1 (Core), Phase 2 (Discovery), and Phase 3 (Growth) are
implemented. This document is the proposal called for in the product brief,
section 17 and 20, written before implementation and kept up to date as
phases land.

## 1. Product framing

`Booking App + Local Marketplace + Growth Engine`. Phase 1 built the **Core**:
auth, business/professional/service/schedule management, real availability,
booking with no double-booking, cancel/reschedule, and a minimal dashboard.
Phase 2 built **Discovery**: marketplace search with a modular Discovery
Score, reviews, and favorites (see section 8). Phase 3 built **Growth**:
bounded empty-slot discounts, loyalty rewards, referrals, one-click
rebooking, and in-app notifications that respect opt-out (see section 9).
The business-OS features (CRM, revenue analytics, kiosk mode, subscriptions)
are designed for in the schema and module boundaries below, but their logic
is deliberately **not** implemented yet — no mocked UI for features that
don't work end-to-end.

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
| Notifications | In-app only (Phase 3) | A `NotificationService` writes real rows for real triggers (booking events, rewards, offers to favoriters) and gates commercial ones on the user's own opt-out. Push/email delivery (FCM/APNs/web push, an email provider) is still deferred — the in-app list is the only surface today. |
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

## 5. API surface (Phase 1 + Phase 2 + Phase 3)

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

POST   /bookings/:id/review         { rating, comment? } -> only past, non-cancelled, once
GET    /businesses/:id/reviews      list + avgRating + reviewCount

POST   /businesses/:id/favorite     idempotent add
DELETE /businesses/:id/favorite     idempotent remove
GET    /favorites/me                current user's favorited businesses

GET    /marketplace/businesses      ?q=&city=&lat=&lng=&maxPriceCents=&date= -> ranked results

PATCH  /businesses/:id/discount-limits   { minDiscountPercent, maxDiscountPercent }
POST   /businesses/:id/offers            { discountPercent, startsAt, endsAt } -> validated against limits
GET    /businesses/:id/offers            active/upcoming offers (public)

PATCH  /businesses/:id/loyalty-config    { visitsRequired: number | null }
GET    /businesses/:id/loyalty-status    (client) progress toward the next reward

GET    /rewards/me                       current user's earned rewards (loyalty + referral)

GET    /professionals/:id/next-availability?serviceId=&afterDate=&withinDays=  rebooking, one call

GET    /notifications/me
PATCH  /notifications/:id/read
PATCH  /notifications/me/preferences     { notificationsEnabled }
```

Business-OS routes (CRM, revenue analytics, kiosk mode, subscriptions) are
Phase 4 — not yet implemented, and deliberately not stubbed with a fake
response that would pretend the feature works.

## 6. Core user flows (Phase 1 + Phase 2 + Phase 3)

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

**Discovery (Phase 2)**
1. Client opens `/discover`, optionally filters by service text, city, max
   price, date, and "near me" (browser geolocation).
2. `GET /marketplace/businesses` ranks matches by Discovery Score (section 8)
   and returns them; price and text/city filters are hard query filters, not
   just scoring nudges.
3. Client opens a result's public page (`/b/[slug]`), can favorite it, reads
   reviews and the average rating, then books as in the Phase 1 flow.
4. After a booking's start time has passed, the client can leave one review
   (`POST /bookings/:id/review`) from `/my-bookings`.

**Growth (Phase 3)**
1. Owner sets discount min/max limits, then boosts today's empty slots with
   a preset (10/20/30%) or custom percent from `/dashboard`; the resulting
   Offer is validated against those limits and surfaced in marketplace
   results and on the public business page, and notifies people who already
   favorited the business (respecting their opt-out).
2. Owner sets `loyaltyVisitsRequired`; each qualifying booking increments the
   client's visit count and, on hitting a multiple, grants a Reward
   automatically — no separate trigger needed since booking creation is
   already the right moment.
3. A client who registers with a friend's referral code creates a `PENDING`
   Referral; once they have an actual past, non-cancelled booking (checked
   lazily on `GET /bookings/me`, since there's no background worker in this
   MVP), both sides get a Reward and the referral flips to `REWARDED` —
   never on signup alone.
4. From a past booking on `/my-bookings`, "Rezervă din nou" calls
   `GET /professionals/:id/next-availability` and lands the client back on
   `/b/[slug]` with the same service/professional preselected.
5. Booking confirm/cancel/reschedule and reward events write real
   Notification rows; offer notifications go only to favoriters who haven't
   opted out (`GET/PATCH /notifications/...`).

## 7. Implementation plan

- **Phase 1 — Core** (done): auth, business/professional/service/schedule
  CRUD, availability computation, booking with no double-booking, cancel/reschedule,
  minimal dashboard, Next.js client covering the flows above, integration tests
  for all of it including a concurrency test for booking.
- **Phase 2 — Discovery** (done): marketplace search (`/discover` +
  `GET /marketplace/businesses`) with a modular Discovery Score, reviews
  (one per past, non-cancelled booking), favorites, and SEO metadata on the
  public business page.
- **Phase 3 — Growth** (done): bounded empty-slot discounts (offers), a
  "boost sloturi libere" dashboard action, loyalty rewards on visit count,
  referral rewards evaluated lazily against real past bookings, one-click
  rebooking, and in-app notifications that respect opt-out. See section 9.
- **Phase 4 — Business OS**: CRM, revenue/acquisition analytics, multi-employee
  dashboards, kiosk/tablet mode, subscription billing, acquisition-channel
  tracking.

Each phase lands as its own set of commits with tests passing before merge,
per the brief's "MVP mic care funcționează end-to-end" priority over a large
app full of non-functional mocks.

## 8. Discovery Score (Phase 2, extended in Phase 3)

Per the brief's section 5: ranking isn't "whoever pays more." Each business
returned by `GET /marketplace/businesses` gets a score from seven factors,
each normalized to `[0, 1]` independently in
`packages/api/src/modules/marketplace/discoveryScore.ts` so the weights can
be retuned later without touching the factor logic:

```
availability: 18   — has an open slot on the requested date (or 0.5 if not evaluated)
distance:     18   — 1 / (1 + km / 5); 0.5 if either side lacks geo data
rating:       18   — avgRating / 5; 0.5 if no reviews yet (doesn't bury new businesses)
priceMatch:   14   — 1 if a service fits maxPriceCents; 1 (neutral) if no price filter
reliability:  14   — 1 - cancellationRate over all bookings; 1 if no bookings yet
popularity:    8   — min(1, totalBookings / 20)
offer:        10   — 1 if a Phase 3 Offer is active right now, else 0
```

`score = round(100 * Σ(weight × factor) / Σ(weight))`. Text/city/price
filters are hard query filters (a business missing them is excluded, not
just ranked lower); the score only orders what's left.

## 9. Growth mechanics (Phase 3)

**Empty-slot discounts.** A business must configure `minDiscountPercent` /
`maxDiscountPercent` before it can create an `Offer` at all — every
`POST /businesses/:id/offers` call is validated against those limits, so a
discount is never applied without the business's own explicit
configuration (brief section 6). Offers are business-wide for a time
window (not tied to one specific empty slot) — simpler to reason about than
per-slot pricing, and sufficient for the "boost today's empty hours" use
case in the dashboard.

**Loyalty.** `Business.loyaltyVisitsRequired` (null = off) is checked
against the existing per-business `Customer.visitCount` right inside
`createBooking`'s transaction — booking creation is already the correct
trigger point, so no separate job is needed. A `Reward` (`type:
"loyalty_reward"`) is created automatically every Nth visit.

**Referrals.** Registering with a code creates a `PENDING` `Referral`
(separate from `User.referredById`, which is just the one-time signup
link). There's no background worker in this MVP, so instead of a cron job
the reward is evaluated *lazily*: every `GET /bookings/me` call checks for
a pending referral belonging to that user and, only if they now have an
actual past, non-cancelled booking, flips it to `REWARDED` and creates a
`Reward` for both sides. Abuse protection: the status transition is a
conditional `updateMany` (`WHERE status = 'PENDING'`), so two concurrent
checks can't double-credit, and the unique `(referrerUserId,
referredUserId)` constraint caps it at one reward per referred friend ever.

**Rebooking.** `GET /professionals/:id/next-availability` scans forward day
by day (reusing the same availability logic as normal booking) so "book
again" from `/my-bookings` is one call instead of the client paging through
the calendar.

**Notifications.** `NotificationService.createNotification` takes a
`commercial` flag. Transactional notifications (booking confirmed/
cancelled/rescheduled, rewards earned) always fire — they're account
state, not marketing. Commercial ones (currently just `offer_available`)
are checked against `User.notificationsEnabled` *before* the row is ever
created, not filtered at delivery time, and are only sent to people who
already favorited that business — never a blast to everyone (brief section
10: "nu trimite spam").
