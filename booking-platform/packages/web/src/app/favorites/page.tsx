"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { useAuth } from "@/lib/useAuth";
import { api, Favorite } from "@/lib/api";
import { Screen, Title, Subtitle, Card, Avatar, LinkButton, ErrorText } from "@/components/ui";

export default function FavoritesPage() {
  const { auth, ready } = useAuth();
  const [favorites, setFavorites] = useState<Favorite[] | null>(null);
  const [error, setError] = useState("");

  useEffect(() => {
    if (!ready || !auth) return;
    api
      .myFavorites()
      .then(setFavorites)
      .catch((err) => setError(err instanceof Error ? err.message : "A apărut o eroare"));
  }, [ready, auth]);

  if (!ready) return null;

  if (!auth) {
    return (
      <Screen>
        <Title>Favorite</Title>
        <Subtitle>Autentifică-te pentru a-ți salva saloanele preferate.</Subtitle>
        <LinkButton href="/login">Autentificare</LinkButton>
      </Screen>
    );
  }

  return (
    <Screen>
      <Title>Favorite</Title>
      <Subtitle>Saloanele pe care le-ai salvat.</Subtitle>

      <ErrorText>{error}</ErrorText>

      {favorites && favorites.length === 0 && (
        <p className="text-sm text-zinc-500">Nu ai salvat niciun salon încă. Apasă pe ♡ pe pagina unui salon.</p>
      )}

      <div className="space-y-3">
        {favorites?.map((f) => (
          <Link key={f.id} href={`/b/${f.business.slug}`}>
            <Card className="flex items-center gap-3">
              <Avatar name={f.business.name} size={48} />
              <div>
                <p className="text-sm font-semibold text-white">{f.business.name}</p>
                <p className="text-xs text-zinc-400">{f.business.city}</p>
              </div>
            </Card>
          </Link>
        ))}
      </div>
    </Screen>
  );
}
