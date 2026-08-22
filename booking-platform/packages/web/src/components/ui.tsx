"use client";

import Link from "next/link";
import { ButtonHTMLAttributes, InputHTMLAttributes, ReactNode, SelectHTMLAttributes } from "react";

export function Screen({ children, className = "" }: { children: ReactNode; className?: string }) {
  return <main className={`flex flex-1 flex-col px-5 py-6 ${className}`}>{children}</main>;
}

export function Title({ children }: { children: ReactNode }) {
  return <h1 className="mb-1 text-2xl font-semibold tracking-tight text-white">{children}</h1>;
}

export function Subtitle({ children }: { children: ReactNode }) {
  return <p className="mb-6 text-sm text-zinc-400">{children}</p>;
}

export function Card({ children, className = "" }: { children: ReactNode; className?: string }) {
  return (
    <div className={`rounded-2xl border border-zinc-800 bg-zinc-900 p-4 shadow-sm shadow-black/20 ${className}`}>
      {children}
    </div>
  );
}

export function Button({
  variant = "primary",
  className = "",
  ...props
}: ButtonHTMLAttributes<HTMLButtonElement> & { variant?: "primary" | "secondary" | "ghost" }) {
  const base = "w-full rounded-xl px-4 py-3 text-sm font-semibold transition disabled:opacity-50";
  const styles =
    variant === "primary"
      ? "bg-amber-400 text-zinc-950 active:bg-amber-300"
      : variant === "secondary"
        ? "bg-zinc-800 text-white active:bg-zinc-700"
        : "bg-transparent text-zinc-300 border border-zinc-700 active:bg-zinc-900";
  return <button className={`${base} ${styles} ${className}`} {...props} />;
}

export function LinkButton({ href, children }: { href: string; children: ReactNode }) {
  return (
    <Link
      href={href}
      className="block w-full rounded-xl bg-amber-400 px-4 py-3 text-center text-sm font-semibold text-zinc-950 active:bg-amber-300"
    >
      {children}
    </Link>
  );
}

export function Field({ label, children }: { label: string; children: ReactNode }) {
  return (
    <label className="mb-3 block">
      <span className="mb-1 block text-xs font-medium text-zinc-400">{label}</span>
      {children}
    </label>
  );
}

export function Input({ className = "", ...props }: InputHTMLAttributes<HTMLInputElement>) {
  return (
    <input
      className={`w-full rounded-xl border border-zinc-700 bg-zinc-900 px-3 py-2.5 text-sm text-white outline-none placeholder:text-zinc-500 focus:border-amber-400 ${className}`}
      {...props}
    />
  );
}

export function Select({ className = "", ...props }: SelectHTMLAttributes<HTMLSelectElement>) {
  return (
    <select
      className={`w-full rounded-xl border border-zinc-700 bg-zinc-900 px-3 py-2.5 text-sm text-white outline-none focus:border-amber-400 ${className}`}
      {...props}
    />
  );
}

export function ErrorText({ children }: { children: ReactNode }) {
  if (!children) return null;
  return <p className="mb-3 rounded-lg bg-red-500/10 px-3 py-2 text-sm text-red-400">{children}</p>;
}

export function SuccessText({ children }: { children: ReactNode }) {
  if (!children) return null;
  return <p className="mb-3 rounded-lg bg-emerald-500/10 px-3 py-2 text-sm text-emerald-400">{children}</p>;
}

export function Badge({ children, tone = "gold" }: { children: ReactNode; tone?: "gold" | "green" | "neutral" }) {
  const styles =
    tone === "gold"
      ? "bg-amber-400 text-zinc-950"
      : tone === "green"
        ? "bg-emerald-500/15 text-emerald-400"
        : "bg-zinc-800 text-zinc-300";
  return <span className={`inline-block whitespace-nowrap rounded-full px-2.5 py-1 text-[11px] font-semibold ${styles}`}>{children}</span>;
}

export function Pill({
  active,
  onClick,
  children,
}: {
  active: boolean;
  onClick: () => void;
  children: ReactNode;
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      className={`shrink-0 rounded-full px-4 py-2 text-sm font-medium transition ${
        active ? "bg-amber-400 text-zinc-950" : "bg-zinc-800 text-zinc-300"
      }`}
    >
      {children}
    </button>
  );
}

export function Avatar({ name, size = 48 }: { name: string; size?: number }) {
  const initials = name
    .trim()
    .split(/\s+/)
    .slice(0, 2)
    .map((w) => w[0]?.toUpperCase())
    .join("");
  return (
    <div
      style={{ width: size, height: size }}
      className="flex shrink-0 items-center justify-center rounded-full bg-zinc-800 text-sm font-semibold text-amber-400"
    >
      {initials || "?"}
    </div>
  );
}

export function formatPrice(cents: number) {
  return `${(cents / 100).toFixed(0)} lei`;
}

export function formatSlotTime(iso: string) {
  return new Date(iso).toLocaleTimeString("ro-RO", { hour: "2-digit", minute: "2-digit", timeZone: "UTC" });
}

export function formatRating(avgRating: number | null, reviewCount: number) {
  if (avgRating === null || reviewCount === 0) return "Fără recenzii încă";
  return `★ ${avgRating.toFixed(1)} (${reviewCount})`;
}

export function formatSlotDateTime(iso: string) {
  return new Date(iso).toLocaleString("ro-RO", {
    weekday: "short",
    day: "2-digit",
    month: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    timeZone: "UTC",
  });
}
