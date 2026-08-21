import request from "supertest";
import { createApp } from "../src/app";
import { resetDb } from "./helpers/db";

const app = createApp();

function nextWeekdayDateString(weekday: number): string {
  // weekday: 0=Sunday .. 6=Saturday. Returns a date at least one day out.
  const d = new Date();
  d.setUTCDate(d.getUTCDate() + 1);
  while (d.getUTCDay() !== weekday) {
    d.setUTCDate(d.getUTCDate() + 1);
  }
  return d.toISOString().slice(0, 10);
}

async function registerAndLogin(email: string, role: "CLIENT" | "PROFESSIONAL" | "SALON_OWNER", name: string) {
  const res = await request(app).post("/api/v1/auth/register").send({ email, password: "password123", name, role });
  return { token: res.body.accessToken as string, user: res.body.user as { id: string } };
}

describe("booking flow", () => {
  let ownerToken: string;
  let clientToken: string;
  let businessId: string;
  let professionalId: string;
  let serviceId: string;
  const scheduleWeekday: number = 1; // Monday

  beforeAll(async () => {
    await resetDb();

    const owner = await registerAndLogin("pro@example.com", "PROFESSIONAL", "Dan");
    ownerToken = owner.token;

    const client = await registerAndLogin("client@example.com", "CLIENT", "Alex");
    clientToken = client.token;

    const businessRes = await request(app)
      .post("/api/v1/businesses")
      .set("Authorization", `Bearer ${ownerToken}`)
      .send({ name: "Dan's Barbershop", city: "Bucuresti" });
    expect(businessRes.status).toBe(201);
    businessId = businessRes.body.id;
    professionalId = businessRes.body.professionals[0].id;

    const serviceRes = await request(app)
      .post(`/api/v1/businesses/${businessId}/services`)
      .set("Authorization", `Bearer ${ownerToken}`)
      .send({ name: "Tuns barbati", durationMinutes: 30, priceCents: 6000 });
    expect(serviceRes.status).toBe(201);
    serviceId = serviceRes.body.id;

    const scheduleRes = await request(app)
      .post(`/api/v1/professionals/${professionalId}/schedule`)
      .set("Authorization", `Bearer ${ownerToken}`)
      .send({ dayOfWeek: scheduleWeekday, startTime: "09:00", endTime: "12:00" });
    expect(scheduleRes.status).toBe(201);
  });

  it("computes open availability slots from the weekly schedule", async () => {
    const date = nextWeekdayDateString(scheduleWeekday);
    const res = await request(app).get(
      `/api/v1/professionals/${professionalId}/availability?date=${date}&serviceId=${serviceId}`
    );
    expect(res.status).toBe(200);
    expect(res.body.slots.length).toBeGreaterThan(0);
    expect(res.body.slots).toContain(`${date}T09:00:00.000Z`);
  });

  it("returns no slots on a day outside the weekly schedule", async () => {
    const otherWeekday = scheduleWeekday === 2 ? 3 : 2;
    const date = nextWeekdayDateString(otherWeekday);
    const res = await request(app).get(
      `/api/v1/professionals/${professionalId}/availability?date=${date}&serviceId=${serviceId}`
    );
    expect(res.status).toBe(200);
    expect(res.body.slots).toEqual([]);
  });

  it("books an open slot", async () => {
    const date = nextWeekdayDateString(scheduleWeekday);
    const slot = `${date}T09:00:00.000Z`;

    const res = await request(app)
      .post("/api/v1/bookings")
      .set("Authorization", `Bearer ${clientToken}`)
      .send({ professionalId, serviceId, startTime: slot });

    expect(res.status).toBe(201);
    expect(res.body.status).toBe("CONFIRMED");
    expect(res.body.startTime).toBe(slot);
  });

  it("rejects a second booking for the same slot (sequential)", async () => {
    const date = nextWeekdayDateString(scheduleWeekday);
    const slot = `${date}T09:00:00.000Z`;

    const res = await request(app)
      .post("/api/v1/bookings")
      .set("Authorization", `Bearer ${clientToken}`)
      .send({ professionalId, serviceId, startTime: slot });

    expect(res.status).toBe(409);
  });

  it("rejects a slot outside working hours", async () => {
    const date = nextWeekdayDateString(scheduleWeekday);
    const slot = `${date}T20:00:00.000Z`;

    const res = await request(app)
      .post("/api/v1/bookings")
      .set("Authorization", `Bearer ${clientToken}`)
      .send({ professionalId, serviceId, startTime: slot });

    expect(res.status).toBe(400);
  });

  it("allows only one of two concurrent booking requests for the same slot to succeed", async () => {
    const date = nextWeekdayDateString(scheduleWeekday);
    const slot = `${date}T10:00:00.000Z`;

    const [a, b] = await Promise.all([
      request(app)
        .post("/api/v1/bookings")
        .set("Authorization", `Bearer ${clientToken}`)
        .send({ professionalId, serviceId, startTime: slot }),
      request(app)
        .post("/api/v1/bookings")
        .set("Authorization", `Bearer ${clientToken}`)
        .send({ professionalId, serviceId, startTime: slot }),
    ]);

    const statuses = [a.status, b.status].sort();
    expect(statuses).toEqual([201, 409]);
  });

  it("lets the customer cancel and reschedule their booking", async () => {
    const date = nextWeekdayDateString(scheduleWeekday);
    const slot = `${date}T11:00:00.000Z`;

    const created = await request(app)
      .post("/api/v1/bookings")
      .set("Authorization", `Bearer ${clientToken}`)
      .send({ professionalId, serviceId, startTime: slot });
    expect(created.status).toBe(201);
    const bookingId = created.body.id;

    const newSlot = `${date}T11:30:00.000Z`;
    const rescheduled = await request(app)
      .patch(`/api/v1/bookings/${bookingId}/reschedule`)
      .set("Authorization", `Bearer ${clientToken}`)
      .send({ startTime: newSlot });
    expect(rescheduled.status).toBe(200);
    expect(rescheduled.body.startTime).toBe(newSlot);

    const cancelled = await request(app)
      .patch(`/api/v1/bookings/${bookingId}/cancel`)
      .set("Authorization", `Bearer ${clientToken}`);
    expect(cancelled.status).toBe(200);
    expect(cancelled.body.status).toBe("CANCELLED");
  });

  it("frees up the slot once a booking is cancelled", async () => {
    const date = nextWeekdayDateString(scheduleWeekday);
    const slot = `${date}T11:30:00.000Z`;

    const res = await request(app)
      .post("/api/v1/bookings")
      .set("Authorization", `Bearer ${clientToken}`)
      .send({ professionalId, serviceId, startTime: slot });

    expect(res.status).toBe(201);
  });

  it("shows the business owner a dashboard with occupancy and upcoming bookings", async () => {
    const res = await request(app)
      .get(`/api/v1/dashboard/${businessId}`)
      .set("Authorization", `Bearer ${ownerToken}`);

    expect(res.status).toBe(200);
    expect(res.body).toHaveProperty("occupancyPercent");
    expect(res.body).toHaveProperty("emptySlotsToday");
    expect(Array.isArray(res.body.upcomingBookings)).toBe(true);
  });

  it("denies dashboard access to a stranger", async () => {
    const stranger = await registerAndLogin("stranger@example.com", "CLIENT", "Stranger");
    const res = await request(app)
      .get(`/api/v1/dashboard/${businessId}`)
      .set("Authorization", `Bearer ${stranger.token}`);

    expect(res.status).toBe(403);
  });
});
