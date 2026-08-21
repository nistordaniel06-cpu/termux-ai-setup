"use client";

import { useEffect, useState } from "react";
import { useParams } from "next/navigation";
import { useAuth } from "@/lib/useAuth";
import { api, Business, Professional, Service } from "@/lib/api";
import {
  Screen,
  Title,
  Subtitle,
  Card,
  Field,
  Select,
  Button,
  ErrorText,
  SuccessText,
  formatPrice,
  formatSlotTime,
} from "@/components/ui";

function tomorrowDateString() {
  const d = new Date();
  d.setDate(d.getDate() + 1);
  return d.toISOString().slice(0, 10);
}

export default function PublicBusinessPage() {
  const { slug } = useParams<{ slug: string }>();
  const { auth } = useAuth();

  const [business, setBusiness] = useState<Business | null | undefined>(undefined);
  const [services, setServices] = useState<Service[]>([]);
  const [professionals, setProfessionals] = useState<Professional[]>([]);

  const [serviceId, setServiceId] = useState("");
  const [professionalId, setProfessionalId] = useState("");
  const [date, setDate] = useState(tomorrowDateString());

  const [slots, setSlots] = useState<string[]>([]);
  const [loadingSlots, setLoadingSlots] = useState(false);
  const [error, setError] = useState("");
  const [confirmed, setConfirmed] = useState<string | null>(null);

  useEffect(() => {
    api
      .getBusiness(slug)
      .then(async (b) => {
        setBusiness(b);
        const [svc, pros] = await Promise.all([api.listServices(b.id), api.listProfessionals(b.id)]);
        setServices(svc);
        setProfessionals(pros);
        if (svc[0]) setServiceId(svc[0].id);
        if (pros[0]) setProfessionalId(pros[0].id);
      })
      .catch(() => setBusiness(null));
  }, [slug]);

  useEffect(() => {
    if (!serviceId || !professionalId || !date) return;
    setLoadingSlots(true);
    setError("");
    api
      .getAvailability(professionalId, date, serviceId)
      .then((res) => setSlots(res.slots))
      .catch((err) => setError(err instanceof Error ? err.message : "A apărut o eroare"))
      .finally(() => setLoadingSlots(false));
  }, [serviceId, professionalId, date]);

  async function bookSlot(slot: string) {
    if (!auth) {
      setError("Trebuie să te autentifici pentru a confirma programarea.");
      return;
    }
    setError("");
    try {
      await api.createBooking({ professionalId, serviceId, startTime: slot });
      setConfirmed(slot);
      setSlots(slots.filter((s) => s !== slot));
    } catch (err) {
      setError(err instanceof Error ? err.message : "A apărut o eroare");
    }
  }

  if (business === undefined) {
    return (
      <Screen>
        <p className="text-sm text-gray-400">Se încarcă...</p>
      </Screen>
    );
  }

  if (business === null) {
    return (
      <Screen>
        <Title>Nu am găsit acest salon</Title>
        <Subtitle>Verifică link-ul și încearcă din nou.</Subtitle>
      </Screen>
    );
  }

  return (
    <Screen>
      <Title>{business.name}</Title>
      <Subtitle>
        {business.city}
        {business.address ? ` · ${business.address}` : ""}
      </Subtitle>

      <ErrorText>{error}</ErrorText>
      {confirmed && <SuccessText>Programare confirmată pentru {formatSlotTime(confirmed)}.</SuccessText>}

      <Card className="mb-4 space-y-3">
        <Field label="Serviciu">
          <Select value={serviceId} onChange={(e) => setServiceId(e.target.value)}>
            {services.map((s) => (
              <option key={s.id} value={s.id}>
                {s.name} — {s.durationMinutes} min, {formatPrice(s.priceCents)}
              </option>
            ))}
          </Select>
        </Field>

        {professionals.length > 1 && (
          <Field label="Profesionist">
            <Select value={professionalId} onChange={(e) => setProfessionalId(e.target.value)}>
              {professionals.map((p) => (
                <option key={p.id} value={p.id}>
                  {p.displayName}
                </option>
              ))}
            </Select>
          </Field>
        )}

        <Field label="Dată">
          <input
            type="date"
            min={tomorrowDateString()}
            value={date}
            onChange={(e) => setDate(e.target.value)}
            className="w-full rounded-xl border border-gray-300 px-3 py-2.5 text-sm outline-none focus:border-gray-900"
          />
        </Field>
      </Card>

      <h2 className="mb-2 text-sm font-semibold text-gray-700">Ore disponibile</h2>
      {loadingSlots ? (
        <p className="text-xs text-gray-400">Se caută ore libere...</p>
      ) : slots.length === 0 ? (
        <p className="text-xs text-gray-400">Nicio oră liberă în această zi.</p>
      ) : (
        <div className="grid grid-cols-3 gap-2">
          {slots.map((slot) => (
            <Button key={slot} variant="secondary" onClick={() => bookSlot(slot)}>
              {formatSlotTime(slot)}
            </Button>
          ))}
        </div>
      )}

      {!auth && (
        <p className="mt-4 text-center text-xs text-gray-400">
          <a href="/login" className="underline">
            Autentifică-te
          </a>{" "}
          pentru a confirma o programare.
        </p>
      )}
    </Screen>
  );
}
