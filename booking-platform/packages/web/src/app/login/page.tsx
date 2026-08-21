"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { api, storeAuth } from "@/lib/api";
import { Screen, Title, Subtitle, Field, Input, Button, ErrorText } from "@/components/ui";

export default function LoginPage() {
  const router = useRouter();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);

  async function onSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError("");
    setLoading(true);
    try {
      const res = await api.login({ email, password });
      storeAuth({ user: res.user, tokens: { accessToken: res.accessToken, refreshToken: res.refreshToken } });
      router.push("/");
      router.refresh();
    } catch (err) {
      setError(err instanceof Error ? err.message : "A apărut o eroare");
    } finally {
      setLoading(false);
    }
  }

  return (
    <Screen>
      <Title>Autentificare</Title>
      <Subtitle>Intră în cont ca să te programezi sau să-ți administrezi salonul.</Subtitle>

      <form onSubmit={onSubmit}>
        <ErrorText>{error}</ErrorText>
        <Field label="Email">
          <Input type="email" required value={email} onChange={(e) => setEmail(e.target.value)} />
        </Field>
        <Field label="Parolă">
          <Input type="password" required value={password} onChange={(e) => setPassword(e.target.value)} />
        </Field>
        <Button type="submit" disabled={loading}>
          {loading ? "Se conectează..." : "Autentificare"}
        </Button>
      </form>

      <p className="mt-4 text-center text-sm text-gray-500">
        Nu ai cont?{" "}
        <a href="/register" className="font-medium text-gray-900 underline">
          Creează unul
        </a>
      </p>
    </Screen>
  );
}
