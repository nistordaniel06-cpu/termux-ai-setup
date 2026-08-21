"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { useAuth } from "@/lib/useAuth";
import { api, Dashboard } from "@/lib/api";
import { Screen, Title, Subtitle, Card, ErrorText, formatSlotDateTime } from "@/components/ui";

export default function DashboardPage() {
  const router = useRouter();
  const { auth, ready } = useAuth();
  const [dashboard, setDashboard] = useState<Dashboard | null>(null);
  const [error, setError] = useState("");

  useEffect(() => {
    if (!ready) return;
    if (!auth) {
      router.push("/login");
      return;
    }
    if (auth.user.role === "CLIENT") {
      router.push("/");
      return;
    }
    api
      .getMyBusiness()
      .then((b) => api.getDashboard(b.id))
      .then(setDashboard)
      .catch((err) => setError(err instanceof Error ? err.message : "A apărut o eroare"));
  }, [ready, auth, router]);

  if (!ready || (!dashboard && !error)) {
    return (
      <Screen>
        <p className="text-sm text-gray-400">Se încarcă...</p>
      </Screen>
    );
  }

  return (
    <Screen>
      <Title>Dashboard</Title>
      <Subtitle>Ocuparea de azi și programările următoare.</Subtitle>
      <ErrorText>{error}</ErrorText>

      {dashboard && (
        <>
          <div className="mb-6 grid grid-cols-2 gap-3">
            <Card>
              <p className="text-xs text-gray-500">Grad de ocupare azi</p>
              <p className="mt-1 text-2xl font-semibold">{dashboard.occupancyPercent}%</p>
            </Card>
            <Card>
              <p className="text-xs text-gray-500">Ore libere azi</p>
              <p className="mt-1 text-2xl font-semibold">{dashboard.emptySlotsToday}</p>
            </Card>
          </div>

          <h2 className="mb-2 text-sm font-semibold text-gray-700">Programări următoare</h2>
          <div className="space-y-2">
            {dashboard.upcomingBookings.length === 0 && (
              <p className="text-xs text-gray-400">Nicio programare viitoare.</p>
            )}
            {dashboard.upcomingBookings.map((b) => (
              <Card key={b.id}>
                <p className="text-sm font-medium">{b.service?.name}</p>
                <p className="text-xs text-gray-500">{b.professional?.displayName}</p>
                <p className="mt-1 text-sm">{formatSlotDateTime(b.startTime)}</p>
              </Card>
            ))}
          </div>
        </>
      )}
    </Screen>
  );
}
