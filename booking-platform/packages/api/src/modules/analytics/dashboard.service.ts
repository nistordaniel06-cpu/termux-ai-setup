import { prisma } from "../../lib/prisma";
import { requireBusinessStaffAccess } from "../business/business.service";
import { getAvailableWindows } from "../professional/professional.service";
import { subtractIntervals, generateCandidateSlots } from "../professional/availability.util";

const EMPTY_SLOT_GRANULARITY_MINUTES = 30;

export async function getDashboard(businessId: string, userId: string) {
  await requireBusinessStaffAccess(businessId, userId);

  const professionals = await prisma.professional.findMany({ where: { businessId, active: true } });
  const now = new Date();
  const today = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate()));
  const tomorrow = new Date(today.getTime() + 24 * 60 * 60 * 1000);

  let totalAvailableMinutes = 0;
  let totalBookedMinutes = 0;
  let emptySlotsToday = 0;

  for (const professional of professionals) {
    const windows = await getAvailableWindows(prisma, professional.id, today);
    const bookingsToday = await prisma.booking.findMany({
      where: {
        professionalId: professional.id,
        status: { notIn: ["CANCELLED"] },
        startTime: { gte: today, lt: tomorrow },
      },
    });

    totalAvailableMinutes += windows.reduce((sum, w) => sum + (w.end.getTime() - w.start.getTime()) / 60_000, 0);
    totalBookedMinutes += bookingsToday.reduce(
      (sum, b) => sum + (b.endTime.getTime() - b.startTime.getTime()) / 60_000,
      0
    );

    const openWindows = subtractIntervals(
      windows,
      bookingsToday.map((b) => ({ start: b.startTime, end: b.endTime }))
    );
    emptySlotsToday += generateCandidateSlots(openWindows, EMPTY_SLOT_GRANULARITY_MINUTES).length;
  }

  const occupancyPercent =
    totalAvailableMinutes > 0 ? Math.round((totalBookedMinutes / totalAvailableMinutes) * 100) : 0;

  const upcomingBookings = await prisma.booking.findMany({
    where: { businessId, status: { notIn: ["CANCELLED"] }, startTime: { gte: now } },
    include: { service: true, professional: true, customer: true },
    orderBy: { startTime: "asc" },
    take: 20,
  });

  return { occupancyPercent, emptySlotsToday, upcomingBookings };
}
