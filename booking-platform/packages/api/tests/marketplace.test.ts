import request from "supertest";
import { createApp } from "../src/app";
import { prisma } from "../src/lib/prisma";
import { resetDb } from "./helpers/db";

const app = createApp();

function nextWeekdayDateString(weekday: number): string {
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

async function setUpBusiness(opts: {
  ownerEmail: string;
  name: string;
  city: string;
  lat?: number;
  lng?: number;
  priceCents: number;
  weekday: number;
}) {
  const owner = await registerAndLogin(opts.ownerEmail, "PROFESSIONAL", "Owner");
  const businessRes = await request(app)
    .post("/api/v1/businesses")
    .set("Authorization", `Bearer ${owner.token}`)
    .send({ name: opts.name, city: opts.city, latitude: opts.lat, longitude: opts.lng });
  const businessId = businessRes.body.id;
  const professionalId = businessRes.body.professionals[0].id;

  const serviceRes = await request(app)
    .post(`/api/v1/businesses/${businessId}/services`)
    .set("Authorization", `Bearer ${owner.token}`)
    .send({ name: "Tuns", durationMinutes: 30, priceCents: opts.priceCents });
  const serviceId = serviceRes.body.id;

  await request(app)
    .post(`/api/v1/professionals/${professionalId}/schedule`)
    .set("Authorization", `Bearer ${owner.token}`)
    .send({ dayOfWeek: opts.weekday, startTime: "09:00", endTime: "12:00" });

  return { owner, businessId, professionalId, serviceId };
}

describe("reviews", () => {
  let clientToken: string;
  let clientUserId: string;
  let businessId: string;
  let professionalId: string;
  let serviceId: string;

  beforeAll(async () => {
    await resetDb();
    const weekday = 1;
    const setup = await setUpBusiness({
      ownerEmail: "review-owner@example.com",
      name: "Review Salon",
      city: "Bucuresti",
      priceCents: 5000,
      weekday,
    });
    businessId = setup.businessId;
    professionalId = setup.professionalId;
    serviceId = setup.serviceId;

    const client = await registerAndLogin("review-client@example.com", "CLIENT", "Client");
    clientToken = client.token;
    clientUserId = client.user.id;
  });

  it("rejects reviewing a booking that hasn't happened yet", async () => {
    const date = nextWeekdayDateString(1);
    const created = await request(app)
      .post("/api/v1/bookings")
      .set("Authorization", `Bearer ${clientToken}`)
      .send({ professionalId, serviceId, startTime: `${date}T09:00:00.000Z` });
    expect(created.status).toBe(201);

    const review = await request(app)
      .post(`/api/v1/bookings/${created.body.id}/review`)
      .set("Authorization", `Bearer ${clientToken}`)
      .send({ rating: 5 });
    expect(review.status).toBe(400);
  });

  it("allows reviewing a past, non-cancelled booking and rejects a second review", async () => {
    const pastBooking = await prisma.booking.create({
      data: {
        customerId: clientUserId,
        businessId,
        professionalId,
        serviceId,
        startTime: new Date(Date.now() - 2 * 60 * 60 * 1000),
        endTime: new Date(Date.now() - 1.5 * 60 * 60 * 1000),
        status: "CONFIRMED",
      },
    });

    const first = await request(app)
      .post(`/api/v1/bookings/${pastBooking.id}/review`)
      .set("Authorization", `Bearer ${clientToken}`)
      .send({ rating: 5, comment: "Excelent!" });
    expect(first.status).toBe(201);

    const second = await request(app)
      .post(`/api/v1/bookings/${pastBooking.id}/review`)
      .set("Authorization", `Bearer ${clientToken}`)
      .send({ rating: 4 });
    expect(second.status).toBe(400);

    const list = await request(app).get(`/api/v1/businesses/${businessId}/reviews`);
    expect(list.status).toBe(200);
    expect(list.body.reviewCount).toBe(1);
    expect(list.body.avgRating).toBe(5);
  });

  it("rejects reviewing someone else's booking", async () => {
    const otherClient = await registerAndLogin("other-client@example.com", "CLIENT", "Other");
    const pastBooking = await prisma.booking.create({
      data: {
        customerId: clientUserId,
        businessId,
        professionalId,
        serviceId,
        startTime: new Date(Date.now() - 3 * 60 * 60 * 1000),
        endTime: new Date(Date.now() - 2.5 * 60 * 60 * 1000),
        status: "CONFIRMED",
      },
    });

    const res = await request(app)
      .post(`/api/v1/bookings/${pastBooking.id}/review`)
      .set("Authorization", `Bearer ${otherClient.token}`)
      .send({ rating: 1 });
    expect(res.status).toBe(403);
  });
});

describe("favorites", () => {
  let clientToken: string;
  let businessId: string;

  beforeAll(async () => {
    await resetDb();
    const setup = await setUpBusiness({
      ownerEmail: "fav-owner@example.com",
      name: "Favorite Salon",
      city: "Bucuresti",
      priceCents: 5000,
      weekday: 2,
    });
    businessId = setup.businessId;

    const client = await registerAndLogin("fav-client@example.com", "CLIENT", "Client");
    clientToken = client.token;
  });

  it("adds, lists, and idempotently re-adds a favorite", async () => {
    const add = await request(app)
      .post(`/api/v1/businesses/${businessId}/favorite`)
      .set("Authorization", `Bearer ${clientToken}`);
    expect(add.status).toBe(201);

    const addAgain = await request(app)
      .post(`/api/v1/businesses/${businessId}/favorite`)
      .set("Authorization", `Bearer ${clientToken}`);
    expect(addAgain.status).toBe(201);

    const list = await request(app).get("/api/v1/favorites/me").set("Authorization", `Bearer ${clientToken}`);
    expect(list.status).toBe(200);
    expect(list.body).toHaveLength(1);
    expect(list.body[0].business.id).toBe(businessId);
  });

  it("removes a favorite, idempotently", async () => {
    const remove = await request(app)
      .delete(`/api/v1/businesses/${businessId}/favorite`)
      .set("Authorization", `Bearer ${clientToken}`);
    expect(remove.status).toBe(204);

    const removeAgain = await request(app)
      .delete(`/api/v1/businesses/${businessId}/favorite`)
      .set("Authorization", `Bearer ${clientToken}`);
    expect(removeAgain.status).toBe(204);

    const list = await request(app).get("/api/v1/favorites/me").set("Authorization", `Bearer ${clientToken}`);
    expect(list.body).toHaveLength(0);
  });
});

describe("marketplace search", () => {
  beforeAll(async () => {
    await resetDb();
  });

  it("filters by city", async () => {
    await setUpBusiness({
      ownerEmail: "city-a@example.com",
      name: "Bucuresti Salon",
      city: "Bucuresti",
      priceCents: 5000,
      weekday: 3,
    });
    await setUpBusiness({
      ownerEmail: "city-b@example.com",
      name: "Cluj Salon",
      city: "Cluj",
      priceCents: 5000,
      weekday: 3,
    });

    const res = await request(app).get("/api/v1/marketplace/businesses?city=Bucuresti");
    expect(res.status).toBe(200);
    expect(res.body.results.length).toBe(1);
    expect(res.body.results[0].city).toBe("Bucuresti");
  });

  it("filters by max price, excluding businesses with no service under budget", async () => {
    await resetDb();
    await setUpBusiness({
      ownerEmail: "cheap@example.com",
      name: "Cheap Salon",
      city: "Iasi",
      priceCents: 3000,
      weekday: 4,
    });
    await setUpBusiness({
      ownerEmail: "expensive@example.com",
      name: "Expensive Salon",
      city: "Iasi",
      priceCents: 30000,
      weekday: 4,
    });

    const res = await request(app).get("/api/v1/marketplace/businesses?city=Iasi&maxPriceCents=5000");
    expect(res.status).toBe(200);
    expect(res.body.results.length).toBe(1);
    expect(res.body.results[0].name).toBe("Cheap Salon");
  });

  it("ranks a rated, closer business above an unrated, farther one", async () => {
    await resetDb();
    const near = await setUpBusiness({
      ownerEmail: "near@example.com",
      name: "Near Rated Salon",
      city: "Timisoara",
      lat: 45.75,
      lng: 21.22,
      priceCents: 5000,
      weekday: 5,
    });
    await setUpBusiness({
      ownerEmail: "far@example.com",
      name: "Far Unrated Salon",
      city: "Timisoara",
      lat: 47.16,
      lng: 27.58, // Iasi coordinates: far from the reference point below
      priceCents: 5000,
      weekday: 5,
    });

    const client = await registerAndLogin("ranking-client@example.com", "CLIENT", "Client");
    const pastBooking = await prisma.booking.create({
      data: {
        customerId: client.user.id,
        businessId: near.businessId,
        professionalId: near.professionalId,
        serviceId: near.serviceId,
        startTime: new Date(Date.now() - 2 * 60 * 60 * 1000),
        endTime: new Date(Date.now() - 1.5 * 60 * 60 * 1000),
        status: "CONFIRMED",
      },
    });
    await request(app)
      .post(`/api/v1/bookings/${pastBooking.id}/review`)
      .set("Authorization", `Bearer ${client.token}`)
      .send({ rating: 5 });

    const res = await request(app).get(
      `/api/v1/marketplace/businesses?city=Timisoara&lat=45.75&lng=21.22`
    );
    expect(res.status).toBe(200);
    expect(res.body.results.length).toBe(2);
    expect(res.body.results[0].name).toBe("Near Rated Salon");
    expect(res.body.results[0].discoveryScore).toBeGreaterThan(res.body.results[1].discoveryScore);
  });
});
