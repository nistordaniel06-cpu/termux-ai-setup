import { prisma } from "../../src/lib/prisma";

export async function resetDb() {
  await prisma.$executeRawUnsafe(`
    TRUNCATE TABLE
      "AnalyticsEvent", "Notification", "Reward", "Referral", "Offer", "Review",
      "Customer", "Booking", "Availability", "Schedule", "Service", "Professional", "Business", "User"
    RESTART IDENTITY CASCADE;
  `);
}
