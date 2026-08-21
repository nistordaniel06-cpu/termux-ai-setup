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

async function registerAndLogin(email: string, role: "CLIENT" | "PROFESSIONAL" | "SALON_OWNER", name: string, referralCode?: string) {
  const res = await request(app)
    .post("/api/v1/auth/register")
    .send({ email, password: "password123", name, role, referralCode });
  return { token: res.body.accessToken as string, user: res.body.user as { id: string; referralCode: string } };
}

async function setUpBusiness(opts: { ownerEmail: string; name: string; priceCents: number; weekday: number }) {
  const owner = await registerAndLogin(opts.ownerEmail, "PROFESSIONAL", "Owner");
  const businessRes = await request(app)
    .post("/api/v1/businesses")
    .set("Authorization", `Bearer ${owner.token}`)
    .send({ name: opts.name, city: "Bucuresti" });
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
    .send({ dayOfWeek: opts.weekday, startTime: "09:00", endTime: "20:00" });

  return { owner, businessId, professionalId, serviceId, weekday: opts.weekday };
}

describe("growth engine - offers", () => {
  let owner: { token: string };
  let businessId: string;

  beforeAll(async () => {
    await resetDb();
    const setup = await setUpBusiness({ ownerEmail: "growth-owner@example.com", name: "Growth Salon", priceCents: 5000, weekday: 1 });
    owner = setup.owner;
    businessId = setup.businessId;
  });

  it("rejects an offer before discount limits are configured", async () => {
    const res = await request(app)
      .post(`/api/v1/businesses/${businessId}/offers`)
      .set("Authorization", `Bearer ${owner.token}`)
      .send({ discountPercent: 20, startsAt: new Date().toISOString(), endsAt: new Date(Date.now() + 3600_000).toISOString() });
    expect(res.status).toBe(400);
  });

  it("configures discount limits and rejects a discount outside them", async () => {
    const limits = await request(app)
      .patch(`/api/v1/businesses/${businessId}/discount-limits`)
      .set("Authorization", `Bearer ${owner.token}`)
      .send({ minDiscountPercent: 10, maxDiscountPercent: 50 });
    expect(limits.status).toBe(200);

    const tooLow = await request(app)
      .post(`/api/v1/businesses/${businessId}/offers`)
      .set("Authorization", `Bearer ${owner.token}`)
      .send({ discountPercent: 5, startsAt: new Date().toISOString(), endsAt: new Date(Date.now() + 3600_000).toISOString() });
    expect(tooLow.status).toBe(400);
  });

  it("creates a valid offer and notifies favoriting users who haven't opted out", async () => {
    const fan = await registerAndLogin("growth-fan@example.com", "CLIENT", "Fan");
    await request(app).post(`/api/v1/businesses/${businessId}/favorite`).set("Authorization", `Bearer ${fan.token}`);

    const optedOut = await registerAndLogin("growth-optedout@example.com", "CLIENT", "OptedOut");
    await request(app)
      .post(`/api/v1/businesses/${businessId}/favorite`)
      .set("Authorization", `Bearer ${optedOut.token}`);
    await request(app)
      .patch("/api/v1/notifications/me/preferences")
      .set("Authorization", `Bearer ${optedOut.token}`)
      .send({ notificationsEnabled: false });

    const offer = await request(app)
      .post(`/api/v1/businesses/${businessId}/offers`)
      .set("Authorization", `Bearer ${owner.token}`)
      .send({ discountPercent: 20, startsAt: new Date().toISOString(), endsAt: new Date(Date.now() + 3600_000).toISOString() });
    expect(offer.status).toBe(201);

    const list = await request(app).get(`/api/v1/businesses/${businessId}/offers`);
    expect(list.body).toHaveLength(1);

    const fanNotifications = await request(app)
      .get("/api/v1/notifications/me")
      .set("Authorization", `Bearer ${fan.token}`);
    expect(fanNotifications.body.some((n: { type: string }) => n.type === "offer_available")).toBe(true);

    const optedOutNotifications = await request(app)
      .get("/api/v1/notifications/me")
      .set("Authorization", `Bearer ${optedOut.token}`);
    expect(optedOutNotifications.body.some((n: { type: string }) => n.type === "offer_available")).toBe(false);
  });

  it("surfaces the active offer in marketplace results and boosts its score", async () => {
    const res = await request(app).get(`/api/v1/marketplace/businesses?city=Bucuresti`);
    const match = res.body.results.find((r: { id: string }) => r.id === businessId);
    expect(match.activeOfferPercent).toBe(20);
  });
});

describe("loyalty", () => {
  let clientToken: string;
  let businessId: string;
  let professionalId: string;
  let serviceId: string;
  const weekday = 2;

  beforeAll(async () => {
    await resetDb();
    const setup = await setUpBusiness({ ownerEmail: "loyalty-owner@example.com", name: "Loyalty Salon", priceCents: 4000, weekday });
    businessId = setup.businessId;
    professionalId = setup.professionalId;
    serviceId = setup.serviceId;

    await request(app)
      .patch(`/api/v1/businesses/${businessId}/loyalty-config`)
      .set("Authorization", `Bearer ${setup.owner.token}`)
      .send({ visitsRequired: 2 });

    const client = await registerAndLogin("loyalty-client@example.com", "CLIENT", "Client");
    clientToken = client.token;
  });

  it("tracks visit progress and grants a reward every Nth visit", async () => {
    const date = nextWeekdayDateString(weekday);

    const before = await request(app)
      .get(`/api/v1/businesses/${businessId}/loyalty-status`)
      .set("Authorization", `Bearer ${clientToken}`);
    expect(before.body).toEqual({ enabled: true, visitsRequired: 2, currentVisits: 0, visitsUntilNextReward: 2 });

    await request(app)
      .post("/api/v1/bookings")
      .set("Authorization", `Bearer ${clientToken}`)
      .send({ professionalId, serviceId, startTime: `${date}T09:00:00.000Z` });

    const afterOne = await request(app)
      .get(`/api/v1/businesses/${businessId}/loyalty-status`)
      .set("Authorization", `Bearer ${clientToken}`);
    expect(afterOne.body).toEqual({ enabled: true, visitsRequired: 2, currentVisits: 1, visitsUntilNextReward: 1 });

    await request(app)
      .post("/api/v1/bookings")
      .set("Authorization", `Bearer ${clientToken}`)
      .send({ professionalId, serviceId, startTime: `${date}T10:00:00.000Z` });

    const afterTwo = await request(app)
      .get(`/api/v1/businesses/${businessId}/loyalty-status`)
      .set("Authorization", `Bearer ${clientToken}`);
    expect(afterTwo.body).toEqual({ enabled: true, visitsRequired: 2, currentVisits: 2, visitsUntilNextReward: 2 });

    const rewards = await request(app).get("/api/v1/rewards/me").set("Authorization", `Bearer ${clientToken}`);
    expect(rewards.body.some((r: { type: string }) => r.type === "loyalty_reward")).toBe(true);
  });
});

describe("referral rewards", () => {
  it("rewards both sides only once the referred user has a past, non-cancelled booking", async () => {
    await resetDb();
    const setup = await setUpBusiness({ ownerEmail: "referral-owner@example.com", name: "Referral Salon", priceCents: 3000, weekday: 3 });

    const referrer = await registerAndLogin("referrer@example.com", "CLIENT", "Referrer");
    const referred = await registerAndLogin("referred@example.com", "CLIENT", "Referred", referrer.user.referralCode);

    const noRewardYet = await request(app)
      .get("/api/v1/bookings/me")
      .set("Authorization", `Bearer ${referred.token}`);
    expect(noRewardYet.status).toBe(200);
    const referrerRewardsBefore = await request(app)
      .get("/api/v1/rewards/me")
      .set("Authorization", `Bearer ${referrer.token}`);
    expect(referrerRewardsBefore.body).toHaveLength(0);

    await prisma.booking.create({
      data: {
        customerId: referred.user.id,
        businessId: setup.businessId,
        professionalId: setup.professionalId,
        serviceId: setup.serviceId,
        startTime: new Date(Date.now() - 2 * 60 * 60 * 1000),
        endTime: new Date(Date.now() - 1.5 * 60 * 60 * 1000),
        status: "CONFIRMED",
      },
    });

    await request(app).get("/api/v1/bookings/me").set("Authorization", `Bearer ${referred.token}`);

    const referrerRewards = await request(app)
      .get("/api/v1/rewards/me")
      .set("Authorization", `Bearer ${referrer.token}`);
    expect(referrerRewards.body.some((r: { type: string }) => r.type === "referral_referrer")).toBe(true);

    const referredRewards = await request(app)
      .get("/api/v1/rewards/me")
      .set("Authorization", `Bearer ${referred.token}`);
    expect(referredRewards.body.some((r: { type: string }) => r.type === "referral_referred")).toBe(true);

    const referral = await prisma.referral.findFirst({ where: { referredUserId: referred.user.id } });
    expect(referral?.status).toBe("REWARDED");
  });
});

describe("rebooking - next availability", () => {
  it("finds the next open day and slots for the same professional", async () => {
    await resetDb();
    const weekday = 4;
    const setup = await setUpBusiness({ ownerEmail: "rebook-owner@example.com", name: "Rebook Salon", priceCents: 3500, weekday });

    const expectedDate = nextWeekdayDateString(weekday);
    const tomorrow = new Date();
    tomorrow.setUTCDate(tomorrow.getUTCDate() + 1);
    const afterDate = tomorrow.toISOString().slice(0, 10);

    const res = await request(app).get(
      `/api/v1/professionals/${setup.professionalId}/next-availability?serviceId=${setup.serviceId}&afterDate=${afterDate}&withinDays=14`
    );
    expect(res.status).toBe(200);
    expect(res.body.date).toBe(expectedDate);
    expect(res.body.slots.length).toBeGreaterThan(0);
  });
});

describe("notifications", () => {
  it("creates a transactional notification on booking, marks it read", async () => {
    await resetDb();
    const setup = await setUpBusiness({ ownerEmail: "notif-owner@example.com", name: "Notif Salon", priceCents: 3000, weekday: 5 });
    const client = await registerAndLogin("notif-client@example.com", "CLIENT", "Client");
    const date = nextWeekdayDateString(5);

    const booking = await request(app)
      .post("/api/v1/bookings")
      .set("Authorization", `Bearer ${client.token}`)
      .send({ professionalId: setup.professionalId, serviceId: setup.serviceId, startTime: `${date}T09:00:00.000Z` });
    expect(booking.status).toBe(201);

    const notifications = await request(app)
      .get("/api/v1/notifications/me")
      .set("Authorization", `Bearer ${client.token}`);
    const confirmed = notifications.body.find((n: { type: string }) => n.type === "booking_confirmed");
    expect(confirmed).toBeTruthy();
    expect(confirmed.readAt).toBeNull();

    const markRead = await request(app)
      .patch(`/api/v1/notifications/${confirmed.id}/read`)
      .set("Authorization", `Bearer ${client.token}`);
    expect(markRead.status).toBe(200);
    expect(markRead.body.readAt).not.toBeNull();
  });
});
