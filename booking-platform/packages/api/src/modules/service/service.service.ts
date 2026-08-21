import { z } from "zod";
import { prisma } from "../../lib/prisma";
import { forbidden, notFound } from "../../lib/errors";
import { updateServiceSchema } from "./service.schema";

async function requireOwnedService(serviceId: string, ownerId: string) {
  const service = await prisma.service.findUnique({ where: { id: serviceId }, include: { business: true } });
  if (!service) throw notFound("Service not found");
  if (service.business.ownerId !== ownerId) throw forbidden("You do not own this service");
  return service;
}

export async function updateService(serviceId: string, ownerId: string, input: z.infer<typeof updateServiceSchema>) {
  await requireOwnedService(serviceId, ownerId);
  return prisma.service.update({ where: { id: serviceId }, data: input });
}

export async function deleteService(serviceId: string, ownerId: string) {
  await requireOwnedService(serviceId, ownerId);
  // Soft delete: services referenced by past bookings must not disappear.
  return prisma.service.update({ where: { id: serviceId }, data: { active: false } });
}
