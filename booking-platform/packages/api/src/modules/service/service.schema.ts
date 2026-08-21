import { z } from "zod";

export const updateServiceSchema = z.object({
  name: z.string().min(1).optional(),
  durationMinutes: z.number().int().positive().optional(),
  priceCents: z.number().int().nonnegative().optional(),
  active: z.boolean().optional(),
});
