import { z } from "zod";

export const setDiscountLimitsSchema = z
  .object({
    minDiscountPercent: z.number().int().min(1).max(90),
    maxDiscountPercent: z.number().int().min(1).max(90),
  })
  .refine((d) => d.minDiscountPercent <= d.maxDiscountPercent, {
    message: "minDiscountPercent must be <= maxDiscountPercent",
  });

export const createOfferSchema = z.object({
  discountPercent: z.number().int().min(1).max(90),
  startsAt: z.string().datetime(),
  endsAt: z.string().datetime(),
});
