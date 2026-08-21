"use client";

import { useEffect, useState } from "react";
import { api, MarketplaceResult } from "@/lib/api";
import { Screen, Title, Subtitle, Card, Field, Input, Button, ErrorText, formatPrice, formatRating } from "@/components/ui";

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
      <Title>Descoperă saloane</Title>
      <Subtitle>Găsește un frizer bun lângă tine, disponibil azi.</Subtitle>

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
          <input
            type="date"
            value={date}
            onChange={(e) => setDate(e.target.value)}
            className="w-full rounded-xl border border-gray-300 px-3 py-2.5 text-sm outline-none focus:border-gray-900"
          />
        </Field>
        <div className="flex gap-2">
          <Button variant="secondary" onClick={useMyLocation} className="flex-1">
            {coords ? "Lângă tine ✓" : "Lângă tine"}
          </Button>
          <Button onClick={runSearch} disabled={loading} className="flex-1">
            {loading ? "Caut..." : "Caută"}
          </Button>
        </div>
        {geoError && <p className="text-xs text-red-600">{geoError}</p>}
      </Card>

      <ErrorText>{error}</ErrorText>

      {results && results.length === 0 && (
        <p className="text-sm text-gray-400">Niciun salon nu se potrivește. Încearcă alte filtre.</p>
      )}

      <div className="space-y-3">
        {results?.map((r) => (
          <a key={r.id} href={`/b/${r.slug}`}>
            <Card>
              <div className="flex items-start justify-between">
                <div>
                  <p className="text-sm font-semibold">{r.name}</p>
                  <p className="text-xs text-gray-500">
                    {r.city}
                    {r.distanceKm !== null ? ` · ${r.distanceKm.toFixed(1)} km` : ""}
                  </p>
                  <p className="mt-1 text-xs text-gray-500">{formatRating(r.avgRating, r.reviewCount)}</p>
                </div>
                <div className="text-right">
                  {r.hasAvailabilityToday && (
                    <span className="mb-1 inline-block rounded-full bg-green-100 px-2 py-0.5 text-[10px] font-medium text-green-700">
                      Disponibil azi
                    </span>
                  )}
                  {r.fromPriceCents !== null && (
                    <p className="text-xs text-gray-500">de la {formatPrice(r.fromPriceCents)}</p>
                  )}
                </div>
              </div>
            </Card>
          </a>
        ))}
      </div>
    </Screen>
  );
}
