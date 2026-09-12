"use client";
// Theme: light/dark + Asian color mode (red=up / green=down toggle, §29).
import { createContext, useContext, useEffect, useState, ReactNode } from "react";
import { Locale, LOCALES } from "./i18n";

interface Prefs {
  theme: "light" | "dark";
  asianColors: boolean; // red-up/green-down
  locale: Locale;
}
const defaults: Prefs = { theme: "light", asianColors: true, locale: "zh" };

const Ctx = createContext<{ prefs: Prefs; setPrefs: (p: Partial<Prefs>) => void }>({
  prefs: defaults,
  setPrefs: () => {},
});

export function usePrefs() { return useContext(Ctx); }

export function PrefsProvider({ children }: { children: ReactNode }) {
  const [prefs, setState] = useState<Prefs>(defaults);
  useEffect(() => {
    try {
      const saved = JSON.parse(localStorage.getItem("sm-prefs") || "{}");
      setState((p) => ({ ...p, ...saved }));
    } catch { /* ignore */ }
  }, []);
  const setPrefs = (p: Partial<Prefs>) =>
    setState((prev) => {
      const next = { ...prev, ...p };
      localStorage.setItem("sm-prefs", JSON.stringify(next));
      return next;
    });

  useEffect(() => {
    document.documentElement.classList.toggle("dark", prefs.theme === "dark");
    document.documentElement.style.setProperty(
      "--color-up", prefs.asianColors ? "#e5484d" : "#30a46c"
    );
    document.documentElement.style.setProperty(
      "--color-down", prefs.asianColors ? "#30a46c" : "#e5484d"
    );
  }, [prefs.theme, prefs.asianColors]);

  return <Ctx.Provider value={{ prefs, setPrefs }}>{children}</Ctx.Provider>;
}
