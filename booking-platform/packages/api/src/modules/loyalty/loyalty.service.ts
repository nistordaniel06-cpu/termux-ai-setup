import { z } from "zod";
import { prisma } from "../../lib/prisma";
import { requireOwnedBusiness, getBusinessById } from "../business/business.service";
import { setLoyaltyConfigSchema } from "./loyalty.schema";

export async function setLoyaltyConfig(
  businessId: string,
  ownerId: string,
  input: z.infer<typeof setLoyaltyConfigSchema>
) {
  await requireOwnedBusiness(businessId, ownerId);
  return prisma.business.update({
    where: { id: businessId },
    data: { loyaltyVisitsRequired: input.visitsRequired },
  });
}

export async function getLoyaltyStatus(businessIdOrSlug: string, userId: string) {
  const business = await getBusinessById(businessIdOrSlug);
  if (!business.loyaltyVisitsRequired) return { enabled: false as const };

  const customer = await prisma.customer.findUnique({
    where: { userId_businessId: { userId, businessId: business.id } },
  });
  const currentVisits = customer?.visitCount ?? 0;
  const remainder = currentVisits % business.loyaltyVisitsRequired;
  const visitsUntilNextReward = remainder === 0 ? business.loyaltyVisitsRequired : business.loyaltyVisitsRequired - remainder;

  return {
    enabled: true as const,
    visitsRequired: business.loyaltyVisitsRequired,
    currentVisits,
    visitsUntilNextReward,
  };
}
