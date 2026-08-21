const API_URL = process.env.NEXT_PUBLIC_API_URL || "http://localhost:4000/api/v1";

export type Role = "CLIENT" | "PROFESSIONAL" | "SALON_OWNER";

export type PublicUser = {
  id: string;
  email: string;
  name: string;
  phone: string | null;
  role: Role;
  referralCode: string;
  notificationsEnabled: boolean;
};

export type Tokens = { accessToken: string; refreshToken: string };
export type StoredAuth = { user: PublicUser; tokens: Tokens };

export type Business = {
  id: string;
  ownerId: string;
  name: string;
  slug: string;
  description: string | null;
  address: string | null;
  city: string | null;
  minDiscountPercent: number | null;
  maxDiscountPercent: number | null;
  loyaltyVisitsRequired: number | null;
  professionals?: Professional[];
};

export type Professional = {
  id: string;
  userId: string;
  businessId: string;
  displayName: string;
  active: boolean;
};

export type Service = {
  id: string;
  businessId: string;
  name: string;
  durationMinutes: number;
  priceCents: number;
  active: boolean;
};

export type Booking = {
  id: string;
  businessId: string;
  professionalId: string;
  serviceId: string;
  startTime: string;
  endTime: string;
  status: "PENDING" | "CONFIRMED" | "CANCELLED" | "COMPLETED" | "NO_SHOW";
  service?: Service;
  professional?: Professional;
  business?: Business;
  review?: { id: string; rating: number; comment: string | null } | null;
};

export type Dashboard = {
  occupancyPercent: number;
  emptySlotsToday: number;
  upcomingBookings: Booking[];
};

export type MarketplaceResult = {
  id: string;
  name: string;
  slug: string;
  city: string | null;
  address: string | null;
  distanceKm: number | null;
  avgRating: number | null;
  reviewCount: number;
  hasAvailabilityToday: boolean | null;
  fromPriceCents: number | null;
  activeOfferPercent: number | null;
  discoveryScore: number;
};

export type Offer = {
  id: string;
  businessId: string;
  discountPercent: number;
  startsAt: string;
  endsAt: string;
};

export type LoyaltyStatus =
  | { enabled: false }
  | { enabled: true; visitsRequired: number; currentVisits: number; visitsUntilNextReward: number };

export type Reward = {
  id: string;
  type: string;
  amount: number;
  businessId: string | null;
  redeemedAt: string | null;
  createdAt: string;
};

export type AppNotification = {
  id: string;
  type: string;
  payload: Record<string, unknown>;
  readAt: string | null;
  createdAt: string;
};

export type Review = {
  id: string;
  rating: number;
  comment: string | null;
  createdAt: string;
  user: { name: string };
};

export type Favorite = { id: string; businessId: string; business: Business };

const AUTH_KEY = "bp_auth";

export function getStoredAuth(): StoredAuth | null {
  if (typeof window === "undefined") return null;
  try {
    const raw = window.localStorage.getItem(AUTH_KEY);
    return raw ? (JSON.parse(raw) as StoredAuth) : null;
  } catch {
    return null;
  }
}

export function storeAuth(auth: StoredAuth) {
  window.localStorage.setItem(AUTH_KEY, JSON.stringify(auth));
}

export function clearAuth() {
  window.localStorage.removeItem(AUTH_KEY);
}

class ApiError extends Error {}

async function request<T>(path: string, options: RequestInit = {}): Promise<T> {
  const auth = getStoredAuth();
  const headers: Record<string, string> = { "Content-Type": "application/json" };
  if (options.headers) Object.assign(headers, options.headers as Record<string, string>);
  if (auth?.tokens?.accessToken) headers.Authorization = `Bearer ${auth.tokens.accessToken}`;

  const res = await fetch(`${API_URL}${path}`, { ...options, headers });
  const text = await res.text();
  const data = text ? JSON.parse(text) : null;

  if (!res.ok) {
    throw new ApiError(data?.error || `Request failed (${res.status})`);
  }
  return data as T;
}

export const api = {
  register: (body: { email: string; password: string; name: string; role: Role; referralCode?: string }) =>
    request<{ user: PublicUser; accessToken: string; refreshToken: string }>("/auth/register", {
      method: "POST",
      body: JSON.stringify(body),
    }),

  login: (body: { email: string; password: string }) =>
    request<{ user: PublicUser; accessToken: string; refreshToken: string }>("/auth/login", {
      method: "POST",
      body: JSON.stringify(body),
    }),

  getMyBusiness: () => request<Business>("/businesses/me"),

  createBusiness: (body: { name: string; city?: string; address?: string; description?: string }) =>
    request<Business>("/businesses", { method: "POST", body: JSON.stringify(body) }),

  getBusiness: (idOrSlug: string) => request<Business>(`/businesses/${idOrSlug}`),

  listServices: (businessId: string) => request<Service[]>(`/businesses/${businessId}/services`),

  addService: (businessId: string, body: { name: string; durationMinutes: number; priceCents: number }) =>
    request<Service>(`/businesses/${businessId}/services`, { method: "POST", body: JSON.stringify(body) }),

  listProfessionals: (businessId: string) => request<Professional[]>(`/businesses/${businessId}/professionals`),

  setSchedule: (professionalId: string, body: { dayOfWeek: number; startTime: string; endTime: string }) =>
    request(`/professionals/${professionalId}/schedule`, { method: "POST", body: JSON.stringify(body) }),

  getSchedule: (professionalId: string) =>
    request<{ dayOfWeek: number; startTime: string; endTime: string }[]>(`/professionals/${professionalId}/schedule`),

  getAvailability: (professionalId: string, date: string, serviceId: string) =>
    request<{ slots: string[] }>(`/professionals/${professionalId}/availability?date=${date}&serviceId=${serviceId}`),

  createBooking: (body: { professionalId: string; serviceId: string; startTime: string }) =>
    request<Booking>("/bookings", { method: "POST", body: JSON.stringify(body) }),

  myBookings: () => request<Booking[]>("/bookings/me"),

  cancelBooking: (id: string) => request<Booking>(`/bookings/${id}/cancel`, { method: "PATCH" }),

  rescheduleBooking: (id: string, startTime: string) =>
    request<Booking>(`/bookings/${id}/reschedule`, { method: "PATCH", body: JSON.stringify({ startTime }) }),

  getDashboard: (businessId: string) => request<Dashboard>(`/dashboard/${businessId}`),

  searchMarketplace: (params: {
    q?: string;
    city?: string;
    lat?: number;
    lng?: number;
    maxPriceCents?: number;
    date?: string;
  }) => {
    const qs = new URLSearchParams();
    for (const [key, value] of Object.entries(params)) {
      if (value !== undefined && value !== "") qs.set(key, String(value));
    }
    return request<{ results: MarketplaceResult[] }>(`/marketplace/businesses?${qs.toString()}`);
  },

  getReviews: (businessId: string) =>
    request<{ reviews: Review[]; avgRating: number | null; reviewCount: number }>(
      `/businesses/${businessId}/reviews`
    ),

  createReview: (bookingId: string, body: { rating: number; comment?: string }) =>
    request(`/bookings/${bookingId}/review`, { method: "POST", body: JSON.stringify(body) }),

  addFavorite: (businessId: string) => request<Favorite>(`/businesses/${businessId}/favorite`, { method: "POST" }),

  removeFavorite: (businessId: string) => request(`/businesses/${businessId}/favorite`, { method: "DELETE" }),

  myFavorites: () => request<Favorite[]>("/favorites/me"),

  setDiscountLimits: (businessId: string, body: { minDiscountPercent: number; maxDiscountPercent: number }) =>
    request<Business>(`/businesses/${businessId}/discount-limits`, { method: "PATCH", body: JSON.stringify(body) }),

  createOffer: (businessId: string, body: { discountPercent: number; startsAt: string; endsAt: string }) =>
    request<Offer>(`/businesses/${businessId}/offers`, { method: "POST", body: JSON.stringify(body) }),

  getOffers: (businessId: string) => request<Offer[]>(`/businesses/${businessId}/offers`),

  setLoyaltyConfig: (businessId: string, body: { visitsRequired: number | null }) =>
    request<Business>(`/businesses/${businessId}/loyalty-config`, { method: "PATCH", body: JSON.stringify(body) }),

  getLoyaltyStatus: (businessId: string) => request<LoyaltyStatus>(`/businesses/${businessId}/loyalty-status`),

  myRewards: () => request<Reward[]>("/rewards/me"),

  myNotifications: () => request<AppNotification[]>("/notifications/me"),

  markNotificationRead: (id: string) => request<AppNotification>(`/notifications/${id}/read`, { method: "PATCH" }),

  setNotificationPreference: (notificationsEnabled: boolean) =>
    request<{ notificationsEnabled: boolean }>("/notifications/me/preferences", {
      method: "PATCH",
      body: JSON.stringify({ notificationsEnabled }),
    }),

  getNextAvailability: (professionalId: string, serviceId: string, afterDate: string, withinDays = 30) =>
    request<{ date: string | null; slots: string[] }>(
      `/professionals/${professionalId}/next-availability?serviceId=${serviceId}&afterDate=${afterDate}&withinDays=${withinDays}`
    ),
};
