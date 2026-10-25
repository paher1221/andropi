/**
 * User-defined providers, kept in pi's own models.json so the agent and the app
 * read the same file. Writes are pretty JSON, comments in an existing file are
 * tolerated when reading but not preserved on write.
 */

import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname } from "node:path";

export type CustomModel = {
	id: string;
	name?: string;
	contextWindow?: number;
	reasoning?: boolean;
	input?: string[];
};

export type CustomEntry = {
	name?: string;
	baseUrl?: string;
	api?: string;
	apiKey?: string;
	models?: CustomModel[];
};

export type CustomSummary = {
	id: string;
	name: string;
	baseUrl: string;
	api: string;
	hasKey: boolean;
	models: CustomModel[];
};

/** APIs pi can speak, in the order the picker offers them. */
export const APIS = ["openai-completions", "anthropic-messages", "google-generative-ai", "openai-responses"];

/** Strip // and /* *\/ comments without touching strings (URLs contain //). */
function stripComments(text: string) {
	let out = "";
	let inString = false;
	let escape = false;
	let line = false;
	let block = false;
	for (let i = 0; i < text.length; i++) {
		const c = text[i];
		const n = text[i + 1];
		if (line) {
			if (c === "\n") {
				line = false;
				out += c;
			}
			continue;
		}
		if (block) {
			if (c === "*" && n === "/") {
				block = false;
				i++;
			}
			continue;
		}
		if (inString) {
			out += c;
			if (escape) escape = false;
			else if (c === "\\") escape = true;
			else if (c === '"') inString = false;
			continue;
		}
		if (c === '"') {
			inString = true;
			out += c;
			continue;
		}
		if (c === "/" && n === "/") {
			line = true;
			i++;
			continue;
		}
		if (c === "/" && n === "*") {
			block = true;
			i++;
			continue;
		}
		out += c;
	}
	return out;
}

export class CustomProviders {
	constructor(public readonly file: string) {}

	private read(): { providers: Record<string, any> } {
		if (!existsSync(this.file)) return { providers: {} };
		try {
			const parsed = JSON.parse(stripComments(readFileSync(this.file, "utf-8")));
			if (!parsed || typeof parsed !== "object" || !parsed.providers) return { providers: {} };
			return { providers: parsed.providers as Record<string, any> };
		} catch {
			return { providers: {} };
		}
	}

	private write(data: { providers: Record<string, any> }) {
		mkdirSync(dirname(this.file), { recursive: true });
		writeFileSync(this.file, `${JSON.stringify(data, null, 2)}\n`, "utf-8");
	}

	list(): CustomSummary[] {
		const { providers } = this.read();
		return Object.entries(providers).map(([id, raw]) => {
			const p = raw as any;
			const models = Array.isArray(p.models)
				? p.models
						.filter((m: any) => m && typeof m.id === "string")
						.map((m: any) => ({
							id: m.id,
							name: m.name ?? m.id,
							contextWindow: m.contextWindow,
							reasoning: !!m.reasoning,
							input: m.input,
						}))
				: [];
			return {
				id,
				name: p.name ?? id,
				baseUrl: p.baseUrl ?? "",
				api: p.api ?? "openai-completions",
				hasKey: typeof p.apiKey === "string" && p.apiKey.length > 0,
				models,
			};
		});
	}

	has(id: string) {
		return Object.hasOwn(this.read().providers, id);
	}

	get(id: string) {
		return this.read().providers[id];
	}

	/** Merge into an existing entry so hand-written fields survive an edit. */
	save(id: string, entry: CustomEntry) {
		const data = this.read();
		const previous = data.providers[id] ?? {};
		const next: any = { ...previous };
		if (entry.name !== undefined) next.name = entry.name;
		if (entry.baseUrl !== undefined) next.baseUrl = entry.baseUrl;
		if (entry.api !== undefined) next.api = entry.api;
		if (entry.apiKey) next.apiKey = entry.apiKey;
		if (entry.models) next.models = entry.models;
		data.providers[id] = next;
		this.write(data);
	}

	remove(id: string) {
		const data = this.read();
		delete data.providers[id];
		this.write(data);
	}

	/** Provider id from a display name: "My Proxy" becomes "my-proxy". */
	static slug(name: string) {
		const base = name
			.toLowerCase()
			.replace(/[^a-z0-9]+/g, "-")
			.replace(/^-+|-+$/g, "");
		// Names without ASCII letters (e.g. Chinese) would all collapse to "provider".
		if (!base || base === "provider" || base.length < 2) return `provider-${Date.now().toString(36)}`;
		return base;
	}
}

type Probe = { id: string; name: string; contextWindow?: number };

async function json(res: Response) {
	const text = await res.text();
	try {
		return JSON.parse(text);
	} catch {
		throw new Error(`${res.status} ${res.statusText} — ${text.slice(0, 160)}`);
	}
}

/**
 * Ask a provider for its model list. OpenAI-compatible services answer /models,
 * Anthropic answers /models with x-api-key, Google answers /models with a key.
 */
export async function probeModels(opts: { api?: string; baseUrl: string; apiKey?: string }): Promise<Probe[]> {
	const api = opts.api ?? "openai-completions";
	const base = opts.baseUrl.replace(/\/+$/, "");
	if (!/^https?:\/\//.test(base)) throw new Error("Base URL must start with http:// or https://");
	const key = opts.apiKey?.trim() ?? "";
	const signal = AbortSignal.timeout(25000);

	if (api === "google-generative-ai") {
		const url = `${base}/models${key ? `?key=${encodeURIComponent(key)}` : ""}`;
		const res = await fetch(url, { signal });
		if (!res.ok) throw new Error(`${res.status} ${res.statusText} — ${(await res.text()).slice(0, 160)}`);
		const data: any = await json(res);
		const models: any[] = Array.isArray(data?.models) ? data.models : [];
		return models
			.filter((m) => !Array.isArray(m.supportedGenerationMethods) || m.supportedGenerationMethods.includes("generateContent"))
			.map((m) => ({
				id: String(m.name ?? "").replace(/^models\//, ""),
				name: m.displayName ?? String(m.name ?? "").replace(/^models\//, ""),
				contextWindow: m.inputTokenLimit,
			}))
			.filter((m) => m.id);
	}

	if (api === "anthropic-messages") {
		const res = await fetch(`${base}/models?limit=1000`, {
			signal,
			headers: {
				...(key ? { "x-api-key": key } : {}),
				"anthropic-version": "2023-06-01",
			},
		});
		if (!res.ok) throw new Error(`${res.status} ${res.statusText} — ${(await res.text()).slice(0, 160)}`);
		const data: any = await json(res);
		const models: any[] = Array.isArray(data?.data) ? data.data : [];
		return models.map((m) => ({ id: String(m.id), name: m.display_name ?? String(m.id) })).filter((m) => m.id);
	}

	// OpenAI-compatible: try as typed, then with /v1 when the bare host 404s.
	const headers: Record<string, string> = key ? { Authorization: `Bearer ${key}` } : {};
	let res = await fetch(`${base}/models`, { signal, headers });
	if (res.status === 404 && !/\/v\d+[a-z]*$/.test(base)) {
		res = await fetch(`${base}/v1/models`, { signal, headers });
	}
	if (!res.ok) throw new Error(`${res.status} ${res.statusText} — ${(await res.text()).slice(0, 160)}`);
	const data: any = await json(res);
	const models: any[] = Array.isArray(data?.data) ? data.data : Array.isArray(data?.models) ? data.models : Array.isArray(data) ? data : [];
	return models
		.map((m) => ({
			id: String(m.id ?? m.name ?? ""),
			name: m.name ?? m.id ?? "",
			contextWindow: m.context_length ?? m.context_window ?? m.max_context_length,
		}))
		.filter((m) => m.id);
}
