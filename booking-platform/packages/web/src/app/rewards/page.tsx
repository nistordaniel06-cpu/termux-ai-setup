"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { useAuth } from "@/lib/useAuth";
import { api, Reward } from "@/lib/api";
import { Screen, Title, Subtitle, Card, ErrorText } from "@/components/ui";

const LABELS: Record<string, string> = {
  loyalty_reward: "Recompensă de fidelitate",
  referral_referrer: "Bonus recomandare (ai adus un prieten)",
  referral_referred: "Bonus de bun venit (ai fost recomandat)",
};

export default function RewardsPage() {
  const router = useRouter();
  const { auth, ready } = useAuth();
  const [rewards, setRewards] = useState<Reward[] | null>(null);
  const [error, setError] = useState("");

  useEffect(() => {
    if (!ready) return;
    if (!auth) {
      router.push("/login");
      return;
    }
    api.myRewards().then(setRewards).catch((err) => setError(err.message));
  }, [ready, auth, router]);

  if (!ready || rewards === null) {
    return (
      <Screen>
        <p className="text-sm text-zinc-500">Se încarcă...</p>
      </Screen>
    );
  }

  const totalPoints = rewards.filter((r) => r.type.startsWith("referral")).reduce((sum, r) => sum + r.amount, 0);
  const loyaltyCount = rewards.filter((r) => r.type === "loyalty_reward").length;

  return (
    <Screen>
      <Title>Recompensele mele</Title>
      <Subtitle>Puncte din recomandări și recompense de fidelitate.</Subtitle>
      <ErrorText>{error}</ErrorText>

      <div className="mb-4 grid grid-cols-2 gap-3">
        <Card>
          <p className="text-xs text-zinc-400">Puncte recomandare</p>
          <p className="mt-1 text-2xl font-semibold">{totalPoints}</p>
        </Card>
        <Card>
          <p className="text-xs text-zinc-400">Recompense fidelitate</p>
          <p className="mt-1 text-2xl font-semibold">{loyaltyCount}</p>
        </Card>
      </div>

      {rewards.length === 0 && <p className="text-sm text-zinc-500">Nicio recompensă încă.</p>}

      <div className="space-y-2">
        {rewards.map((r) => (
          <Card key={r.id}>
            <p className="text-sm font-medium">{LABELS[r.type] ?? r.type}</p>
            <p className="text-xs text-zinc-400">
              {r.amount} {r.type.startsWith("referral") ? "puncte" : ""}
            </p>
            <p className="mt-1 text-xs text-zinc-500">{new Date(r.createdAt).toLocaleDateString("ro-RO")}</p>
          </Card>
        ))}
      </div>
    </Screen>
  );
}
