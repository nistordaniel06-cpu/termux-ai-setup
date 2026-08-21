import "dotenv/config";
import { config } from "dotenv";
import path from "path";

config({ path: path.join(__dirname, "..", ".env.test"), override: true });

import { prisma } from "../src/lib/prisma";

afterAll(async () => {
  await prisma.$disconnect();
});
