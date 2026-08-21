import { z } from "zod";

export const createBusinessSchema = z.object({
  name: z.string().min(1),
  description: z.string().optional(),
  address: z.string().optional(),
  city: z.string().optional(),
  latitude: z.number().optional(),
  longitude: z.number().optional(),
});

export const updateBusinessSchema = createBusinessSchema.partial();

export const addProfessionalSchema = z.object({
  userId: z.string().uuid(),
  displayName: z.string().min(1),
  bio: z.string().optional(),
});

export const addServiceSchema = z.object({
  name: z.string().min(1),
  durationMinutes: z.number().int().positive(),
  priceCents: z.number().int().nonnegative(),
});
