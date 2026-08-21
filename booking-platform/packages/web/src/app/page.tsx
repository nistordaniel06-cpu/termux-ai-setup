"use client";

import Link from "next/link";
import { useAuth } from "@/lib/useAuth";
import { clearAuth } from "@/lib/api";
import { Screen, Title, Subtitle, Card, LinkButton, Button } from "@/components/ui";

export default function HomePage() {
  const { auth, ready, setAuth } = useAuth();

  return (
    <Screen>
      <Title>Booking Platform</Title>
      <Subtitle>Găsește un frizer bun și programează-te în câteva secunde.</Subtitle>

      {!ready ? null : !auth ? (
        <div className="space-y-3">
          <LinkButton href="/discover">Descoperă saloane</LinkButton>
          <LinkButton href="/login">Autentificare</LinkButton>
          <LinkButton href="/register">Creează cont</LinkButton>
        </div>
      ) : (
        <div className="space-y-3">
          <Card>
            <p className="text-sm text-gray-500">Salut,</p>
            <p className="text-lg font-medium">{auth.user.name}</p>
            <p className="mt-1 text-xs text-gray-400">Cod referral: {auth.user.referralCode}</p>
          </Card>

          {auth.user.role === "CLIENT" ? (
            <>
              <LinkButton href="/discover">Descoperă saloane</LinkButton>
              <LinkButton href="/my-bookings">Programările mele</LinkButton>
            </>
          ) : (
            <>
              <LinkButton href="/business/setup">Business-ul meu</LinkButton>
              <LinkButton href="/dashboard">Dashboard</LinkButton>
            </>
          )}

          <Button
            variant="secondary"
            onClick={() => {
              clearAuth();
              setAuth(null);
            }}
          >
            Deconectare
          </Button>
        </div>
      )}

      <p className="mt-8 text-center text-xs text-gray-400">
        Ai un link de la un frizer? Deschide-l direct — ex: <code>/b/numele-salonului</code>
      </p>
    </Screen>
  );
}
