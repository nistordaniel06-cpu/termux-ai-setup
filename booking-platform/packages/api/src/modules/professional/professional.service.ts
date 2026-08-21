import { z } from "zod";
import { Prisma } from "@prisma/client";
import { prisma } from "../../lib/prisma";
import { badRequest, forbidden, notFound } from "../../lib/errors";
import {
  updateProfessionalSchema,
  setScheduleSchema,
  addAvailabilityOverrideSchema,
} from "./professional.schema";
import { combineDateAndTime, subtractIntervals, generateCandidateSlots, Interval } from "./availability.util";

type DbClient = typeof prisma | Prisma.TransactionClient;

/**
 * The professional's bookable windows for a single calendar day: weekly
 * schedule plus one-off additions, minus one-off blocks. Does not account
 * for existing bookings — callers subtract those separately.
 */
export async function getAvailableWindows(client: DbClient, professionalId: string, date: Date): Promise<Interval[]> {
  const dayOfWeek = date.getUTCDay();

  const [weeklySchedule, overrides] = await Promise.all([
    client.schedule.findUnique({ where: { professionalId_dayOfWeek: { professionalId, dayOfWeek } } }),
    client.availability.findMany({ where: { professionalId, date } }),
  ]);

  let windows: Interval[] = weeklySchedule
    ? [{ start: combineDateAndTime(date, weeklySchedule.startTime), end: combineDateAndTime(date, weeklySchedule.endTime) }]
    : [];

  const addedWindows = overrides
    .filter((o) => !o.isBlocked)
    .map((o) => ({ start: combineDateAndTime(date, o.startTime), end: combineDateAndTime(date, o.endTime) }));
  windows = windows.concat(addedWindows);

  const blockedWindows = overrides
    .filter((o) => o.isBlocked)
    .map((o) => ({ start: combineDateAndTime(date, o.startTime), end: combineDateAndTime(date, o.endTime) }));

  return subtractIntervals(windows, blockedWindows);
}

export async function getProfessionalById(id: string) {
  const professional = await prisma.professional.findUnique({ where: { id } });
  if (!professional) throw notFound("Professional not found");
  return professional;
}

async function requireOwnerOrSelf(professionalId: string, userId: string) {
  const professional = await getProfessionalById(professionalId);
  if (professional.userId === userId) return professional;

  const business = await prisma.business.findUnique({ where: { id: professional.businessId } });
  if (business?.ownerId === userId) return professional;

  throw forbidden("You cannot manage this professional's calendar");
}

export async function updateProfessional(
  id: string,
  userId: string,
  input: z.infer<typeof updateProfessionalSchema>
) {
  await requireOwnerOrSelf(id, userId);
  return prisma.professional.update({ where: { id }, data: input });
}

export async function setSchedule(professionalId: string, userId: string, input: z.infer<typeof setScheduleSchema>) {
  await requireOwnerOrSelf(professionalId, userId);
  if (input.startTime >= input.endTime) throw badRequest("startTime must be before endTime");

  return prisma.schedule.upsert({
    where: { professionalId_dayOfWeek: { professionalId, dayOfWeek: input.dayOfWeek } },
    create: { professionalId, ...input },
    update: { startTime: input.startTime, endTime: input.endTime },
  });
}

export async function getSchedule(professionalId: string) {
  await getProfessionalById(professionalId);
  return prisma.schedule.findMany({ where: { professionalId }, orderBy: { dayOfWeek: "asc" } });
}

export async function addAvailabilityOverride(
  professionalId: string,
  userId: string,
  input: z.infer<typeof addAvailabilityOverrideSchema>
) {
  await requireOwnerOrSelf(professionalId, userId);
  if (input.startTime >= input.endTime) throw badRequest("startTime must be before endTime");

  return prisma.availability.create({
    data: {
      professionalId,
      date: new Date(`${input.date}T00:00:00.000Z`),
      startTime: input.startTime,
      endTime: input.endTime,
      isBlocked: input.isBlocked,
    },
  });
}

export async function computeOpenSlots(professionalId: string, dateStr: string, serviceId: string) {
  const professional = await getProfessionalById(professionalId);
  const service = await prisma.service.findUnique({ where: { id: serviceId } });
  if (!service || !service.active || service.businessId !== professional.businessId) {
    throw badRequest("serviceId does not belong to this professional's business");
  }

  const date = new Date(`${dateStr}T00:00:00.000Z`);

  const [windows, existingBookings] = await Promise.all([
    getAvailableWindows(prisma, professionalId, date),
    prisma.booking.findMany({
      where: {
        professionalId,
        status: { notIn: ["CANCELLED"] },
        startTime: { gte: date, lt: new Date(date.getTime() + 24 * 60 * 60 * 1000) },
      },
    }),
  ]);

  // Existing bookings are also "blocked" time for slot generation purposes.
  const bookedIntervals = existingBookings.map((b) => ({ start: b.startTime, end: b.endTime }));
  const openWindows = subtractIntervals(windows, bookedIntervals);

  let slots = generateCandidateSlots(openWindows, service.durationMinutes);

  const now = new Date();
  slots = slots.filter((s) => s.getTime() > now.getTime());

  return slots.map((s) => s.toISOString());
}

function toDateString(date: Date): string {
  return date.toISOString().slice(0, 10);
}

/**
 * Rebooking (brief section 9): "one click" to find the same professional's
 * next open slots on or after a given date, so the client doesn't have to
 * page through the calendar day by day themselves.
 */
export async function findNextAvailability(
  professionalId: string,
  serviceId: string,
  afterDateStr: string,
  withinDays = 30
) {
  const start = new Date(`${afterDateStr}T00:00:00.000Z`);

  for (let i = 0; i < withinDays; i++) {
    const date = new Date(start.getTime() + i * 24 * 60 * 60 * 1000);
    const dateStr = toDateString(date);
    const slots = await computeOpenSlots(professionalId, dateStr, serviceId);
    if (slots.length > 0) return { date: dateStr, slots };
  }

  return { date: null, slots: [] as string[] };
}
