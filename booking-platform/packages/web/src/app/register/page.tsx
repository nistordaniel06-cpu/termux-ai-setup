"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { api, storeAuth, Role } from "@/lib/api";
import { Screen, Title, Subtitle, Field, Input, Select, Button, ErrorText } from "@/components/ui";

export default function RegisterPage() {
  const router = useRouter();
  const [name, setName] = useState("");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [role, setRole] = useState<Role>("CLIENT");
  const [referralCode, setReferralCode] = useState("");
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);

  async function onSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError("");
    setLoading(true);
    try {
      const res = await api.register({
        name,
        email,
        password,
        role,
        referralCode: referralCode || undefined,
      });
      storeAuth({ user: res.user, tokens: { accessToken: res.accessToken, refreshToken: res.refreshToken } });
      router.push(role === "CLIENT" ? "/" : "/business/setup");
      router.refresh();
    } catch (err) {
      setError(err instanceof Error ? err.message : "A apărut o eroare");
    } finally {
      setLoading(false);
    }
  }

  return (
    <Screen>
      <Title>Creează cont</Title>
      <Subtitle>Alege ce fel de cont vrei: client sau profesionist.</Subtitle>

      <form onSubmit={onSubmit}>
        <ErrorText>{error}</ErrorText>

        <Field label="Tip cont">
          <Select value={role} onChange={(e) => setRole(e.target.value as Role)}>
            <option value="CLIENT">Client — vreau să mă programez</option>
            <option value="PROFESSIONAL">Frizer / profesionist independent</option>
            <option value="SALON_OWNER">Proprietar salon</option>
          </Select>
        </Field>

        <Field label="Nume">
          <Input required value={name} onChange={(e) => setName(e.target.value)} />
        </Field>
        <Field label="Email">
          <Input type="email" required value={email} onChange={(e) => setEmail(e.target.value)} />
        </Field>
        <Field label="Parolă">
          <Input
            type="password"
            required
            minLength={8}
            value={password}
            onChange={(e) => setPassword(e.target.value)}
          />
        </Field>
        <Field label="Cod referral (opțional)">
          <Input value={referralCode} onChange={(e) => setReferralCode(e.target.value)} placeholder="ex: dan-a1b2c3" />
        </Field>

        <Button type="submit" disabled={loading}>
          {loading ? "Se creează contul..." : "Creează cont"}
        </Button>
      </form>

      <p className="mt-4 text-center text-sm text-zinc-400">
        Ai deja cont?{" "}
        <a href="/login" className="font-medium text-white underline">
          Autentifică-te
        </a>
      </p>
    </Screen>
  );
}
