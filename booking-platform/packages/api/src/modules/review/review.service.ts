import { z } from "zod";
import { prisma } from "../../lib/prisma";
import { badRequest, forbidden, notFound } from "../../lib/errors";
import { getBusinessById } from "../business/business.service";
import { createReviewSchema } from "./review.schema";

export async function createReview(bookingId: string, userId: string, input: z.infer<typeof createReviewSchema>) {
  const booking = await prisma.booking.findUnique({ where: { id: bookingId }, include: { review: true } });
  if (!booking) throw notFound("Booking not found");
  if (booking.customerId !== userId) throw forbidden("You can only review your own bookings");
  if (booking.status === "CANCELLED") throw badRequest("Cannot review a cancelled booking");
  if (booking.startTime.getTime() > Date.now()) throw badRequest("Cannot review a booking that hasn't happened yet");
  if (booking.review) throw badRequest("This booking already has a review");

  return prisma.review.create({
    data: {
      bookingId,
      userId,
      rating: input.rating,
      comment: input.comment,
    },
  });
}

export async function listForBusiness(idOrSlug: string) {
  const business = await getBusinessById(idOrSlug);

  const reviews = await prisma.review.findMany({
    where: { booking: { businessId: business.id } },
    include: { user: { select: { name: true } } },
    orderBy: { createdAt: "desc" },
  });

  const avgRating =
    reviews.length > 0 ? reviews.reduce((sum, r) => sum + r.rating, 0) / reviews.length : null;

  return { reviews, avgRating, reviewCount: reviews.length };
}
