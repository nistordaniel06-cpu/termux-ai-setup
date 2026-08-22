"use client";

import { useEffect, useMemo, useState } from "react";
import Link from "next/link";
import { useSearchParams } from "next/navigation";
import { useAuth } from "@/lib/useAuth";
import { api, Business, Professional, Service, Review, Offer, LoyaltyStatus } from "@/lib/api";
import {
  Screen,
  Title,
  Card,
  Avatar,
  Badge,
  Pill,
  Select,
  Button,
  ErrorText,
  SuccessText,
  formatPrice,
  formatSlotTime,
  formatRating,
} from "@/components/ui";

function dateString(offsetDays: number) {
  const d = new Date();
  d.setDate(d.getDate() + offsetDays);
  return d.toISOString().slice(0, 10);
}

function dayLabel(offsetDays: number) {
  if (offsetDays === 0) return "Astăzi";
  if (offsetDays === 1) return "Mâine";
  const d = new Date();
  d.setDate(d.getDate() + offsetDays);
  return d.toLocaleDateString("ro-RO", { weekday: "short" });
}

function dayDate(offsetDays: number) {
  const d = new Date();
  d.setDate(d.getDate() + offsetDays);
  return d.toLocaleDateString("ro-RO", { day: "2-digit", month: "2-digit" });
}

export default function PublicBusinessClient({ slug }: { slug: string }) {
  const { auth } = useAuth();
  const searchParams = useSearchParams();

  const [business, setBusiness] = useState<Business | null | undefined>(undefined);
  const [services, setServices] = useState<Service[]>([]);
  const [professionals, setProfessionals] = useState<Professional[]>([]);
  const [reviews, setReviews] = useState<{ reviews: Review[]; avgRating: number | null; reviewCount: number }>({
    reviews: [],
    avgRating: null,
    reviewCount: 0,
  });
  const [isFavorite, setIsFavorite] = useState(false);
  const [offers, setOffers] = useState<Offer[]>([]);
  const [loyalty, setLoyalty] = useState<LoyaltyStatus | null>(null);

  const [serviceId, setServiceId] = useState("");
  const [professionalId, setProfessionalId] = useState("");
  const [date, setDate] = useState(searchParams.get("date") || dateString(0));
  const [customDate, setCustomDate] = useState(false);

  const [slots, setSlots] = useState<string[]>([]);
  const [selectedSlot, setSelectedSlot] = useState<string | null>(null);
  const [loadingSlots, setLoadingSlots] = useState(false);
  const [error, setError] = useState("");
  const [confirmed, setConfirmed] = useState<string | null>(null);

  const quickDays = useMemo(() => [0, 1, 2, 3], []);
  const selectedService = services.find((s) => s.id === serviceId);

  useEffect(() => {
    api
      .getBusiness(slug)
      .then(async (b) => {
        setBusiness(b);
        const [svc, pros, reviewData, offerList] = await Promise.all([
          api.listServices(b.id),
          api.listProfessionals(b.id),
          api.getReviews(b.id),
          api.getOffers(b.id),
        ]);
        setServices(svc);
        setProfessionals(pros);
        setReviews(reviewData);
        setOffers(offerList);

        const serviceFromQuery = searchParams.get("serviceId");
        const professionalFromQuery = searchParams.get("professionalId");
        setServiceId(serviceFromQuery && svc.some((s) => s.id === serviceFromQuery) ? serviceFromQuery : svc[0]?.id ?? "");
        setProfessionalId(
          professionalFromQuery && pros.some((p) => p.id === professionalFromQuery)
            ? professionalFromQuery
            : pros[0]?.id ?? ""
        );
      })
      .catch(() => setBusiness(null));
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [slug]);

  // Separate from the effect above: `auth` starts out null until useAuth's
  // own mount effect reads localStorage, so a client-only fetch gated on
  // `auth` has to depend on `auth` itself (not just run once on mount) or
  // it silently skips for an already-logged-in visitor on a fresh load.
  useEffect(() => {
    if (!business || auth?.user.role !== "CLIENT") return;
    api
      .myFavorites()
      .then((favorites) => setIsFavorite(favorites.some((f) => f.businessId === business.id)))
      .catch(() => {});
    api
      .getLoyaltyStatus(business.id)
      .then(setLoyalty)
      .catch(() => {});
  }, [business, auth]);

  useEffect(() => {
    if (!serviceId || !professionalId || !date) return;
    setLoadingSlots(true);
    setSelectedSlot(null);
    setError("");
    api
      .getAvailability(professionalId, date, serviceId)
      .then((res) => setSlots(res.slots))
      .catch((err) => setError(err instanceof Error ? err.message : "A apărut o eroare"))
      .finally(() => setLoadingSlots(false));
  }, [serviceId, professionalId, date]);

  async function confirmBooking() {
    if (!selectedSlot) return;
    if (!auth) {
      setError("Trebuie să te autentifici pentru a confirma programarea.");
      return;
    }
    setError("");
    try {
      await api.createBooking({ professionalId, serviceId, startTime: selectedSlot });
      setConfirmed(selectedSlot);
      setSlots(slots.filter((s) => s !== selectedSlot));
      setSelectedSlot(null);
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
        <p className="text-sm text-zinc-500">Se încarcă...</p>
      </Screen>
    );
  }

  if (business === null) {
    return (
      <Screen>
        <Title>Nu am găsit acest salon</Title>
        <p className="text-sm text-zinc-400">Verifică link-ul și încearcă din nou.</p>
      </Screen>
    );
  }

  const activeOffer = offers.find(
    (o) => new Date(o.startsAt).getTime() <= Date.now() && new Date(o.endsAt).getTime() > Date.now()
  );
  const mapsHref = `https://www.google.com/maps/search/?api=1&query=${encodeURIComponent(
    [business.address, business.city].filter(Boolean).join(", ") || business.name
  )}`;

  return (
    <div className="flex flex-1 flex-col pb-28">
      <div className="relative flex h-40 items-end justify-between bg-gradient-to-br from-zinc-800 to-zinc-950 px-4 py-3">
        <Link href="/" className="rounded-full bg-zinc-950/60 px-3 py-2 text-white" aria-label="Înapoi">
          ←
        </Link>
        {auth?.user.role === "CLIENT" && (
          <button
            onClick={toggleFavorite}
            aria-label="Salvează la favorite"
            className={`rounded-full px-3 py-2 text-lg ${isFavorite ? "bg-red-500/20 text-red-400" : "bg-zinc-950/60 text-white"}`}
          >
            {isFavorite ? "♥" : "♡"}
          </button>
        )}
      </div>

      <div className="-mt-8 px-5">
        <Avatar name={business.name} size={64} />
      </div>

      <Screen className="pt-3">
        <div className="mb-1 flex items-center gap-2">
          <h1 className="text-xl font-semibold text-white">{business.name}</h1>
          {activeOffer && <Badge tone="green">-{activeOffer.discountPercent}%</Badge>}
        </div>
        <p className="mb-1 text-sm text-zinc-400">{formatRating(reviews.avgRating, reviews.reviewCount)}</p>
        {services.length > 0 && (
          <p className="mb-2 text-xs text-zinc-500">{Array.from(new Set(services.map((s) => s.name))).slice(0, 3).join(" · ")}</p>
        )}
        {(business.address || business.city) && (
          <a href={mapsHref} target="_blank" rel="noreferrer" className="mb-4 inline-block text-xs font-medium text-amber-400">
            📍 Vezi adresa pe hartă
          </a>
        )}

        {loyalty?.enabled && (
          <Card className="mb-4 border-amber-400/30">
            <p className="text-xs text-amber-300">
              Mai ai <strong>{loyalty.visitsUntilNextReward}</strong> vizite până la o recompensă ({loyalty.currentVisits}/
              {loyalty.visitsRequired}).
            </p>
          </Card>
        )}

        <ErrorText>{error}</ErrorText>
        {confirmed && <SuccessText>Programare confirmată pentru {formatSlotTime(confirmed)}.</SuccessText>}

        <div className="mb-4 flex items-center gap-2 overflow-x-auto pb-1">
          {quickDays.map((offset) => (
            <Pill key={offset} active={!customDate && date === dateString(offset)} onClick={() => { setCustomDate(false); setDate(dateString(offset)); }}>
              <span className="block leading-tight">{dayLabel(offset)}</span>
              <span className="block text-[10px] font-normal opacity-80">{dayDate(offset)}</span>
            </Pill>
          ))}
          <label className="relative shrink-0 rounded-full bg-zinc-800 p-2.5 text-zinc-300">
            📅
            <input
              type="date"
              min={dateString(0)}
              value={customDate ? date : ""}
              onChange={(e) => {
                setCustomDate(true);
                setDate(e.target.value);
              }}
              className="absolute inset-0 h-full w-full cursor-pointer opacity-0"
            />
          </label>
        </div>

        {professionals.length > 1 && (
          <div className="mb-4">
            <Select value={professionalId} onChange={(e) => setProfessionalId(e.target.value)}>
              {professionals.map((p) => (
                <option key={p.id} value={p.id}>
                  {p.displayName}
                </option>
              ))}
            </Select>
          </div>
        )}

        <h2 className="mb-2 text-sm font-semibold text-zinc-200">Alege ora</h2>
        {loadingSlots ? (
          <p className="mb-4 text-xs text-zinc-500">Se caută ore libere...</p>
        ) : slots.length === 0 ? (
          <p className="mb-4 text-xs text-zinc-500">Nicio oră liberă în această zi.</p>
        ) : (
          <div className="mb-4 grid grid-cols-4 gap-2">
            {slots.map((slot) => (
              <button
                key={slot}
                onClick={() => setSelectedSlot(slot)}
                className={`rounded-xl px-2 py-2.5 text-sm font-medium transition ${
                  selectedSlot === slot ? "bg-amber-400 text-zinc-950" : "bg-zinc-800 text-white"
                }`}
              >
                {formatSlotTime(slot)}
              </button>
            ))}
          </div>
        )}

        <h2 className="mb-2 text-sm font-semibold text-zinc-200">Serviciu</h2>
        <div className="mb-6 space-y-2">
          {services.map((s) => (
            <button key={s.id} onClick={() => setServiceId(s.id)} className="block w-full text-left">
              <Card className={`flex items-center justify-between ${serviceId === s.id ? "border-amber-400" : ""}`}>
                <div>
                  <p className="text-sm font-medium text-white">{s.name}</p>
                  <p className="text-xs text-zinc-500">{s.durationMinutes} min</p>
                </div>
                <p className="text-sm font-semibold text-white">{formatPrice(s.priceCents)}</p>
              </Card>
            </button>
          ))}
        </div>

        {!auth && (
          <p className="mb-4 text-center text-xs text-zinc-500">
            <Link href="/login" className="underline">
              Autentifică-te
            </Link>{" "}
            pentru a confirma o programare.
          </p>
        )}

        {reviews.reviews.length > 0 && (
          <div>
            <h2 className="mb-2 text-sm font-semibold text-zinc-200">Recenzii</h2>
            <div className="space-y-2">
              {reviews.reviews.map((r) => (
                <Card key={r.id}>
                  <p className="text-sm font-medium text-amber-400">{"★".repeat(r.rating)}</p>
                  {r.comment && <p className="mt-1 text-sm text-zinc-300">{r.comment}</p>}
                  <p className="mt-1 text-xs text-zinc-500">{r.user.name}</p>
                </Card>
              ))}
            </div>
          </div>
        )}
      </Screen>

      {selectedSlot && (
        <div className="fixed bottom-16 left-1/2 z-30 w-full max-w-md -translate-x-1/2 px-5 md:max-w-2xl">
          <Button onClick={confirmBooking} className="shadow-lg shadow-black/40">
            Continuă ({formatSlotTime(selectedSlot)}) — {selectedService ? formatPrice(selectedService.priceCents) : ""}
          </Button>
        </div>
      )}
    </div>
  );
}
