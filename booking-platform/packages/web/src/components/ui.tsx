"use client";

import Link from "next/link";
import { ButtonHTMLAttributes, InputHTMLAttributes, ReactNode, SelectHTMLAttributes } from "react";

export function Screen({ children }: { children: ReactNode }) {
  return <main className="flex flex-1 flex-col px-5 py-6">{children}</main>;
}

export function Title({ children }: { children: ReactNode }) {
  return <h1 className="mb-1 text-2xl font-semibold tracking-tight text-gray-900">{children}</h1>;
}

export function Subtitle({ children }: { children: ReactNode }) {
  return <p className="mb-6 text-sm text-gray-500">{children}</p>;
}

export function Card({ children, className = "" }: { children: ReactNode; className?: string }) {
  return (
    <div className={`rounded-2xl border border-gray-200 bg-white p-4 shadow-sm ${className}`}>{children}</div>
  );
}

export function Button({
  variant = "primary",
  className = "",
  ...props
}: ButtonHTMLAttributes<HTMLButtonElement> & { variant?: "primary" | "secondary" }) {
  const base = "w-full rounded-xl px-4 py-3 text-sm font-medium transition disabled:opacity-50";
  const styles =
    variant === "primary"
      ? "bg-gray-900 text-white active:bg-gray-800"
      : "bg-gray-100 text-gray-900 active:bg-gray-200";
  return <button className={`${base} ${styles} ${className}`} {...props} />;
}

export function LinkButton({ href, children }: { href: string; children: ReactNode }) {
  return (
    <Link
      href={href}
      className="block w-full rounded-xl bg-gray-900 px-4 py-3 text-center text-sm font-medium text-white active:bg-gray-800"
    >
      {children}
    </Link>
  );
}

export function Field({ label, children }: { label: string; children: ReactNode }) {
  return (
    <label className="mb-3 block">
      <span className="mb-1 block text-xs font-medium text-gray-600">{label}</span>
      {children}
    </label>
  );
}

export function Input(props: InputHTMLAttributes<HTMLInputElement>) {
  return (
    <input
      className="w-full rounded-xl border border-gray-300 px-3 py-2.5 text-sm outline-none focus:border-gray-900"
      {...props}
    />
  );
}

export function Select(props: SelectHTMLAttributes<HTMLSelectElement>) {
  return (
    <select
      className="w-full rounded-xl border border-gray-300 bg-white px-3 py-2.5 text-sm outline-none focus:border-gray-900"
      {...props}
    />
  );
}

export function ErrorText({ children }: { children: ReactNode }) {
  if (!children) return null;
  return <p className="mb-3 rounded-lg bg-red-50 px-3 py-2 text-sm text-red-700">{children}</p>;
}

export function SuccessText({ children }: { children: ReactNode }) {
  if (!children) return null;
  return <p className="mb-3 rounded-lg bg-green-50 px-3 py-2 text-sm text-green-700">{children}</p>;
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
