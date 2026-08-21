import { Prisma } from "@prisma/client";
import { prisma } from "../../lib/prisma";
import { forbidden, notFound } from "../../lib/errors";

type DbClient = typeof prisma | Prisma.TransactionClient;

/**
 * Transactional notifications (booking confirmed/cancelled/rescheduled,
 * rewards earned) always fire — they're account-relevant, not marketing.
 * Commercial ones (offers, promos) are gated by the user's own opt-out
 * (brief section 10: "notificările comerciale trebuie să respecte
 * consimțământul... nu trimite spam") — skipped at creation, not just at
 * delivery, so an opted-out user never gets a row at all.
 */
export async function createNotification(
  client: DbClient,
  userId: string,
  type: string,
  payload: Record<string, unknown>,
  options: { commercial: boolean } = { commercial: false }
) {
  if (options.commercial) {
    const user = await client.user.findUnique({ where: { id: userId }, select: { notificationsEnabled: true } });
    if (!user?.notificationsEnabled) return null;
  }

  return client.notification.create({ data: { userId, type, payload: payload as Prisma.InputJsonValue } });
}

export async function listMyNotifications(userId: string) {
  return prisma.notification.findMany({ where: { userId }, orderBy: { createdAt: "desc" }, take: 50 });
}

export async function markRead(notificationId: string, userId: string) {
  const notification = await prisma.notification.findUnique({ where: { id: notificationId } });
  if (!notification) throw notFound("Notification not found");
  if (notification.userId !== userId) throw forbidden("Not your notification");

  return prisma.notification.update({ where: { id: notificationId }, data: { readAt: new Date() } });
}

export async function setNotificationPreference(userId: string, notificationsEnabled: boolean) {
  return prisma.user.update({ where: { id: userId }, data: { notificationsEnabled } });
}
