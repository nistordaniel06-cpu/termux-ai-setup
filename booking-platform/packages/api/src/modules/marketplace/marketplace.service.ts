import { z } from "zod";
import { prisma } from "../../lib/prisma";
import { getAvailableWindows } from "../professional/professional.service";
import { subtractIntervals } from "../professional/availability.util";
import { computeDiscoveryScore, haversineKm } from "./discoveryScore";
import { searchQuerySchema } from "./marketplace.schema";

function todayDateString(): string {
  return new Date().toISOString().slice(0, 10);
}

async function hasAvailabilityOnDate(professionalIds: string[], date: Date): Promise<boolean> {
  for (const professionalId of professionalIds) {
    const windows = await getAvailableWindows(prisma, professionalId, date);
    if (windows.length === 0) continue;

    const bookingsToday = await prisma.booking.findMany({
      where: {
        professionalId,
        status: { notIn: ["CANCELLED"] },
        startTime: { gte: date, lt: new Date(date.getTime() + 24 * 60 * 60 * 1000) },
      },
    });
    const openWindows = subtractIntervals(
      windows,
      bookingsToday.map((b) => ({ start: b.startTime, end: b.endTime }))
    );
    if (openWindows.some((w) => w.end.getTime() > w.start.getTime())) return true;
  }
  return false;
}

export async function search(rawQuery: Record<string, unknown>) {
  const filters = searchQuerySchema.parse(rawQuery);
  const date = filters.date ?? todayDateString();
  const dateObj = new Date(`${date}T00:00:00.000Z`);

  const businesses = await prisma.business.findMany({
    where: {
      AND: [
        filters.city ? { city: { contains: filters.city, mode: "insensitive" } } : {},
        filters.q
          ? {
              OR: [
                { name: { contains: filters.q, mode: "insensitive" } },
                { services: { some: { name: { contains: filters.q, mode: "insensitive" }, active: true } } },
              ],
            }
          : {},
        filters.maxPriceCents !== undefined
          ? { services: { some: { active: true, priceCents: { lte: filters.maxPriceCents } } } }
          : {},
      ],
    },
    include: {
      services: { where: { active: true } },
      professionals: { where: { active: true } },
    },
    take: 50,
  });

  const results = await Promise.all(
    businesses.map(async (business) => {
      const professionalIds = business.professionals.map((p) => p.id);

      const [reviewAgg, totalBookings, cancelledBookings, hasAvailability] = await Promise.all([
        prisma.review.aggregate({
          where: { booking: { businessId: business.id } },
          _avg: { rating: true },
          _count: true,
        }),
        prisma.booking.count({ where: { businessId: business.id } }),
        prisma.booking.count({ where: { businessId: business.id, status: "CANCELLED" } }),
        professionalIds.length > 0 ? hasAvailabilityOnDate(professionalIds, dateObj) : false,
      ]);

      const distanceKm =
        filters.lat !== undefined &&
        filters.lng !== undefined &&
        business.latitude !== null &&
        business.longitude !== null
          ? haversineKm(filters.lat, filters.lng, business.latitude, business.longitude)
          : null;

      const priceMatches =
        filters.maxPriceCents === undefined
          ? null
          : business.services.some((s) => s.priceCents <= filters.maxPriceCents!);

      const reliability = totalBookings > 0 ? 1 - cancelledBookings / totalBookings : 1;

      const discoveryScore = computeDiscoveryScore({
        hasAvailability: professionalIds.length > 0 ? hasAvailability : null,
        distanceKm,
        avgRating: reviewAgg._count > 0 ? reviewAgg._avg.rating : null,
        priceMatches,
        reliability,
        totalBookings,
      });

      const cheapestService = business.services.reduce<(typeof business.services)[number] | null>(
        (min, s) => (min === null || s.priceCents < min.priceCents ? s : min),
        null
      );

      return {
        id: business.id,
        name: business.name,
        slug: business.slug,
        city: business.city,
        address: business.address,
        distanceKm,
        avgRating: reviewAgg._count > 0 ? reviewAgg._avg.rating : null,
        reviewCount: reviewAgg._count,
        hasAvailabilityToday: hasAvailability,
        fromPriceCents: cheapestService?.priceCents ?? null,
        discoveryScore,
      };
    })
  );

  results.sort((a, b) => b.discoveryScore - a.discoveryScore);

  return results.slice(0, filters.limit);
}
