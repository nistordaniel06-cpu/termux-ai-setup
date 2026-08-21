import { z } from "zod";

export const updateProfessionalSchema = z.object({
  displayName: z.string().min(1).optional(),
  bio: z.string().optional(),
  active: z.boolean().optional(),
});

const hhmm = z.string().regex(/^([01]\d|2[0-3]):[0-5]\d$/, "Expected HH:mm");

export const setScheduleSchema = z.object({
  dayOfWeek: z.number().int().min(0).max(6),
  startTime: hhmm,
  endTime: hhmm,
});

export const addAvailabilityOverrideSchema = z.object({
  date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/, "Expected YYYY-MM-DD"),
  startTime: hhmm,
  endTime: hhmm,
  isBlocked: z.boolean().default(false),
});

export const getOpenSlotsQuerySchema = z.object({
  date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/, "Expected YYYY-MM-DD"),
  serviceId: z.string().uuid(),
});
