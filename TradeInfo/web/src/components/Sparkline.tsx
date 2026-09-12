// Minimal SVG line chart — no chart lib dependency.
import { ChartPoint } from "@/lib/api";

export function Sparkline({ points }: { points: ChartPoint[] }) {
  if (points.length < 2)
    return <div className="h-40 rounded bg-neutral-50 dark:bg-neutral-900" />;
  const ys = points.map((p) => Number(p.price));
  const [min, max] = [Math.min(...ys), Math.max(...ys)];
  const w = 600, h = 160, span = max - min || 1;
  const d = points
    .map((p, i) => `${(i / (points.length - 1)) * w},${h - ((Number(p.price) - min) / span) * h}`)
    .join(" L");
  const rising = ys[ys.length - 1] >= ys[0];
  return (
    <svg viewBox={`0 0 ${w} ${h}`} className="h-40 w-full">
      <polyline fill="none" strokeWidth="2" points={d}
        stroke={rising ? "var(--color-up)" : "var(--color-down)"} />
    </svg>
  );
}
