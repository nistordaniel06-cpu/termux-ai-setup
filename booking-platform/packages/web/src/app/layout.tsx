import type { Metadata, Viewport } from "next";
import "./globals.css";
import BottomNav from "@/components/BottomNav";

export const metadata: Metadata = {
  title: "Need a Haircut — programări la frizerii din oraș",
  description: "Găsește un frizer bun lângă tine și programează-te în câteva secunde.",
};

export const viewport: Viewport = {
  width: "device-width",
  initialScale: 1,
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="ro">
      <body className="min-h-screen bg-zinc-950 text-white antialiased">
        <div className="mx-auto flex min-h-screen max-w-md flex-col md:max-w-2xl">
          <div className="flex-1 pb-20">{children}</div>
          <BottomNav />
        </div>
      </body>
    </html>
  );
}
