"use client";
import { useState } from "react";
import { api } from "@/lib/api";
import { useRouter } from "next/navigation";

export default function LoginPage() {
  const [email, setEmail] = useState("");
  const [pw, setPw] = useState("");
  const [mode, setMode] = useState<"login" | "register">("login");
  const [error, setError] = useState("");
  const router = useRouter();

  async function oauthLogin(provider: "google" | "apple") {
    setError("");
    try {
      // In prod: id_token comes from GIS/AppleJS. Dev posts a mock payload.
      const mock = `a.${btoa(JSON.stringify({ sub: `${provider}-demo`, email: `${provider}@demo.com` }))}.s`;
      const r = await fetch(
        (process.env.NEXT_PUBLIC_API_URL || "http://localhost:8000") + "/api/v1/auth/oauth",
        {
          method: "POST",
          headers: { "content-type": "application/json" },
          body: JSON.stringify({ provider, id_token: mock }),
        }
      );
      const j = await r.json();
      if (!r.ok) throw new Error(j?.error?.message ?? "oauth failed");
      localStorage.setItem("sm-token", j.access_token);
      localStorage.setItem("sm-refresh", j.refresh_token);
      router.push("/watchlist");
    } catch (e) {
      setError(e instanceof Error ? e.message : "oauth failed");
    }
  }

  async function submit() {
    setError("");
    try {
      const r = mode === "login" ? await api.login(email, pw) : await api.register(email, pw);
      localStorage.setItem("sm-token", r.access_token);
      localStorage.setItem("sm-refresh", r.refresh_token);
      router.push("/watchlist");
    } catch (e) {
      setError(e instanceof Error ? e.message : "failed");
    }
  }
  return (
    <div className="mx-auto max-w-sm py-16">
      <h1 className="mb-4 text-lg font-bold">{mode === "login" ? "登录" : "注册"}</h1>
      <input value={email} onChange={(e) => setEmail(e.target.value)} placeholder="email"
        className="mb-2 w-full rounded border px-3 py-2 dark:bg-neutral-900" />
      <input value={pw} onChange={(e) => setPw(e.target.value)} type="password" placeholder="password"
        className="mb-3 w-full rounded border px-3 py-2 dark:bg-neutral-900" />
      {error && <p className="mb-2 text-sm text-red-500">{error}</p>}
      <button onClick={submit} className="w-full rounded bg-neutral-900 py-2 text-white dark:bg-neutral-100 dark:text-black">
        {mode === "login" ? "登录" : "注册"}
      </button>
      <div className="my-3 flex items-center gap-2 text-xs text-neutral-400">
        <span className="h-px flex-1 bg-neutral-200 dark:bg-neutral-800" />或<span className="h-px flex-1 bg-neutral-200 dark:bg-neutral-800" />
      </div>
      {/* Google Identity Services / Apple JS load at deploy; they return an
          id_token that we post to /auth/oauth. In dev the buttons post a
          mock token so the flow is exercisable end-to-end. */}
      <button
        onClick={() => oauthLogin("google")}
        className="mb-2 w-full rounded border py-2 text-sm"
      >Continue with Google</button>
      <button
        onClick={() => oauthLogin("apple")}
        className="w-full rounded border py-2 text-sm"
      >Continue with Apple</button>
      <button onClick={() => setMode(mode === "login" ? "register" : "login")}
        className="mt-3 w-full text-sm text-neutral-500">
        {mode === "login" ? "没有账号？注册" : "已有账号？登录"}
      </button>
    </div>
  );
}
