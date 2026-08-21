import { z } from "zod";

export const setLoyaltyConfigSchema = z.object({
  visitsRequired: z.number().int().min(2).max(100).nullable(),
});
