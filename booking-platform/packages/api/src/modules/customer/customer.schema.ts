import { z } from "zod";

export const listCustomersQuerySchema = z.object({
  q: z.string().trim().min(1).optional(),
  sort: z.enum(["recent", "visits", "name"]).default("recent"),
  take: z.coerce.number().int().min(1).max(100).default(50),
});
