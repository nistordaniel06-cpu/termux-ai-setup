import type { Metadata, Viewport } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Booking Platform",
  description: "Găsește un frizer bun și programează-te în câteva secunde.",
};

export const viewport: Viewport = {
  width: "device-width",
  initialScale: 1,
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="ro">
      <body className="min-h-screen bg-[#fafafa] text-gray-900 antialiased">
        <div className="mx-auto flex min-h-screen max-w-md flex-col">{children}</div>
      </body>
    </html>
  );
}
