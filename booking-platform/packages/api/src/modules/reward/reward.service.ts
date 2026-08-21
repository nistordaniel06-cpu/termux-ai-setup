import { prisma } from "../../lib/prisma";
import { createNotification } from "../notification/notification.service";

// Named, tunable constants (brief section 7: referrer gets credit/points,
// the referred friend gets a benefit too).
export const REFERRAL_REFERRER_POINTS = 100;
export const REFERRAL_REFERRED_POINTS = 50;

export async function listMyRewards(userId: string) {
  return prisma.reward.findMany({ where: { userId }, orderBy: { createdAt: "desc" } });
}

/**
 * Lazy evaluation: there's no background worker in this MVP, so instead of
 * a cron job we check-and-reward a pending referral the next time the
 * referred user's bookings are read (see booking.service.listMyBookings).
 * The reward only fires once a booking of theirs has actually happened —
 * never just on signup (brief section 7: "Reward-ul se acordă după
 * programare finalizată, nu doar după crearea contului").
 *
 * Abuse protection: a referral can only ever transition PENDING -> REWARDED
 * once (enforced by the conditional updateMany below plus the unique
 * (referrerUserId, referredUserId) constraint on Referral), so double-
 * crediting — including from two concurrent evaluations — is not possible.
 */
export async function evaluateReferralReward(referredUserId: string) {
  const pending = await prisma.referral.findFirst({
    where: { referredUserId, status: "PENDING" },
  });
  if (!pending) return;

  const qualifyingBooking = await prisma.booking.findFirst({
    where: {
      customerId: referredUserId,
      status: { not: "CANCELLED" },
      startTime: { lte: new Date() },
    },
  });
  if (!qualifyingBooking) return;

  await prisma.$transaction(async (tx) => {
    const updated = await tx.referral.updateMany({
      where: { id: pending.id, status: "PENDING" },
      data: { status: "REWARDED", rewardedAt: new Date() },
    });
    if (updated.count === 0) return; // another concurrent check already rewarded it

    await tx.reward.create({
      data: { userId: pending.referrerUserId, type: "referral_referrer", amount: REFERRAL_REFERRER_POINTS },
    });
    await tx.reward.create({
      data: { userId: pending.referredUserId, type: "referral_referred", amount: REFERRAL_REFERRED_POINTS },
    });

    await createNotification(tx, pending.referrerUserId, "referral_reward", { points: REFERRAL_REFERRER_POINTS });
    await createNotification(tx, pending.referredUserId, "referral_reward", { points: REFERRAL_REFERRED_POINTS });
  });
}
