"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { api, MarketplaceResult } from "@/lib/api";
import { Screen, Title, Subtitle, Card, Avatar, Badge, Field, Input, Button, ErrorText, formatPrice, formatRating } from "@/components/ui";

function todayDateString() {
  return new Date().toISOString().slice(0, 10);
}

export default function DiscoverPage() {
  const [q, setQ] = useState("");
  const [city, setCity] = useState("");
  const [maxPrice, setMaxPrice] = useState("");
  const [date, setDate] = useState(todayDateString());
  const [coords, setCoords] = useState<{ lat: number; lng: number } | null>(null);
  const [geoError, setGeoError] = useState("");

  const [results, setResults] = useState<MarketplaceResult[] | null>(null);
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);

  async function runSearch() {
    setLoading(true);
    setError("");
    try {
      const res = await api.searchMarketplace({
        q: q || undefined,
        city: city || undefined,
        maxPriceCents: maxPrice ? Math.round(Number(maxPrice) * 100) : undefined,
        date,
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
    if (!navigator.geolocation) {
      setGeoError("Locația nu este disponibilă în acest browser.");
      return;
    }
    navigator.geolocation.getCurrentPosition(
      (pos) => setCoords({ lat: pos.coords.latitude, lng: pos.coords.longitude }),
      () => setGeoError("Nu am putut obține locația ta.")
    );
  }

  return (
    <Screen>
      <Title>Căutare avansată</Title>
      <Subtitle>Filtrează după preț, oraș și dată pentru a găsi exact ce cauți.</Subtitle>

      <Card className="mb-4 space-y-3">
        <Field label="Serviciu sau salon">
          <Input value={q} onChange={(e) => setQ(e.target.value)} placeholder="Tuns barbati" />
        </Field>
        <div className="grid grid-cols-2 gap-2">
          <Field label="Oraș">
            <Input value={city} onChange={(e) => setCity(e.target.value)} placeholder="Bucuresti" />
          </Field>
          <Field label="Preț maxim (lei)">
            <Input type="number" min={0} value={maxPrice} onChange={(e) => setMaxPrice(e.target.value)} />
          </Field>
        </div>
        <Field label="Dată">
          <Input type="date" value={date} onChange={(e) => setDate(e.target.value)} />
        </Field>
        <div className="flex gap-2">
          <Button variant="secondary" onClick={useMyLocation} className="flex-1">
            {coords ? "Lângă tine ✓" : "Lângă tine"}
          </Button>
          <Button onClick={runSearch} disabled={loading} className="flex-1">
            {loading ? "Caut..." : "Caută"}
          </Button>
        </div>
        {geoError && <p className="text-xs text-red-400">{geoError}</p>}
      </Card>

      <ErrorText>{error}</ErrorText>

      {results && results.length === 0 && (
        <p className="text-sm text-zinc-500">Niciun salon nu se potrivește. Încearcă alte filtre.</p>
      )}

      <div className="space-y-3">
        {results?.map((r) => (
          <Link key={r.id} href={`/b/${r.slug}`}>
            <Card className="flex items-center gap-3">
              <Avatar name={r.name} size={48} />
              <div className="min-w-0 flex-1">
                <p className="truncate text-sm font-semibold text-white">{r.name}</p>
                <p className="text-xs text-zinc-400">
                  {r.city}
                  {r.distanceKm !== null ? ` · ${r.distanceKm.toFixed(1)} km` : ""}
                </p>
                <p className="mt-1 text-xs text-zinc-400">{formatRating(r.avgRating, r.reviewCount)}</p>
              </div>
              <div className="flex shrink-0 flex-col items-end gap-1">
                {r.hasAvailabilityToday && <Badge tone="gold">Disponibil azi</Badge>}
                {r.fromPriceCents !== null && (
                  <p className="text-xs text-zinc-400">de la {formatPrice(r.fromPriceCents)}</p>
                )}
              </div>
            </Card>
          </Link>
        ))}
      </div>
    </Screen>
  );
}
