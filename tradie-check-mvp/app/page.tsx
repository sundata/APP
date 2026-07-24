"use client";

import { FormEvent, useMemo, useState } from "react";

type Report = {
  score: number;
  label: string;
  tone: "good" | "watch" | "risk";
  checks: { title: string; detail: string; status: "pass" | "warn" | "fail" }[];
};

const projectTypes = [
  "Plumbing",
  "Electrical",
  "Roofing",
  "Bathroom renovation",
  "Heating & cooling",
  "Other building work",
];

function validAbn(value: string) {
  const digits = value.replace(/\D/g, "").split("").map(Number);
  if (digits.length !== 11) return false;
  digits[0] -= 1;
  const weights = [10, 1, 3, 5, 7, 9, 11, 13, 15, 17, 19];
  return digits.reduce((sum, digit, index) => sum + digit * weights[index], 0) % 89 === 0;
}

function money(value: string) {
  return Number(value.replace(/[^0-9.]/g, "")) || 0;
}

export default function Home() {
  const [abn, setAbn] = useState("");
  const [project, setProject] = useState(projectTypes[0]);
  const [quoteTotal, setQuoteTotal] = useState("");
  const [deposit, setDeposit] = useState("");
  const [licence, setLicence] = useState("");
  const [fileName, setFileName] = useState("");
  const [report, setReport] = useState<Report | null>(null);
  const [feedback, setFeedback] = useState<"helpful" | "not_helpful" | null>(null);
  const [email, setEmail] = useState("");
  const [emailState, setEmailState] = useState<"idle" | "saving" | "saved" | "error">("idle");

  const formattedAbn = useMemo(() => {
    const raw = abn.replace(/\D/g, "").slice(0, 11);
    return raw.replace(/(\d{2})(\d{3})(\d{3})(\d{3})/, "$1 $2 $3 $4");
  }, [abn]);

  async function sendSignal(payload: Record<string, unknown>) {
    const response = await fetch("/api/signals", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify(payload),
    });
    if (!response.ok) throw new Error("save failed");
  }

  function createReport(event: FormEvent) {
    event.preventDefault();
    const total = money(quoteTotal);
    const upfront = money(deposit);
    const ratio = total > 0 ? upfront / total : 0;
    const checks: Report["checks"] = [];
    let score = 100;

    if (validAbn(abn)) {
      checks.push({ title: "ABN format passes", detail: "The 11-digit ABN passes the official checksum format. Confirm its status on ABN Lookup.", status: "pass" });
    } else {
      score -= 35;
      checks.push({ title: "ABN needs attention", detail: "This number does not pass the Australian ABN checksum. Ask the tradie to confirm it before paying.", status: "fail" });
    }

    if (licence.trim()) {
      checks.push({ title: "Licence supplied", detail: `Licence ${licence.trim()} is ready to check against the relevant state register.`, status: "pass" });
    } else {
      score -= 15;
      checks.push({ title: "No licence number entered", detail: `${project} work may require a licence. Confirm the correct class and holder before work starts.`, status: "warn" });
    }

    if (!total) {
      score -= 20;
      checks.push({ title: "No clear total", detail: "A written quote should state the total price or explain how the final amount is calculated.", status: "fail" });
    } else if (ratio > 0.5) {
      score -= 25;
      checks.push({ title: "High upfront payment", detail: `${Math.round(ratio * 100)}% is requested before work begins. Ask for milestones and verify the applicable deposit rules.`, status: "fail" });
    } else if (ratio > 0.2) {
      score -= 10;
      checks.push({ title: "Deposit worth checking", detail: `${Math.round(ratio * 100)}% is requested upfront. Compare it with project milestones and state rules.`, status: "warn" });
    } else {
      checks.push({ title: "Lower upfront exposure", detail: ratio ? `The deposit is ${Math.round(ratio * 100)}% of the quote.` : "No upfront deposit was entered.", status: "pass" });
    }

    if (fileName) {
      checks.push({ title: "Written quote attached", detail: `${fileName} was selected. In this privacy-first demo it stays on your device.`, status: "pass" });
    } else {
      score -= 10;
      checks.push({ title: "Written quote missing", detail: "Upload the written quote so scope, exclusions, GST and payment milestones can be reviewed.", status: "warn" });
    }

    const label = score >= 80 ? "Lower concern" : score >= 55 ? "Check before paying" : "High concern";
    const tone = score >= 80 ? "good" : score >= 55 ? "watch" : "risk";
    setReport({ score: Math.max(score, 0), label, tone, checks });
    setFeedback(null);
    void sendSignal({ kind: "report", score: Math.max(score, 0), projectType: project }).catch(() => undefined);
    setTimeout(() => document.getElementById("report")?.scrollIntoView({ behavior: "smooth", block: "start" }), 50);
  }

  async function recordFeedback(value: "helpful" | "not_helpful") {
    setFeedback(value);
    try {
      await sendSignal({ kind: "feedback", sentiment: value, score: report?.score, projectType: project });
    } catch {
      setFeedback(null);
    }
  }

  async function joinWaitlist(event: FormEvent) {
    event.preventDefault();
    setEmailState("saving");
    try {
      await sendSignal({ kind: "waitlist", email, score: report?.score, projectType: project });
      setEmailState("saved");
    } catch {
      setEmailState("error");
    }
  }

  return (
    <main>
      <header className="nav shell">
        <a className="brand" href="#top" aria-label="TradieCheck home"><span>TC</span> TradieCheck</a>
        <div className="nav-note"><i /> Quote files stay private</div>
      </header>

      <section className="hero shell" id="top">
        <div className="hero-copy">
          <p className="eyebrow">BEFORE YOU PAY A DEPOSIT</p>
          <h1>A clearer second look at your tradie quote.</h1>
          <p className="lede">Enter an ABN, add the quote details and get a practical risk checklist in under two minutes. No account needed.</p>
          <div className="trust-row"><span>✓ ABN format check</span><span>✓ Deposit risk flags</span><span>✓ Next-step checklist</span></div>
        </div>
        <aside className="hero-card" aria-label="Example report summary">
          <div className="mini-top"><span>Example report</span><b>82</b></div>
          <div className="meter"><i /></div>
          <h3>Lower concern</h3>
          <p>ABN format passes · Written quote attached · Licence still needs official confirmation</p>
        </aside>
      </section>

      <section className="workspace shell">
        <form className="form-card" onSubmit={createReport}>
          <div className="section-title"><span>1</span><div><h2>Check a quote</h2><p>Use the information shown on the quote.</p></div></div>

          <label>Tradie ABN <em>Required</em>
            <input inputMode="numeric" placeholder="12 345 678 901" value={formattedAbn} onChange={(e) => setAbn(e.target.value)} required />
          </label>

          <div className="two-col">
            <label>Type of work
              <select value={project} onChange={(e) => setProject(e.target.value)}>{projectTypes.map((item) => <option key={item}>{item}</option>)}</select>
            </label>
            <label>Licence number <small>Optional</small>
              <input placeholder="e.g. 123456" value={licence} onChange={(e) => setLicence(e.target.value)} />
            </label>
          </div>

          <div className="two-col">
            <label>Total quote (AUD) <em>Required</em>
              <div className="money-input"><span>$</span><input inputMode="decimal" placeholder="8,500" value={quoteTotal} onChange={(e) => setQuoteTotal(e.target.value)} required /></div>
            </label>
            <label>Deposit requested
              <div className="money-input"><span>$</span><input inputMode="decimal" placeholder="1,000" value={deposit} onChange={(e) => setDeposit(e.target.value)} /></div>
            </label>
          </div>

          <label>Written quote <small>PDF, JPG or PNG</small>
            <div className="upload">
              <input type="file" accept=".pdf,.jpg,.jpeg,.png" onChange={(e) => setFileName(e.target.files?.[0]?.name || "")} />
              <strong>{fileName || "Choose your quote"}</strong>
              <span>{fileName ? "Selected — stays on this device" : "Tap to select a file · 10 MB max"}</span>
            </div>
          </label>

          <button type="submit">Generate my risk check <span>→</span></button>
          <p className="privacy">🔒 This demo does not upload or store your quote.</p>
        </form>

        <aside className="how-card">
          <p className="eyebrow">WHAT YOU'LL GET</p>
          <h2>A useful answer—not another directory.</h2>
          <ol>
            <li><span>01</span><div><b>Identity signal</b><p>Check whether the ABN format is valid and jump to the official register.</p></div></li>
            <li><span>02</span><div><b>Payment exposure</b><p>See when an upfront deposit deserves a closer look.</p></div></li>
            <li><span>03</span><div><b>Clear next steps</b><p>Know exactly what to confirm before work or payment begins.</p></div></li>
          </ol>
          <div className="disclaimer"><b>Important</b><p>This is an early screening tool, not legal advice or a guarantee of workmanship. Always verify registrations with the relevant government authority.</p></div>
        </aside>
      </section>

      {report && <section className={`report shell ${report.tone}`} id="report">
        <div className="report-head">
          <div><p className="eyebrow">YOUR SCREENING RESULT</p><h2>{report.label}</h2><p>Based on the details you entered—not a guarantee or credit score.</p></div>
          <div className="score"><b>{report.score}</b><span>/100</span></div>
        </div>
        <div className="checks">
          {report.checks.map((check) => <article key={check.title} className={check.status}><span>{check.status === "pass" ? "✓" : check.status === "warn" ? "!" : "×"}</span><div><h3>{check.title}</h3><p>{check.detail}</p></div></article>)}
        </div>
        <div className="actions">
          <a href={`https://abr.business.gov.au/ABN/View?abn=${abn.replace(/\D/g, "")}`} target="_blank" rel="noreferrer">Verify ABN on government register ↗</a>
          <button type="button" onClick={() => window.print()}>Save / print report</button>
        </div>
        <div className="validation-box">
          <div className="feedback-block">
            <b>Was this check useful?</b>
            {feedback ? <p>Thanks — your feedback helps improve the next version.</p> : <div className="feedback-buttons">
              <button type="button" onClick={() => recordFeedback("helpful")}>👍 Yes</button>
              <button type="button" onClick={() => recordFeedback("not_helpful")}>👎 Not yet</button>
            </div>}
          </div>
          <form className="waitlist" onSubmit={joinWaitlist}>
            <div><b>Want real quote-document analysis?</b><p>Join the early-access list. No marketing spam.</p></div>
            {emailState === "saved" ? <strong className="saved">✓ You’re on the list</strong> : <div className="email-row"><input type="email" required placeholder="you@example.com" value={email} onChange={(e) => setEmail(e.target.value)} /><button disabled={emailState === "saving"}>{emailState === "saving" ? "Saving…" : "Notify me"}</button></div>}
            {emailState === "error" && <span className="form-error">Couldn’t save that. Please try again.</span>}
          </form>
        </div>
      </section>}

      <footer className="shell"><span>TradieCheck · Melbourne MVP</span><span>Screen first. Verify officially. Pay carefully.</span></footer>
    </main>
  );
}
