"use client";

import { useEffect, useMemo, useState } from "react";
import Link from "next/link";
import { useAuth } from "@/lib/useAuth";
import { api, clearAuth, MarketplaceResult } from "@/lib/api";
import { Card, Avatar, Badge, Pill, ErrorText, formatPrice, formatRating } from "@/components/ui";

type Tab = "now" | "near" | "top";

function todayDateString() {
  return new Date().toISOString().slice(0, 10);
}

export default function HomePage() {
  const { auth, ready, setAuth } = useAuth();

  const [city, setCity] = useState("");
  const [q, setQ] = useState("");
  const [tab, setTab] = useState<Tab>("now");
  const [quickWindow, setQuickWindow] = useState<30 | 60 | 120>(30);
  const [coords, setCoords] = useState<{ lat: number; lng: number } | null>(null);
  const [geoError, setGeoError] = useState("");

  const [results, setResults] = useState<MarketplaceResult[] | null>(null);
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(true);

  async function runSearch() {
    setLoading(true);
    setError("");
    try {
      const res = await api.searchMarketplace({
        q: q || undefined,
        city: city || undefined,
        date: todayDateString(),
        lat: coords?.lat,
        lng: coords?.lng,
      });
      setResults(res.results);
    } catch (err) {
      setError(err instanceof Error ? err.message : "A apărut o eroare");
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    runSearch();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [coords]);

  function useMyLocation() {
    setGeoError("");
    setTab("near");
    if (!navigator.geolocation) {
      setGeoError("Locația nu este disponibilă în acest browser.");
      return;
    }
    navigator.geolocation.getCurrentPosition(
      (pos) => setCoords({ lat: pos.coords.latitude, lng: pos.coords.longitude }),
      () => setGeoError("Nu am putut obține locația ta.")
    );
  }

  const visible = useMemo(() => {
    if (!results) return null;
    const list = [...results];
    if (tab === "now") {
      return list.filter((r) => r.hasAvailabilityToday).sort((a, b) => b.discoveryScore - a.discoveryScore);
    }
    if (tab === "near") {
      return list.sort((a, b) => (a.distanceKm ?? Infinity) - (b.distanceKm ?? Infinity));
    }
    return list.sort((a, b) => (b.avgRating ?? -1) - (a.avgRating ?? -1) || b.reviewCount - a.reviewCount);
  }, [results, tab]);

  return (
    <main className="flex flex-1 flex-col px-5 py-6">
      <div className="mb-4 flex items-center justify-between">
        <button
          onClick={useMyLocation}
          className="flex items-center gap-1.5 text-sm font-medium text-white"
        >
          <span className="text-amber-400">📍</span>
          {coords ? "Lângă tine" : city || "Alege orașul"}
        </button>
        {ready && auth ? (
          <div className="flex items-center gap-3">
            <Link href="/notifications" aria-label="Notificări" className="text-xl">
              🔔
            </Link>
            <button
              onClick={() => {
                clearAuth();
                setAuth(null);
              }}
              className="text-xs text-zinc-500 underline"
            >
              Ieșire
            </button>
          </div>
        ) : (
          <Link href="/login" className="text-sm font-medium text-amber-400">
            Autentificare
          </Link>
        )}
      </div>

      <form
        onSubmit={(e) => {
          e.preventDefault();
          runSearch();
        }}
        className="mb-5 flex items-center gap-2 rounded-2xl border border-zinc-700 bg-zinc-900 px-4 py-3"
      >
        <span className="text-zinc-500">🔍</span>
        <input
          value={q}
          onChange={(e) => setQ(e.target.value)}
          placeholder="Caută frizer, salon sau serviciu..."
          className="w-full bg-transparent text-sm text-white outline-none placeholder:text-zinc-500"
        />
        <input
          value={city}
          onChange={(e) => setCity(e.target.value)}
          placeholder="oraș"
          className="w-20 shrink-0 border-l border-zinc-700 bg-transparent pl-2 text-sm text-white outline-none placeholder:text-zinc-500"
        />
      </form>

      <Card className="mb-5 border-amber-400/30 bg-gradient-to-br from-zinc-900 to-zinc-900">
        <p className="mb-0.5 text-sm font-semibold text-white">⚡ Ai nevoie de un tuns acum?</p>
        <p className="mb-3 text-xs text-zinc-400">Găsește frizeri disponibili în următoarele</p>
        <div className="flex gap-2">
          {([30, 60, 120] as const).map((min) => (
            <Pill
              key={min}
              active={tab === "now" && quickWindow === min}
              onClick={() => {
                setQuickWindow(min);
                setTab("now");
              }}
            >
              {min} min
            </Pill>
          ))}
        </div>
      </Card>

      <div className="mb-4 flex gap-2 overflow-x-auto">
        <Pill active={tab === "now"} onClick={() => setTab("now")}>
          Disponibil acum
        </Pill>
        <Pill active={tab === "near"} onClick={useMyLocation}>
          Lângă tine
        </Pill>
        <Pill active={tab === "top"} onClick={() => setTab("top")}>
          Cele mai apreciate
        </Pill>
      </div>

      {geoError && <p className="mb-3 text-xs text-red-400">{geoError}</p>}
      <ErrorText>{error}</ErrorText>

      {loading && <p className="text-sm text-zinc-500">Se caută frizeri...</p>}

      {!loading && visible && visible.length === 0 && (
        <p className="text-sm text-zinc-500">Niciun salon nu se potrivește acum. Încearcă alt filtru.</p>
      )}

      <div className="space-y-3">
        {visible?.map((r) => (
          <Link key={r.id} href={`/b/${r.slug}`}>
            <Card className="flex items-center gap-3">
              <Avatar name={r.name} size={52} />
              <div className="min-w-0 flex-1">
                <p className="truncate text-sm font-semibold text-white">{r.name}</p>
                <p className="text-xs text-zinc-400">{formatRating(r.avgRating, r.reviewCount)}</p>
                <p className="text-xs text-zinc-500">
                  {r.city}
                  {r.distanceKm !== null ? ` · ${r.distanceKm.toFixed(1)} km` : ""}
                </p>
              </div>
              <div className="flex shrink-0 flex-col items-end gap-1">
                {r.fromPriceCents !== null && (
                  <p className="text-xs text-zinc-400">de la {formatPrice(r.fromPriceCents)}</p>
                )}
                {r.activeOfferPercent !== null && <Badge tone="green">-{r.activeOfferPercent}%</Badge>}
                {r.hasAvailabilityToday && <Badge tone="gold">Disponibil azi</Badge>}
              </div>
            </Card>
          </Link>
        ))}
      </div>

      {ready && auth && (auth.user.role === "PROFESSIONAL" || auth.user.role === "SALON_OWNER") && (
        <Link href="/business/setup" className="mt-6 block">
          <Card className="text-center text-sm font-medium text-amber-400">Administrează-ți salonul →</Card>
        </Link>
      )}
    </main>
  );
}
