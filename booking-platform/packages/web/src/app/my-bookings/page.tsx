"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { useAuth } from "@/lib/useAuth";
import { api, Booking } from "@/lib/api";
import { Screen, Title, Subtitle, Card, Button, ErrorText, formatSlotDateTime } from "@/components/ui";

export default function MyBookingsPage() {
  const router = useRouter();
  const { auth, ready } = useAuth();
  const [bookings, setBookings] = useState<Booking[] | null>(null);
  const [error, setError] = useState("");
  const [reschedulingId, setReschedulingId] = useState<string | null>(null);
  const [newTime, setNewTime] = useState("");
  const [reviewingId, setReviewingId] = useState<string | null>(null);
  const [rating, setRating] = useState(5);
  const [comment, setComment] = useState("");

  useEffect(() => {
    if (!ready) return;
    if (!auth) {
      router.push("/login");
      return;
    }
    api.myBookings().then(setBookings).catch((err) => setError(err.message));
  }, [ready, auth, router]);

  async function onCancel(id: string) {
    try {
      const updated = await api.cancelBooking(id);
      setBookings((prev) => prev?.map((b) => (b.id === id ? updated : b)) ?? null);
    } catch (err) {
      setError(err instanceof Error ? err.message : "A apărut o eroare");
    }
  }

  async function onConfirmReschedule(id: string) {
    if (!newTime) return;
    try {
      const iso = new Date(newTime).toISOString();
      const updated = await api.rescheduleBooking(id, iso);
      setBookings((prev) => prev?.map((b) => (b.id === id ? updated : b)) ?? null);
      setReschedulingId(null);
      setNewTime("");
    } catch (err) {
      setError(err instanceof Error ? err.message : "A apărut o eroare");
    }
  }

  async function onSubmitReview(id: string) {
    try {
      await api.createReview(id, { rating, comment: comment || undefined });
      setBookings(
        (prev) => prev?.map((b) => (b.id === id ? { ...b, review: { id: "local", rating, comment } } : b)) ?? null
      );
      setReviewingId(null);
      setComment("");
      setRating(5);
    } catch (err) {
      setError(err instanceof Error ? err.message : "A apărut o eroare");
    }
  }

  if (!ready || bookings === null) {
    return (
      <Screen>
        <p className="text-sm text-gray-400">Se încarcă...</p>
      </Screen>
    );
  }

  return (
    <Screen>
      <Title>Programările mele</Title>
      <Subtitle>Anulează sau reprogramează direct de aici.</Subtitle>
      <ErrorText>{error}</ErrorText>

      {bookings.length === 0 && <p className="text-sm text-gray-400">Nu ai nicio programare încă.</p>}

      <div className="space-y-3">
        {bookings.map((b) => (
          <Card key={b.id}>
            <div className="flex items-start justify-between">
              <div>
                <p className="text-sm font-medium">{b.service?.name}</p>
                <p className="text-xs text-gray-500">{b.professional?.displayName}</p>
                <p className="mt-1 text-sm">{formatSlotDateTime(b.startTime)}</p>
                <p className="mt-1 text-xs uppercase tracking-wide text-gray-400">{b.status}</p>
              </div>
            </div>

            {b.status === "CONFIRMED" && new Date(b.startTime).getTime() > Date.now() && (
              <div className="mt-3 space-y-2">
                {reschedulingId === b.id ? (
                  <div className="flex items-center gap-2">
                    <input
                      type="datetime-local"
                      value={newTime}
                      onChange={(e) => setNewTime(e.target.value)}
                      className="flex-1 rounded-xl border border-gray-300 px-2 py-2 text-xs"
                    />
                    <Button className="w-auto" onClick={() => onConfirmReschedule(b.id)}>
                      OK
                    </Button>
                  </div>
                ) : (
                  <div className="grid grid-cols-2 gap-2">
                    <Button variant="secondary" onClick={() => setReschedulingId(b.id)}>
                      Reprogramează
                    </Button>
                    <Button variant="secondary" onClick={() => onCancel(b.id)}>
                      Anulează
                    </Button>
                  </div>
                )}
              </div>
            )}

            {b.status === "CONFIRMED" && new Date(b.startTime).getTime() <= Date.now() && (
              <div className="mt-3">
                {b.review ? (
                  <p className="text-xs text-gray-500">Recenzia ta: {"★".repeat(b.review.rating)}</p>
                ) : reviewingId === b.id ? (
                  <div className="space-y-2">
                    <div className="flex gap-1">
                      {[1, 2, 3, 4, 5].map((n) => (
                        <button
                          key={n}
                          onClick={() => setRating(n)}
                          className={`text-lg ${n <= rating ? "text-yellow-500" : "text-gray-300"}`}
                        >
                          ★
                        </button>
                      ))}
                    </div>
                    <input
                      value={comment}
                      onChange={(e) => setComment(e.target.value)}
                      placeholder="Un comentariu (opțional)"
                      className="w-full rounded-xl border border-gray-300 px-3 py-2 text-xs"
                    />
                    <Button onClick={() => onSubmitReview(b.id)}>Trimite recenzia</Button>
                  </div>
                ) : (
                  <Button variant="secondary" onClick={() => setReviewingId(b.id)}>
                    Lasă o recenzie
                  </Button>
                )}
              </div>
            )}
          </Card>
        ))}
      </div>
    </Screen>
  );
}
