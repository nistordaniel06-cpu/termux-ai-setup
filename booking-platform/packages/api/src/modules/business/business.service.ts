import { prisma } from "../../lib/prisma";
import { badRequest, forbidden, notFound } from "../../lib/errors";
import { z } from "zod";
import { createBusinessSchema, updateBusinessSchema, addProfessionalSchema, addServiceSchema } from "./business.schema";

function slugify(name: string): string {
  return name
    .toLowerCase()
    .trim()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/(^-|-$)/g, "");
}

async function uniqueSlug(name: string): Promise<string> {
  const base = slugify(name) || "business";
  let slug = base;
  let i = 1;
  while (await prisma.business.findUnique({ where: { slug } })) {
    slug = `${base}-${i++}`;
  }
  return slug;
}

export async function createBusiness(
  ownerId: string,
  ownerRole: "CLIENT" | "PROFESSIONAL" | "SALON_OWNER",
  input: z.infer<typeof createBusinessSchema>
) {
  if (ownerRole === "CLIENT") throw forbidden("Only professionals or salon owners can create a business");

  const existing = await prisma.business.findFirst({ where: { ownerId } });
  if (existing) throw badRequest("This account already owns a business");

  const slug = await uniqueSlug(input.name);

  return prisma.business.create({
    data: {
      ownerId,
      name: input.name,
      slug,
      description: input.description,
      address: input.address,
      city: input.city,
      latitude: input.latitude,
      longitude: input.longitude,
      // A solo professional's business comes with themselves as the first professional.
      professionals:
        ownerRole === "PROFESSIONAL"
          ? { create: [{ userId: ownerId, displayName: input.name }] }
          : undefined,
    },
    include: { professionals: true },
  });
}

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/** Looks up a business by id, or by its public slug if idOrSlug isn't a UUID. */
export async function getBusinessById(idOrSlug: string) {
  const business = UUID_RE.test(idOrSlug)
    ? await prisma.business.findUnique({ where: { id: idOrSlug } })
    : await prisma.business.findUnique({ where: { slug: idOrSlug } });
  if (!business) throw notFound("Business not found");
  return business;
}

export async function getMyBusiness(ownerId: string) {
  const business = await prisma.business.findFirst({ where: { ownerId } });
  if (!business) throw notFound("No business found for this account");
  return business;
}

export async function requireOwnedBusiness(businessId: string, ownerId: string) {
  const business = await getBusinessById(businessId);
  if (business.ownerId !== ownerId) throw forbidden("You do not own this business");
  return business;
}

export async function updateBusiness(
  businessId: string,
  ownerId: string,
  input: z.infer<typeof updateBusinessSchema>
) {
  await requireOwnedBusiness(businessId, ownerId);
  return prisma.business.update({ where: { id: businessId }, data: input });
}

export async function addProfessional(
  businessId: string,
  ownerId: string,
  input: z.infer<typeof addProfessionalSchema>
) {
  await requireOwnedBusiness(businessId, ownerId);

  const user = await prisma.user.findUnique({ where: { id: input.userId } });
  if (!user || user.role !== "PROFESSIONAL") {
    throw badRequest("userId must belong to an existing account with role PROFESSIONAL");
  }

  const alreadyLinked = await prisma.professional.findUnique({ where: { userId: input.userId } });
  if (alreadyLinked) throw badRequest("This user is already a professional somewhere");

  return prisma.professional.create({
    data: {
      userId: input.userId,
      businessId,
      displayName: input.displayName,
      bio: input.bio,
    },
  });
}

export async function listProfessionals(businessId: string) {
  await getBusinessById(businessId);
  return prisma.professional.findMany({ where: { businessId, active: true } });
}

export async function addService(businessId: string, ownerId: string, input: z.infer<typeof addServiceSchema>) {
  await requireOwnedBusiness(businessId, ownerId);
  return prisma.service.create({
    data: {
      businessId,
      name: input.name,
      durationMinutes: input.durationMinutes,
      priceCents: input.priceCents,
    },
  });
}

export async function listServices(businessId: string) {
  await getBusinessById(businessId);
  return prisma.service.findMany({ where: { businessId, active: true } });
}
