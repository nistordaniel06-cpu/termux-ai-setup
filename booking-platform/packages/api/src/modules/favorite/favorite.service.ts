import { prisma } from "../../lib/prisma";
import { getBusinessById } from "../business/business.service";

export async function addFavorite(userId: string, businessIdOrSlug: string) {
  const business = await getBusinessById(businessIdOrSlug);

  return prisma.favorite.upsert({
    where: { userId_businessId: { userId, businessId: business.id } },
    create: { userId, businessId: business.id },
    update: {},
  });
}

export async function removeFavorite(userId: string, businessIdOrSlug: string) {
  const business = await getBusinessById(businessIdOrSlug);

  await prisma.favorite.deleteMany({ where: { userId, businessId: business.id } });
}

export async function listMyFavorites(userId: string) {
  return prisma.favorite.findMany({
    where: { userId },
    include: { business: true },
    orderBy: { createdAt: "desc" },
  });
}
