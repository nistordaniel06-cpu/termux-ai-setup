import { z } from "zod";
import { Prisma } from "@prisma/client";
import { prisma } from "../../lib/prisma";
import { badRequest, conflict, forbidden, notFound } from "../../lib/errors";
import { getAvailableWindows } from "../professional/professional.service";
import { createNotification } from "../notification/notification.service";
import { evaluateReferralReward } from "../reward/reward.service";
import { createBookingSchema } from "./booking.schema";

function isRaceConditionError(err: unknown): boolean {
  if (err instanceof Prisma.PrismaClientKnownRequestError) {
    // P2002: unique constraint (same professional + exact start time)
    // P2034: transaction write conflict under SERIALIZABLE isolation
    return err.code === "P2002" || err.code === "P2034";
  }
  return false;
}

async function assertSlotIsBookable(
  tx: Prisma.TransactionClient,
  professionalId: string,
  startTime: Date,
  endTime: Date,
  excludeBookingId?: string
) {
  const day = new Date(Date.UTC(startTime.getUTCFullYear(), startTime.getUTCMonth(), startTime.getUTCDate()));
  const windows = await getAvailableWindows(tx, professionalId, day);
  const fits = windows.some((w) => w.start <= startTime && endTime <= w.end);
  if (!fits) throw badRequest("That time is outside the professional's available hours");

  const overlapping = await tx.booking.findFirst({
    where: {
      professionalId,
      id: excludeBookingId ? { not: excludeBookingId } : undefined,
      status: { notIn: ["CANCELLED"] },
      startTime: { lt: endTime },
      endTime: { gt: startTime },
    },
  });
  if (overlapping) throw conflict("That time slot was just booked");
}

export async function createBooking(customerId: string, input: z.infer<typeof createBookingSchema>) {
  const professional = await prisma.professional.findUnique({ where: { id: input.professionalId } });
  if (!professional || !professional.active) throw notFound("Professional not found");

  const service = await prisma.service.findUnique({ where: { id: input.serviceId } });
  if (!service || !service.active || service.businessId !== professional.businessId) {
    throw badRequest("serviceId does not belong to this professional's business");
  }

  const business = await prisma.business.findUniqueOrThrow({ where: { id: professional.businessId } });

  const startTime = new Date(input.startTime);
  if (startTime.getTime() <= Date.now()) throw badRequest("startTime must be in the future");
  const endTime = new Date(startTime.getTime() + service.durationMinutes * 60_000);

  try {
    return await prisma.$transaction(
      async (tx) => {
        await assertSlotIsBookable(tx, professional.id, startTime, endTime);

        const booking = await tx.booking.create({
          data: {
            customerId,
            businessId: professional.businessId,
            professionalId: professional.id,
            serviceId: service.id,
            startTime,
            endTime,
            status: "CONFIRMED",
          },
        });

        const customer = await tx.customer.upsert({
          where: { userId_businessId: { userId: customerId, businessId: professional.businessId } },
          create: {
            userId: customerId,
            businessId: professional.businessId,
            firstVisitAt: startTime,
            lastVisitAt: startTime,
            visitCount: 1,
          },
          update: { lastVisitAt: startTime, visitCount: { increment: 1 } },
        });

        await tx.analyticsEvent.create({
          data: {
            businessId: professional.businessId,
            type: "booking_created",
            payload: { bookingId: booking.id, professionalId: professional.id, serviceId: service.id },
          },
        });

        await createNotification(tx, customerId, "booking_confirmed", {
          bookingId: booking.id,
          startTime: booking.startTime,
        });

        // Loyalty (Phase 3): every Nth visit earns a reward, if the business
        // configured one. Never applies when loyaltyVisitsRequired is unset.
        if (business.loyaltyVisitsRequired && customer.visitCount % business.loyaltyVisitsRequired === 0) {
          await tx.reward.create({
            data: { userId: customerId, businessId: business.id, type: "loyalty_reward", amount: 1 },
          });
          await createNotification(tx, customerId, "loyalty_reward", {
            businessId: business.id,
            businessName: business.name,
            visitCount: customer.visitCount,
          });
        }

        return booking;
      },
      { isolationLevel: Prisma.TransactionIsolationLevel.Serializable }
    );
  } catch (err) {
    if (isRaceConditionError(err)) throw conflict("That time slot was just booked");
    throw err;
  }
}

async function requireBookingAccess(bookingId: string, userId: string) {
  const booking = await prisma.booking.findUnique({ where: { id: bookingId }, include: { business: true } });
  if (!booking) throw notFound("Booking not found");
  if (booking.customerId !== userId && booking.business.ownerId !== userId) {
    const isProfessional = await prisma.professional.findFirst({
      where: { id: booking.professionalId, userId },
    });
    if (!isProfessional) throw forbidden("You cannot manage this booking");
  }
  return booking;
}

export async function cancelBooking(bookingId: string, userId: string) {
  const booking = await requireBookingAccess(bookingId, userId);
  if (booking.status === "CANCELLED") return booking;

  const updated = await prisma.booking.update({ where: { id: bookingId }, data: { status: "CANCELLED" } });
  await createNotification(prisma, booking.customerId, "booking_cancelled", {
    bookingId: booking.id,
    startTime: booking.startTime,
  });
  return updated;
}

export async function rescheduleBooking(bookingId: string, userId: string, newStartTimeIso: string) {
  const booking = await requireBookingAccess(bookingId, userId);
  if (booking.status === "CANCELLED") throw badRequest("Cannot reschedule a cancelled booking");

  const durationMs = booking.endTime.getTime() - booking.startTime.getTime();
  const startTime = new Date(newStartTimeIso);
  if (startTime.getTime() <= Date.now()) throw badRequest("startTime must be in the future");
  const endTime = new Date(startTime.getTime() + durationMs);

  try {
    const updated = await prisma.$transaction(
      async (tx) => {
        await assertSlotIsBookable(tx, booking.professionalId, startTime, endTime, booking.id);
        const rescheduled = await tx.booking.update({ where: { id: booking.id }, data: { startTime, endTime } });
        await createNotification(tx, booking.customerId, "booking_rescheduled", {
          bookingId: booking.id,
          startTime: rescheduled.startTime,
        });
        return rescheduled;
      },
      { isolationLevel: Prisma.TransactionIsolationLevel.Serializable }
    );
    return updated;
  } catch (err) {
    if (isRaceConditionError(err)) throw conflict("That time slot was just booked");
    throw err;
  }
}

export async function listMyBookings(customerId: string) {
  await evaluateReferralReward(customerId);

  return prisma.booking.findMany({
    where: { customerId },
    include: { service: true, professional: true, business: true, review: true },
    orderBy: { startTime: "desc" },
  });
}

export async function listBusinessBookings(businessId: string, userId: string) {
  const business = await prisma.business.findUnique({ where: { id: businessId } });
  if (!business) throw notFound("Business not found");

  if (business.ownerId !== userId) {
    const isProfessional = await prisma.professional.findFirst({ where: { businessId, userId } });
    if (!isProfessional) throw forbidden("You cannot view this business's bookings");
  }

  return prisma.booking.findMany({
    where: { businessId },
    include: { service: true, professional: true, customer: true },
    orderBy: { startTime: "desc" },
  });
}
