"use client";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { t } from "@/lib/i18n";
import { usePrefs } from "@/lib/theme";

const TABS = ["home", "markets", "watchlist", "news", "calendar"] as const;

export function Nav() {
  const { prefs } = usePrefs();
  const path = usePathname();
  return (
    <header className="sticky top-0 z-10 border-b bg-white/80 backdrop-blur dark:bg-neutral-950/80">
      <nav className="mx-auto flex max-w-5xl items-center gap-1 px-4 py-3">
        <Link href="/" className="mr-4 font-bold">SimpleMarket</Link>
        {TABS.map((k) => (
          <Link
            key={k}
            href={k === "home" ? "/" : `/${k}`}
            className={`rounded px-3 py-1 text-sm ${
              (k === "home" ? path === "/" : path.startsWith(`/${k}`))
                ? "bg-neutral-100 dark:bg-neutral-800 font-medium"
                : "text-neutral-500"
            }`}
          >
            {t(prefs.locale, k)}
          </Link>
        ))}
        <div className="ml-auto flex gap-2 text-sm">
          <Link href="/search">{t(prefs.locale, "search")}</Link>
          <Link href="/settings">{t(prefs.locale, "settings")}</Link>
        </div>
      </nav>
    </header>
  );
}
