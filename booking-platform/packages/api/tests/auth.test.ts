import request from "supertest";
import { createApp } from "../src/app";
import { resetDb } from "./helpers/db";

const app = createApp();

beforeAll(async () => {
  await resetDb();
});

describe("auth", () => {
  const email = "owner@example.com";
  const password = "password123";

  it("registers a new user and returns tokens", async () => {
    const res = await request(app)
      .post("/api/v1/auth/register")
      .send({ email, password, name: "Owner", role: "SALON_OWNER" });

    expect(res.status).toBe(201);
    expect(res.body.user.email).toBe(email);
    expect(res.body.user.passwordHash).toBeUndefined();
    expect(res.body.accessToken).toEqual(expect.any(String));
    expect(res.body.refreshToken).toEqual(expect.any(String));
    expect(res.body.user.referralCode).toEqual(expect.any(String));
  });

  it("rejects a duplicate email", async () => {
    const res = await request(app)
      .post("/api/v1/auth/register")
      .send({ email, password, name: "Owner Again", role: "SALON_OWNER" });

    expect(res.status).toBe(400);
  });

  it("logs in with correct credentials", async () => {
    const res = await request(app).post("/api/v1/auth/login").send({ email, password });
    expect(res.status).toBe(200);
    expect(res.body.accessToken).toEqual(expect.any(String));
  });

  it("rejects an incorrect password", async () => {
    const res = await request(app).post("/api/v1/auth/login").send({ email, password: "wrong-password" });
    expect(res.status).toBe(401);
  });

  it("refreshes tokens", async () => {
    const login = await request(app).post("/api/v1/auth/login").send({ email, password });
    const res = await request(app).post("/api/v1/auth/refresh").send({ refreshToken: login.body.refreshToken });
    expect(res.status).toBe(200);
    expect(res.body.accessToken).toEqual(expect.any(String));
  });

  it("registers with a referral code and links the referrer", async () => {
    const login = await request(app).post("/api/v1/auth/login").send({ email, password });
    const code = login.body.user.referralCode;

    const referred = await request(app)
      .post("/api/v1/auth/register")
      .send({ email: "friend@example.com", password, name: "Friend", role: "CLIENT", referralCode: code });

    expect(referred.status).toBe(201);
  });

  it("rejects an invalid referral code", async () => {
    const res = await request(app)
      .post("/api/v1/auth/register")
      .send({ email: "nofriend@example.com", password, name: "No Friend", role: "CLIENT", referralCode: "does-not-exist" });

    expect(res.status).toBe(400);
  });
});
