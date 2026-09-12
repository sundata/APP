import "./globals.css";
import { PrefsProvider } from "@/lib/theme";
import { Nav } from "./nav";

export const metadata = { title: "SimpleMarket", description: "简洁的全球行情资讯" };

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="zh">
      <body className="bg-white text-neutral-900 dark:bg-neutral-950 dark:text-neutral-100">
        <PrefsProvider>
          <Nav />
          <main className="mx-auto max-w-5xl px-4 pb-16">{children}</main>
        </PrefsProvider>
      </body>
    </html>
  );
}
