"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { useAuth } from "@/lib/useAuth";
import { api, AppNotification, storeAuth } from "@/lib/api";
import { Screen, Title, Subtitle, Card, ErrorText } from "@/components/ui";

const LABELS: Record<string, (payload: Record<string, unknown>) => string> = {
  booking_confirmed: () => "Programare confirmată.",
  booking_cancelled: () => "O programare a fost anulată.",
  booking_rescheduled: () => "O programare a fost reprogramată.",
  offer_available: (p) => `${p.businessName ?? "Un salon favorit"} are o ofertă de -${p.discountPercent}% azi.`,
  loyalty_reward: (p) => `Ai câștigat o recompensă de fidelitate la ${p.businessName ?? "un salon"}!`,
  referral_reward: (p) => `Ai primit ${p.points} puncte din programul de recomandări.`,
};

function describe(n: AppNotification) {
  return LABELS[n.type]?.(n.payload) ?? n.type;
}

export default function NotificationsPage() {
  const router = useRouter();
  const { auth, ready, setAuth } = useAuth();
  const [notifications, setNotifications] = useState<AppNotification[] | null>(null);
  const [notificationsEnabled, setNotificationsEnabled] = useState(true);
  const [error, setError] = useState("");

  useEffect(() => {
    if (!ready) return;
    if (!auth) {
      router.push("/login");
      return;
    }
    setNotificationsEnabled(auth.user.notificationsEnabled);
    api.myNotifications().then(setNotifications).catch((err) => setError(err.message));
  }, [ready, auth, router]);

  async function onMarkRead(id: string) {
    try {
      const updated = await api.markNotificationRead(id);
      setNotifications((prev) => prev?.map((n) => (n.id === id ? updated : n)) ?? null);
    } catch (err) {
      setError(err instanceof Error ? err.message : "A apărut o eroare");
    }
  }

  async function onToggle(enabled: boolean) {
    setNotificationsEnabled(enabled);
    try {
      await api.setNotificationPreference(enabled);
      if (auth) {
        const updatedAuth = { ...auth, user: { ...auth.user, notificationsEnabled: enabled } };
        storeAuth(updatedAuth);
        setAuth(updatedAuth);
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : "A apărut o eroare");
    }
  }

  if (!ready || notifications === null) {
    return (
      <Screen>
        <p className="text-sm text-gray-400">Se încarcă...</p>
      </Screen>
    );
  }

  return (
    <Screen>
      <Title>Notificări</Title>
      <Subtitle>Confirmări, anulări și oferte relevante.</Subtitle>
      <ErrorText>{error}</ErrorText>

      <Card className="mb-4">
        <label className="flex items-center justify-between text-sm">
          <span>Primește notificări despre oferte</span>
          <input
            type="checkbox"
            checked={notificationsEnabled}
            onChange={(e) => onToggle(e.target.checked)}
          />
        </label>
      </Card>

      {notifications.length === 0 && <p className="text-sm text-gray-400">Nicio notificare încă.</p>}

      <div className="space-y-2">
        {notifications.map((n) => (
          <Card key={n.id} className={n.readAt ? "opacity-60" : ""}>
            <div className="flex items-start justify-between gap-2">
              <p className="text-sm">{describe(n)}</p>
              {!n.readAt && (
                <button onClick={() => onMarkRead(n.id)} className="shrink-0 text-xs text-gray-400 underline">
                  marchează citit
                </button>
              )}
            </div>
            <p className="mt-1 text-xs text-gray-400">{new Date(n.createdAt).toLocaleString("ro-RO")}</p>
          </Card>
        ))}
      </div>
    </Screen>
  );
}
