import { Quote } from "@/lib/api";

// §39 freshness label — always visible next to a price.
export function FreshnessBadge({ freshness }: { freshness: Quote["freshness"] }) {
  const styles: Record<Quote["freshness"], string> = {
    live: "bg-green-100 text-green-700 dark:bg-green-900/40",
    delayed: "bg-yellow-100 text-yellow-700 dark:bg-yellow-900/40",
    stale: "bg-orange-100 text-orange-700 dark:bg-orange-900/40",
    closed: "bg-neutral-100 text-neutral-500 dark:bg-neutral-800",
    no_data: "bg-neutral-100 text-neutral-400 dark:bg-neutral-800",
  };
  return (
    <span className={`rounded px-1.5 py-0.5 text-[10px] font-medium ${styles[freshness]}`}>
      {freshness}
    </span>
  );
}
