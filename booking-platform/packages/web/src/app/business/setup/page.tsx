"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { useAuth } from "@/lib/useAuth";
import { api, Business, Professional, Service } from "@/lib/api";
import {
  Screen,
  Title,
  Subtitle,
  Card,
  Field,
  Input,
  Button,
  ErrorText,
  SuccessText,
  formatPrice,
} from "@/components/ui";

const WEEKDAYS = ["Duminica", "Luni", "Marti", "Miercuri", "Joi", "Vineri", "Sambata"];

export default function BusinessSetupPage() {
  const router = useRouter();
  const { auth, ready } = useAuth();
  const [business, setBusiness] = useState<Business | null | undefined>(undefined);
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
      .then(setBusiness)
      .catch(() => setBusiness(null));
  }, [ready, auth, router]);

  if (!ready || business === undefined) {
    return (
      <Screen>
        <p className="text-sm text-gray-400">Se încarcă...</p>
      </Screen>
    );
  }

  if (business === null) {
    return <CreateBusinessForm onCreated={setBusiness} />;
  }

  return <BusinessDashboard business={business} error={error} setError={setError} />;
}

function CreateBusinessForm({ onCreated }: { onCreated: (b: Business) => void }) {
  const [name, setName] = useState("");
  const [city, setCity] = useState("");
  const [address, setAddress] = useState("");
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);

  async function onSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError("");
    setLoading(true);
    try {
      const business = await api.createBusiness({ name, city, address });
      onCreated(business);
    } catch (err) {
      setError(err instanceof Error ? err.message : "A apărut o eroare");
    } finally {
      setLoading(false);
    }
  }

  return (
    <Screen>
      <Title>Creează-ți business-ul</Title>
      <Subtitle>Numele apare clienților și devine link-ul tău public de programări.</Subtitle>
      <form onSubmit={onSubmit}>
        <ErrorText>{error}</ErrorText>
        <Field label="Nume salon / brand">
          <Input required value={name} onChange={(e) => setName(e.target.value)} />
        </Field>
        <Field label="Oraș">
          <Input value={city} onChange={(e) => setCity(e.target.value)} />
        </Field>
        <Field label="Adresă">
          <Input value={address} onChange={(e) => setAddress(e.target.value)} />
        </Field>
        <Button type="submit" disabled={loading}>
          {loading ? "Se creează..." : "Creează business"}
        </Button>
      </form>
    </Screen>
  );
}

function BusinessDashboard({
  business,
  error,
  setError,
}: {
  business: Business;
  error: string;
  setError: (v: string) => void;
}) {
  const [services, setServices] = useState<Service[]>([]);
  const [professionals, setProfessionals] = useState<Professional[]>([]);
  const publicUrl = typeof window !== "undefined" ? `${window.location.origin}/b/${business.slug}` : "";

  useEffect(() => {
    api.listServices(business.id).then(setServices).catch(() => {});
    api.listProfessionals(business.id).then(setProfessionals).catch(() => {});
  }, [business.id]);

  return (
    <Screen>
      <Title>{business.name}</Title>
      <Subtitle>Link public de programări</Subtitle>
      <Card className="mb-4">
        <a href={`/b/${business.slug}`} className="break-all text-sm font-medium text-gray-900 underline">
          {publicUrl}
        </a>
      </Card>

      <ErrorText>{error}</ErrorText>

      <ServicesSection businessId={business.id} services={services} setServices={setServices} setError={setError} />

      {professionals.map((pro) => (
        <ScheduleSection key={pro.id} professional={pro} setError={setError} />
      ))}

      <LoyaltySection business={business} setError={setError} />
    </Screen>
  );
}

function LoyaltySection({ business, setError }: { business: Business; setError: (v: string) => void }) {
  const [visitsRequired, setVisitsRequired] = useState(business.loyaltyVisitsRequired ?? 4);
  const [enabled, setEnabled] = useState(business.loyaltyVisitsRequired !== null);
  const [loading, setLoading] = useState(false);
  const [saved, setSaved] = useState(false);

  async function onSave() {
    setLoading(true);
    setSaved(false);
    try {
      await api.setLoyaltyConfig(business.id, { visitsRequired: enabled ? visitsRequired : null });
      setSaved(true);
    } catch (err) {
      setError(err instanceof Error ? err.message : "A apărut o eroare");
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="mb-6">
      <h2 className="mb-2 text-sm font-semibold text-gray-700">Program de fidelitate</h2>
      <Card>
        <label className="mb-3 flex items-center gap-2 text-sm">
          <input type="checkbox" checked={enabled} onChange={(e) => setEnabled(e.target.checked)} />
          Activează recompensa la fiecare N vizite
        </label>
        {enabled && (
          <Field label="Număr de vizite pentru recompensă">
            <Input
              type="number"
              min={2}
              max={100}
              value={visitsRequired}
              onChange={(e) => setVisitsRequired(Number(e.target.value))}
            />
          </Field>
        )}
        <SuccessText>{saved ? "Program de fidelitate salvat." : ""}</SuccessText>
        <Button onClick={onSave} disabled={loading}>
          {loading ? "Se salvează..." : "Salvează"}
        </Button>
      </Card>
    </div>
  );
}

function ServicesSection({
  businessId,
  services,
  setServices,
  setError,
}: {
  businessId: string;
  services: Service[];
  setServices: (s: Service[]) => void;
  setError: (v: string) => void;
}) {
  const [name, setName] = useState("");
  const [duration, setDuration] = useState(30);
  const [price, setPrice] = useState(50);
  const [loading, setLoading] = useState(false);

  async function onSubmit(e: React.FormEvent) {
    e.preventDefault();
    setLoading(true);
    try {
      const service = await api.addService(businessId, {
        name,
        durationMinutes: duration,
        priceCents: Math.round(price * 100),
      });
      setServices([...services, service]);
      setName("");
    } catch (err) {
      setError(err instanceof Error ? err.message : "A apărut o eroare");
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="mb-6">
      <h2 className="mb-2 text-sm font-semibold text-gray-700">Servicii</h2>
      <div className="mb-3 space-y-2">
        {services.map((s) => (
          <Card key={s.id}>
            <div className="flex items-center justify-between">
              <span className="text-sm font-medium">{s.name}</span>
              <span className="text-sm text-gray-500">
                {s.durationMinutes} min · {formatPrice(s.priceCents)}
              </span>
            </div>
          </Card>
        ))}
        {services.length === 0 && <p className="text-xs text-gray-400">Niciun serviciu adăugat încă.</p>}
      </div>

      <Card>
        <form onSubmit={onSubmit} className="space-y-2">
          <Field label="Nume serviciu">
            <Input required value={name} onChange={(e) => setName(e.target.value)} placeholder="Tuns barbati" />
          </Field>
          <div className="grid grid-cols-2 gap-2">
            <Field label="Durată (min)">
              <Input
                type="number"
                min={5}
                required
                value={duration}
                onChange={(e) => setDuration(Number(e.target.value))}
              />
            </Field>
            <Field label="Preț (lei)">
              <Input
                type="number"
                min={0}
                required
                value={price}
                onChange={(e) => setPrice(Number(e.target.value))}
              />
            </Field>
          </div>
          <Button type="submit" disabled={loading}>
            {loading ? "Se adaugă..." : "Adaugă serviciu"}
          </Button>
        </form>
      </Card>
    </div>
  );
}

function ScheduleSection({ professional, setError }: { professional: Professional; setError: (v: string) => void }) {
  const [hours, setHours] = useState<Record<number, { enabled: boolean; startTime: string; endTime: string }>>(
    Object.fromEntries(
      Array.from({ length: 7 }, (_, day) => [day, { enabled: false, startTime: "09:00", endTime: "18:00" }])
    )
  );
  const [loading, setLoading] = useState(false);
  const [saved, setSaved] = useState(false);

  useEffect(() => {
    api
      .getSchedule(professional.id)
      .then((entries) => {
        setHours((prev) => {
          const next = { ...prev };
          for (const entry of entries) {
            next[entry.dayOfWeek] = { enabled: true, startTime: entry.startTime, endTime: entry.endTime };
          }
          return next;
        });
      })
      .catch(() => {});
  }, [professional.id]);

  async function onSave() {
    setLoading(true);
    setSaved(false);
    try {
      for (const [day, value] of Object.entries(hours)) {
        if (!value.enabled) continue;
        await api.setSchedule(professional.id, {
          dayOfWeek: Number(day),
          startTime: value.startTime,
          endTime: value.endTime,
        });
      }
      setSaved(true);
    } catch (err) {
      setError(err instanceof Error ? err.message : "A apărut o eroare");
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="mb-6">
      <h2 className="mb-2 text-sm font-semibold text-gray-700">Program — {professional.displayName}</h2>
      <Card>
        <div className="space-y-2">
          {WEEKDAYS.map((label, day) => (
            <div key={day} className="flex items-center gap-2">
              <input
                type="checkbox"
                checked={hours[day].enabled}
                onChange={(e) =>
                  setHours({ ...hours, [day]: { ...hours[day], enabled: e.target.checked } })
                }
              />
              <span className="w-20 text-xs text-gray-600">{label}</span>
              <input
                type="time"
                disabled={!hours[day].enabled}
                value={hours[day].startTime}
                onChange={(e) => setHours({ ...hours, [day]: { ...hours[day], startTime: e.target.value } })}
                className="rounded-lg border border-gray-300 px-2 py-1 text-xs disabled:opacity-40"
              />
              <span className="text-xs text-gray-400">-</span>
              <input
                type="time"
                disabled={!hours[day].enabled}
                value={hours[day].endTime}
                onChange={(e) => setHours({ ...hours, [day]: { ...hours[day], endTime: e.target.value } })}
                className="rounded-lg border border-gray-300 px-2 py-1 text-xs disabled:opacity-40"
              />
            </div>
          ))}
        </div>
        <div className="mt-3">
          <SuccessText>{saved ? "Program salvat." : ""}</SuccessText>
          <Button onClick={onSave} disabled={loading}>
            {loading ? "Se salvează..." : "Salvează programul"}
          </Button>
        </div>
      </Card>
    </div>
  );
}
