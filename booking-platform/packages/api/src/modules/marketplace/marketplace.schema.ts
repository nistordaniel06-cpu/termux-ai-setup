import { z } from "zod";

export const searchQuerySchema = z.object({
  q: z.string().trim().optional(),
  city: z.string().trim().optional(),
  lat: z.coerce.number().optional(),
  lng: z.coerce.number().optional(),
  maxPriceCents: z.coerce.number().int().nonnegative().optional(),
  date: z
    .string()
    .regex(/^\d{4}-\d{2}-\d{2}$/, "Expected YYYY-MM-DD")
    .optional(),
  limit: z.coerce.number().int().positive().max(50).default(20),
});
