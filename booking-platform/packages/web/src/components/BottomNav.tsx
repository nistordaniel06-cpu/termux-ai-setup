"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { useAuth } from "@/lib/useAuth";

function HomeIcon({ active }: { active: boolean }) {
  return (
    <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke={active ? "#f2c14e" : "#71717a"} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <path d="M3 10.5 12 3l9 7.5" />
      <path d="M5 9.5V21h14V9.5" />
    </svg>
  );
}

function SearchIcon({ active }: { active: boolean }) {
  return (
    <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke={active ? "#f2c14e" : "#71717a"} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <circle cx="11" cy="11" r="7" />
      <path d="m21 21-4.3-4.3" />
    </svg>
  );
}

function HeartIcon({ active }: { active: boolean }) {
  return (
    <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke={active ? "#f2c14e" : "#71717a"} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <path d="M20.8 4.6a5.5 5.5 0 0 0-7.8 0L12 5.6l-1-1a5.5 5.5 0 0 0-7.8 7.8l1 1L12 21l7.8-7.6 1-1a5.5 5.5 0 0 0 0-7.8Z" />
    </svg>
  );
}

function CalendarIcon({ active }: { active: boolean }) {
  return (
    <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke={active ? "#f2c14e" : "#71717a"} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <rect x="3" y="5" width="18" height="16" rx="2" />
      <path d="M3 10h18M8 3v4M16 3v4" />
    </svg>
  );
}

function UserIcon({ active }: { active: boolean }) {
  return (
    <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke={active ? "#f2c14e" : "#71717a"} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <circle cx="12" cy="8" r="4" />
      <path d="M4 21c1.5-4 5-6 8-6s6.5 2 8 6" />
    </svg>
  );
}

export default function BottomNav() {
  const pathname = usePathname();
  const { auth } = useAuth();

  const profileHref = !auth ? "/login" : auth.user.role === "CLIENT" ? "/my-bookings" : "/dashboard";

  const items = [
    { href: "/", label: "Acasă", Icon: HomeIcon, match: (p: string) => p === "/" },
    { href: "/discover", label: "Căutare", Icon: SearchIcon, match: (p: string) => p.startsWith("/discover") },
    { href: "/favorites", label: "Favorite", Icon: HeartIcon, match: (p: string) => p.startsWith("/favorites") },
    { href: "/my-bookings", label: "Programări", Icon: CalendarIcon, match: (p: string) => p.startsWith("/my-bookings") },
    { href: profileHref, label: "Profil", Icon: UserIcon, match: (p: string) => p.startsWith("/login") || p.startsWith("/dashboard") },
  ];

  return (
    <nav className="fixed bottom-0 left-1/2 z-40 w-full max-w-md -translate-x-1/2 border-t border-zinc-800 bg-zinc-950/95 px-2 backdrop-blur md:max-w-2xl">
      <div className="mx-auto flex max-w-md items-stretch justify-between">
        {items.map(({ href, label, Icon, match }) => {
          const active = match(pathname);
          return (
            <Link
              key={label}
              href={href}
              className="flex flex-1 flex-col items-center gap-1 py-2.5 text-[11px]"
            >
              <Icon active={active} />
              <span className={active ? "font-medium text-amber-400" : "text-zinc-500"}>{label}</span>
            </Link>
          );
        })}
      </div>
    </nav>
  );
}
