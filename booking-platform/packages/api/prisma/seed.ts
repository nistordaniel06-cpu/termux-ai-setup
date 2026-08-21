import bcrypt from "bcryptjs";
import { PrismaClient } from "@prisma/client";

const prisma = new PrismaClient();

async function main() {
  const passwordHash = await bcrypt.hash("password123", 10);

  const owner = await prisma.user.upsert({
    where: { email: "dan@example.com" },
    update: {},
    create: {
      email: "dan@example.com",
      passwordHash,
      name: "Dan",
      role: "PROFESSIONAL",
      referralCode: "dan-seed01",
    },
  });

  const client = await prisma.user.upsert({
    where: { email: "client@example.com" },
    update: {},
    create: {
      email: "client@example.com",
      passwordHash,
      name: "Alex",
      role: "CLIENT",
      referralCode: "alex-seed01",
    },
  });

  let business = await prisma.business.findFirst({ where: { ownerId: owner.id } });
  if (!business) {
    business = await prisma.business.create({
      data: {
        ownerId: owner.id,
        name: "Dan's Barbershop",
        slug: "dans-barbershop",
        city: "Bucuresti",
        address: "Str. Exemplu 1",
        latitude: 44.4268,
        longitude: 26.1025,
        professionals: { create: [{ userId: owner.id, displayName: "Dan" }] },
      },
      include: { professionals: true },
    });
  }

  const professional = await prisma.professional.findFirstOrThrow({ where: { businessId: business.id } });

  const service = await prisma.service.upsert({
    where: { id: "00000000-0000-0000-0000-000000000001" },
    update: {},
    create: {
      id: "00000000-0000-0000-0000-000000000001",
      businessId: business.id,
      name: "Tuns barbati",
      durationMinutes: 30,
      priceCents: 6000,
    },
  });

  for (let day = 1; day <= 5; day++) {
    await prisma.schedule.upsert({
      where: { professionalId_dayOfWeek: { professionalId: professional.id, dayOfWeek: day } },
      update: {},
      create: { professionalId: professional.id, dayOfWeek: day, startTime: "09:00", endTime: "18:00" },
    });
  }

  console.log("Seeded:", { owner: owner.email, client: client.email, business: business.slug, service: service.name });
}

main()
  .catch((err) => {
    console.error(err);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
