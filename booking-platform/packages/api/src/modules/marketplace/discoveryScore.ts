/**
 * Discovery Score: ranks marketplace results by more than "who pays more".
 * Each factor is normalized to [0, 1] independently so the weights below can
 * be retuned later without touching the factor logic (brief section 5).
 */
export const DISCOVERY_WEIGHTS = {
  availability: 18,
  distance: 18,
  rating: 18,
  priceMatch: 14,
  reliability: 14,
  popularity: 8,
  offer: 10,
};

export type DiscoverySignals = {
  hasAvailability: boolean | null; // null = not evaluated (no date requested)
  distanceKm: number | null; // null = no geo data to compare
  avgRating: number | null; // null = no reviews yet
  priceMatches: boolean | null; // null = no price filter requested
  reliability: number; // 1 - cancellationRate, in [0, 1]
  totalBookings: number;
  hasActiveOffer: boolean; // Phase 3: empty-slot discount currently running
};

function normalizeDistance(distanceKm: number | null): number {
  if (distanceKm === null) return 0.5; // neutral: no penalty for missing geo data
  return 1 / (1 + distanceKm / 5); // 0km -> 1, 5km -> 0.5, 20km -> ~0.2
}

function normalizeRating(avgRating: number | null): number {
  if (avgRating === null) return 0.5; // neutral: don't bury businesses with no reviews yet
  return avgRating / 5;
}

function normalizePopularity(totalBookings: number): number {
  return Math.min(1, totalBookings / 20);
}

export function computeDiscoveryScore(signals: DiscoverySignals): number {
  const factors: Record<keyof typeof DISCOVERY_WEIGHTS, number> = {
    availability: signals.hasAvailability === null ? 0.5 : signals.hasAvailability ? 1 : 0,
    distance: normalizeDistance(signals.distanceKm),
    rating: normalizeRating(signals.avgRating),
    priceMatch: signals.priceMatches === null ? 1 : signals.priceMatches ? 1 : 0,
    reliability: signals.reliability,
    popularity: normalizePopularity(signals.totalBookings),
    offer: signals.hasActiveOffer ? 1 : 0,
  };

  const totalWeight = Object.values(DISCOVERY_WEIGHTS).reduce((a, b) => a + b, 0);
  const weightedSum = (Object.keys(DISCOVERY_WEIGHTS) as (keyof typeof DISCOVERY_WEIGHTS)[]).reduce(
    (sum, key) => sum + DISCOVERY_WEIGHTS[key] * factors[key],
    0
  );

  return Math.round((weightedSum / totalWeight) * 100);
}

/** Great-circle distance in km (haversine). */
export function haversineKm(aLat: number, aLng: number, bLat: number, bLng: number): number {
  const R = 6371;
  const dLat = ((bLat - aLat) * Math.PI) / 180;
  const dLng = ((bLng - aLng) * Math.PI) / 180;
  const lat1 = (aLat * Math.PI) / 180;
  const lat2 = (bLat * Math.PI) / 180;

  const h = Math.sin(dLat / 2) ** 2 + Math.cos(lat1) * Math.cos(lat2) * Math.sin(dLng / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(h));
}
