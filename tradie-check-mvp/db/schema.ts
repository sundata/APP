import { integer, sqliteTable, text } from "drizzle-orm/sqlite-core";

export const signals = sqliteTable("signals", {
  id: integer("id").primaryKey({ autoIncrement: true }),
  kind: text("kind").notNull(),
  email: text("email"),
  sentiment: text("sentiment"),
  score: integer("score"),
  projectType: text("project_type"),
  createdAt: integer("created_at", { mode: "timestamp_ms" }).notNull(),
});
