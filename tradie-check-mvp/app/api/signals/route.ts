import { getDb } from "../../../db";
import { signals } from "../../../db/schema";

export async function POST(request: Request) {
  try {
    const body = (await request.json()) as {
      kind?: string;
      email?: string;
      sentiment?: string;
      score?: number;
      projectType?: string;
    };

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
  } catch {
    return Response.json({ error: "Could not save your response" }, { status: 500 });
  }
}
