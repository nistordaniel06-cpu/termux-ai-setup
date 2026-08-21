"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { useAuth } from "@/lib/useAuth";
import { api, Business, Dashboard, Offer } from "@/lib/api";
import { Screen, Title, Subtitle, Card, Button, Input, Field, ErrorText, SuccessText, formatSlotDateTime } from "@/components/ui";

export default function DashboardPage() {
  const router = useRouter();
  const { auth, ready } = useAuth();
  const [business, setBusiness] = useState<Business | null>(null);
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
      .then(async (b) => {
        setBusiness(b);
        setDashboard(await api.getDashboard(b.id));
      })
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

      {dashboard && business && (
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

          <GrowthSection business={business} emptySlotsToday={dashboard.emptySlotsToday} />

          <h2 className="mb-2 mt-6 text-sm font-semibold text-gray-700">Programări următoare</h2>
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

function GrowthSection({ business, emptySlotsToday }: { business: Business; emptySlotsToday: number }) {
  const [minDiscount, setMinDiscount] = useState(String(business.minDiscountPercent ?? 10));
  const [maxDiscount, setMaxDiscount] = useState(String(business.maxDiscountPercent ?? 50));
  const [limitsConfigured, setLimitsConfigured] = useState(
    business.minDiscountPercent !== null && business.maxDiscountPercent !== null
  );
  const [customPercent, setCustomPercent] = useState("");
  const [offers, setOffers] = useState<Offer[]>([]);
  const [error, setError] = useState("");
  const [success, setSuccess] = useState("");
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    api.getOffers(business.id).then(setOffers).catch(() => {});
  }, [business.id]);

  async function saveLimits(e: React.FormEvent) {
    e.preventDefault();
    setError("");
    try {
      await api.setDiscountLimits(business.id, {
        minDiscountPercent: Number(minDiscount),
        maxDiscountPercent: Number(maxDiscount),
      });
      setLimitsConfigured(true);
    } catch (err) {
      setError(err instanceof Error ? err.message : "A apărut o eroare");
    }
  }

  async function boost(percent: number) {
    setError("");
    setSuccess("");
    setLoading(true);
    try {
      const now = new Date();
      const endOfDay = new Date(now);
      endOfDay.setUTCHours(23, 59, 59, 999);
      const offer = await api.createOffer(business.id, {
        discountPercent: percent,
        startsAt: now.toISOString(),
        endsAt: endOfDay.toISOString(),
      });
      setOffers([...offers, offer]);
      setSuccess(`Ofertă -${percent}% activă până la finalul zilei.`);
    } catch (err) {
      setError(err instanceof Error ? err.message : "A apărut o eroare");
    } finally {
      setLoading(false);
    }
  }

  const activeOffer = offers.find((o) => new Date(o.endsAt).getTime() > Date.now());

  return (
    <Card className="space-y-3">
      <h2 className="text-sm font-semibold text-gray-700">Boost sloturi libere</h2>
      <ErrorText>{error}</ErrorText>
      <SuccessText>{success}</SuccessText>

      {!limitsConfigured ? (
        <form onSubmit={saveLimits} className="space-y-2">
          <p className="text-xs text-gray-500">
            Setează limitele de discount înainte de a putea lansa oferte pentru orele libere.
          </p>
          <div className="grid grid-cols-2 gap-2">
            <Field label="Discount minim (%)">
              <Input type="number" min={1} max={90} value={minDiscount} onChange={(e) => setMinDiscount(e.target.value)} />
            </Field>
            <Field label="Discount maxim (%)">
              <Input type="number" min={1} max={90} value={maxDiscount} onChange={(e) => setMaxDiscount(e.target.value)} />
            </Field>
          </div>
          <Button type="submit">Salvează limitele</Button>
        </form>
      ) : activeOffer ? (
        <p className="text-sm text-gray-600">
          Ofertă activă: <strong>-{activeOffer.discountPercent}%</strong> până la {new Date(activeOffer.endsAt).toLocaleTimeString("ro-RO", { hour: "2-digit", minute: "2-digit" })}.
        </p>
      ) : (
        <>
          <p className="text-xs text-gray-500">
            {emptySlotsToday} ore libere azi. Propune un discount ca să le umpli.
          </p>
          <div className="grid grid-cols-4 gap-2">
            {[10, 20, 30].map((p) => (
              <Button key={p} variant="secondary" disabled={loading} onClick={() => boost(p)}>
                -{p}%
              </Button>
            ))}
            <Input
              placeholder="%"
              value={customPercent}
              onChange={(e) => setCustomPercent(e.target.value)}
              className="text-center"
            />
          </div>
          {customPercent && (
            <Button disabled={loading} onClick={() => boost(Number(customPercent))}>
              Aplică -{customPercent}%
            </Button>
          )}
        </>
      )}
    </Card>
  );
}
