CREATE TABLE `signals` (
	`id` integer PRIMARY KEY AUTOINCREMENT NOT NULL,
	`kind` text NOT NULL,
	`email` text,
	`sentiment` text,
	`score` integer,
	`project_type` text,
	`created_at` integer NOT NULL
);
