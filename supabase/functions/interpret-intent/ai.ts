// IA de Deytra: interpreta la necesidad en lenguaje natural y, cuando hace falta,
// sugiere negocios o cuentas reales encontradas en internet (con su link).
// Funciona con Anthropic (Claude) u OpenAI. Las claves viven solo en el backend
// (secretos de Supabase). Para cambiar de proveedor alcanza con el secreto AI_PROVIDER.
//
//   AI_PROVIDER        "anthropic" (por defecto) u "openai"
//   ANTHROPIC_API_KEY  clave de Anthropic
//   OPENAI_API_KEY     clave de OpenAI
//   AI_MODEL           opcional, para forzar un modelo puntual

export type AiIntent = {
  direction?: "seek" | "offer";
  object_type?: "service" | "product" | "job_opportunity" | "venue" | "collaboration" | "other";
  category_slugs?: string[];
  city?: string | null;
  modality?: "presencial" | "remoto" | "hibrido" | "no_aplica";
  ships_nationwide?: boolean;
  web_query?: string;
};

export type Suggestion = {
  name: string;
  url: string;
  description: string;
  kind: "tienda" | "negocio" | "instagram" | "profesional";
  scope: "local" | "nacional";
};

export type AiConfig = { provider: "anthropic" | "openai"; key: string; model: string };

const DEFAULT_MODEL = { anthropic: "claude-haiku-5-5", openai: "gpt-6-luna" } as const;

/** Acepta el secreto aunque se haya pegado con texto de más: toma solo la clave. */
export function cleanKey(raw: string | undefined): string | undefined {
  if (!raw) return undefined;
  const hit = raw.match(/sk-(?:ant-|proj-|svcacct-)?[A-Za-z0-9_\-]{20,}/);
  const key = (hit ? hit[0] : raw).trim();
  return /^[\x21-\x7e]+$/.test(key) ? key : undefined;
}

/** Elige el proveedor según los secretos cargados. Devuelve null si no hay ninguna clave. */
export function aiConfig(env: (k: string) => string | undefined): AiConfig | null {
  const anthropic = cleanKey(env("ANTHROPIC_API_KEY"));
  const openai = cleanKey(env("OPENAI_API_KEY"));
  const wanted = (env("AI_PROVIDER") ?? "").trim().toLowerCase();
  const custom = (env("AI_MODEL") ?? "").trim();
  let provider: AiConfig["provider"] | null = null;
  if (wanted === "openai" && openai) provider = "openai";
  else if (wanted === "anthropic" && anthropic) provider = "anthropic";
  else if (anthropic) provider = "anthropic";
  else if (openai) provider = "openai";
  if (!provider) return null;
  return {
    provider,
    key: provider === "openai" ? openai! : anthropic!,
    model: /^[a-z0-9.\-]{3,60}$/i.test(custom) ? custom : DEFAULT_MODEL[provider],
  };
}

/** Respuesta común a los dos proveedores. */
type AiReply = { text: string; seen: Set<string> };

function hostOf(url: unknown): string | null {
  try {
    return typeof url === "string" ? new URL(url).hostname.replace(/^www\./, "") : null;
  } catch {
    return null;
  }
}

async function post(url: string, headers: Record<string, string>, body: unknown, ms: number) {
  return await fetch(url, {
    method: "POST",
    headers: { ...headers, "content-type": "application/json" },
    body: JSON.stringify(body),
    signal: AbortSignal.timeout(Math.max(1000, ms)),
  });
}

async function errorKind(res: Response) {
  try {
    const b = await res.json();
    return String(b?.error?.type ?? b?.error?.code ?? "").slice(0, 60);
  } catch {
    return "";
  }
}

async function askAnthropic(
  cfg: AiConfig,
  system: string,
  user: string,
  maxTokens: number,
  ms: number,
  search: { city: string | null; region: string | null } | null,
): Promise<AiReply | null> {
  const started = Date.now();
  const headers = { "x-api-key": cfg.key, "anthropic-version": "2023-06-01" };
  const base: Record<string, unknown> = {
    model: cfg.model,
    max_tokens: maxTokens,
    system,
    messages: [{ role: "user", content: user }],
  };
  if (search) {
    base.tools = [{
      type: "web_search_20250305",
      name: "web_search",
      // Una sola búsqueda por pedido: es lo que más cuesta.
      max_uses: 1,
      user_location: {
        type: "approximate",
        country: "AR",
        timezone: "America/Argentina/Buenos_Aires",
        ...(search.city ? { city: search.city } : {}),
        ...(search.region ? { region: search.region } : {}),
      },
    }];
  }
  const url = "https://api.anthropic.com/v1/messages";
  // Sin razonamiento extendido: respuestas cortas, rápidas y baratas.
  let res = await post(url, headers, { ...base, thinking: { type: "disabled" } }, ms);
  if (res.status === 400) {
    res = await post(
      url,
      headers,
      { ...base, max_tokens: Math.max(maxTokens * 4, 4000) },
      ms - (Date.now() - started),
    );
  }
  if (!res.ok) {
    console.error("[deytra-ai] anthropic status", res.status, await errorKind(res));
    return null;
  }
  const msg = await res.json();
  const seen = new Set<string>();
  const texts: string[] = [];
  for (const block of msg?.content ?? []) {
    if (block?.type === "text" && typeof block.text === "string") texts.push(block.text);
    if (block?.type === "web_search_tool_result" && Array.isArray(block.content)) {
      for (const r of block.content) {
        const h = hostOf(r?.url);
        if (h) seen.add(h);
      }
    }
    for (const c of block?.citations ?? []) {
      const h = hostOf(c?.url);
      if (h) seen.add(h);
    }
  }
  console.log(
    "[deytra-ai] anthropic ok",
    msg?.stop_reason,
    `${Date.now() - started}ms`,
    `in=${msg?.usage?.input_tokens ?? "?"} out=${msg?.usage?.output_tokens ?? "?"}`,
  );
  return { text: texts.join("\n"), seen };
}

async function askOpenAI(
  cfg: AiConfig,
  system: string,
  user: string,
  maxTokens: number,
  ms: number,
  search: { city: string | null; region: string | null } | null,
): Promise<AiReply | null> {
  const started = Date.now();
  const headers = { authorization: `Bearer ${cfg.key}` };
  const url = "https://api.openai.com/v1/responses";
  const base: Record<string, unknown> = {
    model: cfg.model,
    instructions: system,
    input: user,
    max_output_tokens: maxTokens,
    store: false,
  };
  if (search) {
    base.tools = [{
      type: "web_search",
      search_context_size: "low",
      user_location: {
        type: "approximate",
        country: "AR",
        timezone: "America/Argentina/Buenos_Aires",
        ...(search.city ? { city: search.city } : {}),
        ...(search.region ? { region: search.region } : {}),
      },
    }];
  }
  // Intento con los ajustes de ahorro; si el modelo no acepta alguno, se reintenta sin ellos.
  let res = await post(
    url,
    headers,
    { ...base, reasoning: { effort: "none" }, ...(search ? { max_tool_calls: 1 } : {}) },
    ms,
  );
  if (res.status === 400) {
    res = await post(
      url,
      headers,
      { ...base, max_output_tokens: Math.max(maxTokens * 4, 4000) },
      ms - (Date.now() - started),
    );
  }
  if (!res.ok) {
    console.error("[deytra-ai] openai status", res.status, await errorKind(res));
    return null;
  }
  const out = await res.json();
  const seen = new Set<string>();
  const texts: string[] = [];
  for (const item of out?.output ?? []) {
    if (item?.type === "message") {
      for (const part of item.content ?? []) {
        if (part?.type === "output_text" && typeof part.text === "string") texts.push(part.text);
        for (const a of part?.annotations ?? []) {
          const h = hostOf(a?.url);
          if (h) seen.add(h);
        }
      }
    }
    if (item?.type === "web_search_call") {
      for (const s of item?.action?.sources ?? []) {
        const h = hostOf(s?.url);
        if (h) seen.add(h);
      }
    }
  }
  console.log(
    "[deytra-ai] openai ok",
    out?.status,
    `${Date.now() - started}ms`,
    `in=${out?.usage?.input_tokens ?? "?"} out=${out?.usage?.output_tokens ?? "?"}`,
  );
  return { text: texts.join("\n"), seen };
}

async function ask(
  cfg: AiConfig,
  system: string,
  user: string,
  maxTokens: number,
  ms: number,
  search: { city: string | null; region: string | null } | null = null,
): Promise<AiReply | null> {
  try {
    return cfg.provider === "openai"
      ? await askOpenAI(cfg, system, user, maxTokens, ms, search)
      : await askAnthropic(cfg, system, user, maxTokens, ms, search);
  } catch (e) {
    // Nunca se registra el mensaje completo: podría contener la clave.
    console.error("[deytra-ai]", cfg.provider, "request failed", (e as Error)?.name ?? "error");
    return null;
  }
}

function firstJson(text: string, open: "{" | "["): any | null {
  // Primero un bloque ```json, después cada posición posible del primer carácter.
  const fenced = text.match(/```(?:json)?\s*([\s\S]*?)```/);
  const sources = fenced ? [fenced[1], text] : [text];
  const close = open === "{" ? "}" : "]";
  for (const src of sources) {
    const end = src.lastIndexOf(close);
    let start = src.indexOf(open);
    while (start >= 0 && start < end) {
      try {
        return JSON.parse(src.slice(start, end + 1));
      } catch {
        start = src.indexOf(open, start + 1);
      }
    }
  }
  return null;
}

const OBJ = ["service", "product", "job_opportunity", "venue", "collaboration", "other"];
const MOD = ["presencial", "remoto", "hibrido", "no_aplica"];

/** Entiende lo que la persona pide. Devuelve null si la IA no está disponible. */
export async function aiInterpret(
  cfg: AiConfig | null,
  text: string,
  profileCity: string | null,
  categories: { slug: string; name: string }[],
): Promise<AiIntent | null> {
  if (!cfg) return null;
  const catalog = categories.map((c) => `${c.slug}: ${c.name}`).join("\n");
  const system =
    "Sos el motor de comprensión de Deytra, una app argentina que conecta personas con quien puede resolver lo que necesitan. " +
    "Analizá el pedido y respondé SOLO un objeto JSON, sin texto extra, con estas claves: " +
    '"direction" ("seek" si la persona busca algo, "offer" si ofrece lo suyo), ' +
    '"object_type" (service, product, job_opportunity, venue, collaboration u other), ' +
    '"category_slugs" (de 1 a 6 slugs del catálogo, ordenados del más al menos pertinente; incluí todas las formas útiles de resolverlo, por ejemplo para "decorar el patio": jardineria, paisajismo, viveros-plantas, decoracion), ' +
    '"city" (la localidad argentina mencionada, con su nombre oficial, o null si no menciona ninguna), ' +
    '"modality" (presencial si alguien tiene que ir al lugar, remoto si se resuelve a distancia o con envío, hibrido si ambas sirven, no_aplica si da igual), ' +
    '"ships_nationwide" (true si es un producto que se puede comprar con envío a todo el país), ' +
    '"web_query" (una búsqueda corta en español para encontrar en internet negocios o cuentas que lo resuelvan, incluyendo la zona si importa). ' +
    "Usá solo slugs del catálogo. No inventes ciudades.";
  const user =
    `Catálogo de rubros:\n${catalog}\n\n` +
    `Ciudad del perfil de la persona: ${profileCity ?? "desconocida"}\n\n` +
    `Pedido: """${text.slice(0, 1500)}"""`;
  const reply = await ask(cfg, system, user, 600, 12000);
  const data = reply ? firstJson(reply.text, "{") : null;
  if (!data || typeof data !== "object") return null;
  const valid = new Set(categories.map((c) => c.slug));
  const out: AiIntent = {};
  if (data.direction === "seek" || data.direction === "offer") out.direction = data.direction;
  if (OBJ.includes(data.object_type)) out.object_type = data.object_type;
  if (Array.isArray(data.category_slugs)) {
    out.category_slugs = data.category_slugs
      .filter((s: unknown) => typeof s === "string" && valid.has(s))
      .slice(0, 6);
  }
  if (typeof data.city === "string" && data.city.trim() && data.city.length <= 80)
    out.city = data.city.trim();
  if (MOD.includes(data.modality)) out.modality = data.modality;
  if (typeof data.ships_nationwide === "boolean") out.ships_nationwide = data.ships_nationwide;
  if (typeof data.web_query === "string" && data.web_query.trim())
    out.web_query = data.web_query.trim().slice(0, 160);
  return out;
}

/**
 * Busca en internet negocios o cuentas reales. Solo devuelve links que aparecieron en la búsqueda.
 * Devuelve null si la búsqueda no se pudo hacer (para no contarla en el límite diario).
 */
export async function aiWebSuggestions(
  cfg: AiConfig | null,
  need: string,
  query: string,
  city: string | null,
  province: string | null,
  nationwide: boolean,
): Promise<Suggestion[] | null> {
  if (!cfg || !query) return null;
  const where = nationwide
    ? "con envío o atención a todo el país"
    : city
      ? `en ${city}${province ? `, ${province}` : ""} o alrededores`
      : "en Argentina";
  const system =
    "Sos la guía de Deytra. Hacé UNA búsqueda en internet para encontrar opciones reales que resuelvan la necesidad de la persona y respondé SOLO un arreglo JSON (sin texto extra) de hasta 4 objetos con: " +
    '"name" (nombre del negocio, tienda, profesional o cuenta), "url" (el link exacto que encontraste en los resultados: sitio web, tienda online o perfil de Instagram), ' +
    '"description" (qué ofrece y por qué sirve, máximo 140 caracteres, en español rioplatense), ' +
    '"kind" (tienda, negocio, instagram o profesional), "scope" (local o nacional). ' +
    "Priorizá opciones argentinas, con datos verificables y vigentes. No incluyas directorios genéricos, notas periodísticas ni marketplaces enteros como opción. " +
    "Si no encontrás nada confiable, devolvé [].";
  const user = `Necesidad: """${need.slice(0, 600)}"""\nBuscá: ${query} ${where}`;
  const reply = await ask(cfg, system, user, 2000, 35000, {
    city: nationwide ? null : city,
    region: nationwide ? null : province,
  });
  if (!reply) return null;
  const list = firstJson(reply.text, "[");
  if (!Array.isArray(list)) {
    console.log("[deytra-ai] web sin lista", reply.seen.size, "sitios vistos");
    return [];
  }
  const seen = reply.seen;
  const out: Suggestion[] = [];
  for (const s of list) {
    if (!s || typeof s.name !== "string" || typeof s.url !== "string") continue;
    let host = "";
    try {
      const u = new URL(s.url);
      if (u.protocol !== "https:" && u.protocol !== "http:") continue;
      host = u.hostname.replace(/^www\./, "");
    } catch {
      continue;
    }
    // Links realmente vistos en los resultados: evita links inventados.
    if (!seen.has(host) && ![...seen].some((h) => host.endsWith(h) || h.endsWith(host))) continue;
    out.push({
      name: s.name.slice(0, 80),
      url: s.url.slice(0, 500),
      description: typeof s.description === "string" ? s.description.slice(0, 160) : "",
      kind: ["tienda", "negocio", "instagram", "profesional"].includes(s.kind) ? s.kind : "negocio",
      scope: s.scope === "nacional" ? "nacional" : "local",
    });
    if (out.length >= 4) break;
  }
  return out;
}
