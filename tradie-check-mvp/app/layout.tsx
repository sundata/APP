import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "TradieCheck — Check before you pay",
  description: "A fast, private first-pass risk check for Australian tradie quotes.",
  openGraph: {
    title: "TradieCheck — Check before you pay",
    description: "A fast, private first-pass risk check for Australian tradie quotes.",
    images: [{ url: "/og.png", width: 1200, height: 630, alt: "TradieCheck quote risk screening" }],
  },
  twitter: {
    card: "summary_large_image",
    title: "TradieCheck — Check before you pay",
    description: "A fast, private first-pass risk check for Australian tradie quotes.",
    images: ["/og.png"],
  },
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return <html lang="en"><body>{children}</body></html>;
}
