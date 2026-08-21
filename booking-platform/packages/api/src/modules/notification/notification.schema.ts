import { z } from "zod";

export const setPreferenceSchema = z.object({
  notificationsEnabled: z.boolean(),
});
