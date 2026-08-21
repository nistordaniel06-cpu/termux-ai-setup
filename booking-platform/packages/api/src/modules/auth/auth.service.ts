import bcrypt from "bcryptjs";
import { randomBytes } from "crypto";
import { prisma } from "../../lib/prisma";
import { signAccessToken, signRefreshToken, verifyRefreshToken } from "../../lib/jwt";
import { badRequest, unauthorized } from "../../lib/errors";
import { registerSchema, loginSchema } from "./auth.schema";
import { z } from "zod";

async function generateReferralCode(name: string): Promise<string> {
  const base = name
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "")
    .slice(0, 8) || "user";

  for (let attempt = 0; attempt < 5; attempt++) {
    const suffix = randomBytes(3).toString("hex");
    const code = `${base}-${suffix}`;
    const existing = await prisma.user.findUnique({ where: { referralCode: code } });
    if (!existing) return code;
  }
  throw new Error("Could not generate a unique referral code");
}

function tokensFor(user: { id: string; role: "CLIENT" | "PROFESSIONAL" | "SALON_OWNER" }) {
  const payload = { sub: user.id, role: user.role };
  return {
    accessToken: signAccessToken(payload),
    refreshToken: signRefreshToken(payload),
  };
}

export async function register(input: z.infer<typeof registerSchema>) {
  const existing = await prisma.user.findUnique({ where: { email: input.email } });
  if (existing) throw badRequest("Email already registered");

  let referredById: string | undefined;
  if (input.referralCode) {
    const referrer = await prisma.user.findUnique({ where: { referralCode: input.referralCode } });
    if (!referrer) throw badRequest("Invalid referral code");
    referredById = referrer.id;
  }

  const passwordHash = await bcrypt.hash(input.password, 10);
  const referralCode = await generateReferralCode(input.name);

  const user = await prisma.user.create({
    data: {
      email: input.email,
      passwordHash,
      name: input.name,
      phone: input.phone,
      role: input.role,
      referralCode,
      referredById,
    },
  });

  // Tracked separately from User.referredById so reward status (PENDING ->
  // REWARDED once a real booking happens) doesn't get conflated with the
  // one-time signup link.
  if (referredById) {
    await prisma.referral.create({
      data: { referrerUserId: referredById, referredUserId: user.id },
    });
  }

  return { user, ...tokensFor(user) };
}

export async function login(input: z.infer<typeof loginSchema>) {
  const user = await prisma.user.findUnique({ where: { email: input.email } });
  if (!user) throw unauthorized("Invalid email or password");

  const valid = await bcrypt.compare(input.password, user.passwordHash);
  if (!valid) throw unauthorized("Invalid email or password");

  return { user, ...tokensFor(user) };
}

export async function refresh(refreshToken: string) {
  let payload;
  try {
    payload = verifyRefreshToken(refreshToken);
  } catch {
    throw unauthorized("Invalid or expired refresh token");
  }

  const user = await prisma.user.findUnique({ where: { id: payload.sub } });
  if (!user) throw unauthorized("Invalid refresh token");

  return tokensFor(user);
}

export function toPublicUser(user: {
  id: string;
  email: string;
  name: string;
  phone: string | null;
  role: string;
  referralCode: string;
}) {
  return {
    id: user.id,
    email: user.email,
    name: user.name,
    phone: user.phone,
    role: user.role,
    referralCode: user.referralCode,
  };
}
