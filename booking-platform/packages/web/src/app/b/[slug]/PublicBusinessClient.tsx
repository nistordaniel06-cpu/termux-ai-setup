"use client";

import { useEffect, useState } from "react";
import { useAuth } from "@/lib/useAuth";
import { api, Business, Professional, Service, Review } from "@/lib/api";
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
  formatRating,
} from "@/components/ui";

function tomorrowDateString() {
  const d = new Date();
  d.setDate(d.getDate() + 1);
  return d.toISOString().slice(0, 10);
}

export default function PublicBusinessClient({ slug }: { slug: string }) {
  const { auth } = useAuth();

  const [business, setBusiness] = useState<Business | null | undefined>(undefined);
  const [services, setServices] = useState<Service[]>([]);
  const [professionals, setProfessionals] = useState<Professional[]>([]);
  const [reviews, setReviews] = useState<{ reviews: Review[]; avgRating: number | null; reviewCount: number }>({
    reviews: [],
    avgRating: null,
    reviewCount: 0,
  });
  const [isFavorite, setIsFavorite] = useState(false);

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
        const [svc, pros, reviewData] = await Promise.all([
          api.listServices(b.id),
          api.listProfessionals(b.id),
          api.getReviews(b.id),
        ]);
        setServices(svc);
        setProfessionals(pros);
        setReviews(reviewData);
        if (svc[0]) setServiceId(svc[0].id);
        if (pros[0]) setProfessionalId(pros[0].id);

        if (auth?.user.role === "CLIENT") {
          const favorites = await api.myFavorites().catch(() => []);
          setIsFavorite(favorites.some((f) => f.businessId === b.id));
        }
      })
      .catch(() => setBusiness(null));
    // eslint-disable-next-line react-hooks/exhaustive-deps
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

  async function toggleFavorite() {
    if (!business) return;
    try {
      if (isFavorite) {
        await api.removeFavorite(business.id);
      } else {
        await api.addFavorite(business.id);
      }
      setIsFavorite(!isFavorite);
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
      <div className="flex items-start justify-between">
        <div>
          <Title>{business.name}</Title>
          <Subtitle>
            {business.city}
            {business.address ? ` · ${business.address}` : ""}
          </Subtitle>
        </div>
        {auth?.user.role === "CLIENT" && (
          <button
            onClick={toggleFavorite}
            aria-label="Salvează la favorite"
            className={`rounded-full border px-3 py-2 text-sm ${
              isFavorite ? "border-red-300 bg-red-50 text-red-600" : "border-gray-300 text-gray-400"
            }`}
          >
            {isFavorite ? "♥" : "♡"}
          </button>
        )}
      </div>

      <p className="mb-4 text-sm text-gray-600">{formatRating(reviews.avgRating, reviews.reviewCount)}</p>

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

      {reviews.reviews.length > 0 && (
        <div className="mt-8">
          <h2 className="mb-2 text-sm font-semibold text-gray-700">Recenzii</h2>
          <div className="space-y-2">
            {reviews.reviews.map((r) => (
              <Card key={r.id}>
                <p className="text-sm font-medium">{"★".repeat(r.rating)}</p>
                {r.comment && <p className="mt-1 text-sm text-gray-600">{r.comment}</p>}
                <p className="mt-1 text-xs text-gray-400">{r.user.name}</p>
              </Card>
            ))}
          </div>
        </div>
      )}
    </Screen>
  );
}
