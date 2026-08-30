import { getDb } from "../../../db";
import { signals } from "../../../db/schema";

type SignalRequestBody = {
  kind?: string;
  email?: string;
  sentiment?: string;
  score?: number;
  projectType?: string;
};

export async function POST(request: Request) {
  let body: SignalRequestBody;

  try {
    body = (await request.json()) as SignalRequestBody;
  } catch (error) {
    console.error("[signals] Malformed request body", error);
    return Response.json({ error: "Invalid request body" }, { status: 400 });
  }

  try {
    if (!body.kind || !["report", "feedback", "waitlist"].includes(body.kind)) {
      return Response.json({ error: "Invalid signal" }, { status: 400 });
    }

    const email = body.email?.trim().toLowerCase() || null;
    if (email && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
      return Response.json({ error: "Enter a valid email" }, { status: 400 });
    }

    const db = getDb();
    await db.insert(signals).values({
      kind: body.kind,
      email,
      sentiment: ["helpful", "not_helpful"].includes(body.sentiment || "") ? body.sentiment : null,
      score: Number.isFinite(body.score) ? Math.max(0, Math.min(100, Math.round(body.score!))) : null,
      projectType: body.projectType?.slice(0, 80) || null,
      createdAt: new Date(),
    });

    return Response.json({ ok: true }, { status: 201 });
  } catch (error) {
    console.error("[signals] Failed to save signal", {
      error,
      kind: body.kind,
      projectType: body.projectType,
    });
    return Response.json({ error: "Could not save your response" }, { status: 500 });
  }
}
