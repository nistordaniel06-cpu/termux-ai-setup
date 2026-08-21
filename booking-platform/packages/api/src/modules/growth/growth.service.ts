import { z } from "zod";
import { prisma } from "../../lib/prisma";
import { badRequest } from "../../lib/errors";
import { requireOwnedBusiness, getBusinessById } from "../business/business.service";
import { createNotification } from "../notification/notification.service";
import { setDiscountLimitsSchema, createOfferSchema } from "./growth.schema";

export async function setDiscountLimits(
  businessId: string,
  ownerId: string,
  input: z.infer<typeof setDiscountLimitsSchema>
) {
  await requireOwnedBusiness(businessId, ownerId);
  return prisma.business.update({
    where: { id: businessId },
    data: { minDiscountPercent: input.minDiscountPercent, maxDiscountPercent: input.maxDiscountPercent },
  });
}

/**
 * Empty-slot discounts (brief section 6): the business must configure
 * min/max limits first, and every offer's discount is validated against
 * them — never applied without the business's own configuration.
 */
export async function createOffer(businessId: string, ownerId: string, input: z.infer<typeof createOfferSchema>) {
  const business = await requireOwnedBusiness(businessId, ownerId);

  if (business.minDiscountPercent === null || business.maxDiscountPercent === null) {
    throw badRequest("Configure discount limits (min/max) before creating an offer");
  }
  if (input.discountPercent < business.minDiscountPercent || input.discountPercent > business.maxDiscountPercent) {
    throw badRequest(
      `discountPercent must be between ${business.minDiscountPercent} and ${business.maxDiscountPercent}`
    );
  }

  const startsAt = new Date(input.startsAt);
  const endsAt = new Date(input.endsAt);
  if (endsAt <= startsAt) throw badRequest("endsAt must be after startsAt");

  const offer = await prisma.offer.create({
    data: { businessId, discountPercent: input.discountPercent, startsAt, endsAt },
  });

  // Surface the offer to people who already care about this business, not
  // as a blast to everyone — and only to those who haven't opted out.
  const favorites = await prisma.favorite.findMany({ where: { businessId } });
  for (const favorite of favorites) {
    await createNotification(
      prisma,
      favorite.userId,
      "offer_available",
      { businessId, businessName: business.name, offerId: offer.id, discountPercent: offer.discountPercent },
      { commercial: true }
    );
  }

  return offer;
}

export async function listOffers(businessIdOrSlug: string) {
  const business = await getBusinessById(businessIdOrSlug);
  const now = new Date();
  return prisma.offer.findMany({
    where: { businessId: business.id, endsAt: { gte: now } },
    orderBy: { startsAt: "asc" },
  });
}

export async function getActiveOffer(businessId: string) {
  const now = new Date();
  return prisma.offer.findFirst({
    where: { businessId, startsAt: { lte: now }, endsAt: { gte: now } },
    orderBy: { discountPercent: "desc" },
  });
}
