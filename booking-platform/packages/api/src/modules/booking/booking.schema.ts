import { z } from "zod";

export const createBookingSchema = z.object({
  professionalId: z.string().uuid(),
  serviceId: z.string().uuid(),
  startTime: z.string().datetime(),
});

export const rescheduleBookingSchema = z.object({
  startTime: z.string().datetime(),
});
