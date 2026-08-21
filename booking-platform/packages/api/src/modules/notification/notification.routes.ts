import { Router } from "express";
import { asyncHandler } from "../../middleware/errorHandler";
import { requireAuth } from "../../middleware/auth";
import { setPreferenceSchema } from "./notification.schema";
import * as notificationService from "./notification.service";

export const notificationRouter = Router();

notificationRouter.get(
  "/me",
  requireAuth,
  asyncHandler(async (req, res) => {
    const notifications = await notificationService.listMyNotifications(req.auth!.userId);
    res.json(notifications);
  })
);

notificationRouter.patch(
  "/:id/read",
  requireAuth,
  asyncHandler(async (req, res) => {
    const notification = await notificationService.markRead(req.params.id, req.auth!.userId);
    res.json(notification);
  })
);

notificationRouter.patch(
  "/me/preferences",
  requireAuth,
  asyncHandler(async (req, res) => {
    const { notificationsEnabled } = setPreferenceSchema.parse(req.body);
    const user = await notificationService.setNotificationPreference(req.auth!.userId, notificationsEnabled);
    res.json({ notificationsEnabled: user.notificationsEnabled });
  })
);
