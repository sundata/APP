"use client";
import { usePrefs } from "@/lib/theme";
import { LOCALES, t } from "@/lib/i18n";

export default function SettingsPage() {
  const { prefs, setPrefs } = usePrefs();
  return (
    <div className="mx-auto max-w-md space-y-6 py-10">
      <div>
        <h2 className="mb-2 font-semibold">语言 / Language / 言語</h2>
        <div className="flex gap-2">
          {LOCALES.map((l) => (
            <button key={l} onClick={() => setPrefs({ locale: l })}
              className={`rounded border px-3 py-1 ${prefs.locale === l ? "border-neutral-900 dark:border-neutral-100" : ""}`}>
              {l.toUpperCase()}
            </button>
          ))}
        </div>
      </div>
      <div>
        <h2 className="mb-2 font-semibold">主题</h2>
        <div className="flex gap-2">
          {(["light", "dark"] as const).map((m) => (
            <button key={m} onClick={() => setPrefs({ theme: m })}
              className={`rounded border px-3 py-1 ${prefs.theme === m ? "border-neutral-900 dark:border-neutral-100" : ""}`}>
              {m}
            </button>
          ))}
        </div>
      </div>
      <div>
        <h2 className="mb-2 font-semibold">涨跌配色</h2>
        <label className="flex items-center gap-2 text-sm">
          <input type="checkbox" checked={prefs.asianColors} onChange={(e) => setPrefs({ asianColors: e.target.checked })} />
          {t(prefs.locale, "asian_colors") ?? "红涨绿跌（亚洲配色）"}
        </label>
      </div>
    </div>
  );
}
