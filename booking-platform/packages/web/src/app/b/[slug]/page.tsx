import type { Metadata } from "next";
import PublicBusinessClient from "./PublicBusinessClient";

const API_URL = process.env.NEXT_PUBLIC_API_URL || "http://localhost:4000/api/v1";

type Params = { params: { slug: string } };

export async function generateMetadata({ params }: Params): Promise<Metadata> {
  try {
    const res = await fetch(`${API_URL}/businesses/${params.slug}`, { cache: "no-store" });
    if (!res.ok) throw new Error("not found");
    const business = await res.json();
    const cityPart = business.city ? ` din ${business.city}` : "";

    return {
      title: `${business.name} — programări online`,
      description: `Programează-te la ${business.name}${cityPart}. Vezi servicii, prețuri și ore disponibile în timp real.`,
    };
  } catch {
    return { title: "Salon — Booking Platform" };
  }
}

export default function PublicBusinessPage({ params }: Params) {
  return <PublicBusinessClient slug={params.slug} />;
}
