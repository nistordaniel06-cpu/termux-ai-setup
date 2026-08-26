import { z } from "zod";
import { prisma } from "../../lib/prisma";
import { notFound } from "../../lib/errors";
import { requireBusinessStaffAccess } from "../business/business.service";
import { listCustomersQuerySchema } from "./customer.schema";

type CustomerWithUser = {
  id: string;
  visitCount: number;
  firstVisitAt: Date | null;
  lastVisitAt: Date | null;
  user: { id: string; name: string; email: string; phone: string | null };
};

function toCustomerSummary(customer: CustomerWithUser) {
  return {
    id: customer.id,
    userId: customer.user.id,
    name: customer.user.name,
    email: customer.user.email,
    phone: customer.user.phone,
    visitCount: customer.visitCount,
    firstVisitAt: customer.firstVisitAt,
    lastVisitAt: customer.lastVisitAt,
  };
}

export async function listCustomers(
  businessId: string,
  userId: string,
  query: z.infer<typeof listCustomersQuerySchema>
) {
  await requireBusinessStaffAccess(businessId, userId);

  const orderBy =
    query.sort === "visits"
      ? { visitCount: "desc" as const }
      : query.sort === "name"
        ? { user: { name: "asc" as const } }
        : { lastVisitAt: "desc" as const };

  const customers = await prisma.customer.findMany({
    where: {
      businessId,
      ...(query.q
        ? {
            user: {
              OR: [
                { name: { contains: query.q, mode: "insensitive" as const } },
                { email: { contains: query.q, mode: "insensitive" as const } },
              ],
            },
          }
        : {}),
    },
    include: { user: true },
    orderBy,
    take: query.take,
  });

  return customers.map(toCustomerSummary);
}

export async function getCustomerDetail(businessId: string, customerId: string, userId: string) {
  await requireBusinessStaffAccess(businessId, userId);

  const customer = await prisma.customer.findFirst({
    where: { id: customerId, businessId },
    include: { user: true },
  });
  if (!customer) throw notFound("Customer not found");

  const bookings = await prisma.booking.findMany({
    where: { businessId, customerId: customer.userId },
    include: { service: true, professional: true },
    orderBy: { startTime: "desc" },
  });

  // Known simplification: sums each booking's *current* service price, not a
  // price snapshot at booking time (Booking doesn't store one) — same
  // pricing caveat as the rest of the MVP, see README "Known simplifications".
  const totalSpentCents = bookings
    .filter((b) => b.status !== "CANCELLED")
    .reduce((sum, b) => sum + b.service.priceCents, 0);

  return {
    ...toCustomerSummary(customer),
    bookings,
    totalSpentCents,
  };
}
