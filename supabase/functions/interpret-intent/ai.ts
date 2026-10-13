// IA de Deytra: interpreta la necesidad en lenguaje natural y, cuando hace falta,
// sugiere negocios o cuentas reales encontradas en internet (con su link).
// La clave vive solo en el backend (secreto ANTHROPIC_API_KEY de Supabase).

const API = "https://api.anthropic.com/v1/messages";
const MODEL = "claude-haiku-5-5";

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

/** Acepta el secreto aunque se haya pegado con texto de más: toma solo la clave. */
export function cleanKey(raw: string | undefined): string | undefined {
  if (!raw) return undefined;
  const hit = raw.match(/sk-ant-[A-Za-z0-9_\-]{20,}/);
  const key = (hit ? hit[0] : raw).trim();
  return /^[\x21-\x7e]+$/.test(key) ? key : undefined;
}

async function post(key: string, body: Record<string, unknown>, timeoutMs: number) {
  return await fetch(API, {
    method: "POST",
    headers: {
      "x-api-key": key,
      "anthropic-version": "2023-06-01",
      "content-type": "application/json",
    },
    body: JSON.stringify({ model: MODEL, ...body }),
    signal: AbortSignal.timeout(timeoutMs),
  });
}

async function callClaude(
  rawKey: string,
  body: Record<string, unknown>,
  timeoutMs: number,
  label: string,
): Promise<any | null> {
  const key = cleanKey(rawKey);
  if (!key) {
    console.error("[deytra-ai] clave con formato inválido");
    return null;
  }
  const started = Date.now();
  try {
    // Sin razonamiento extendido: respuestas cortas y rápidas, sin gastar la salida pensando.
    let res = await post(key, { ...body, thinking: { type: "disabled" } }, timeoutMs);
    if (res.status === 400) {
      // Si el modelo no acepta desactivarlo, se reintenta igual pero con más margen de salida.
      const max = Number(body.max_tokens ?? 1000);
      res = await post(
        key,
        { ...body, max_tokens: Math.max(max * 4, 4000) },
        Math.max(1000, timeoutMs - (Date.now() - started)),
      );
    }
    if (!res.ok) {
      let kind = "";
      try {
        kind = String((await res.json())?.error?.type ?? "").slice(0, 60);
      } catch { /* sin cuerpo */ }
      console.error("[deytra-ai]", label, "status", res.status, kind);
      return null;
    }
    const msg = await res.json();
    const types = (msg?.content ?? []).map((b: any) => b?.type).join(",");
    console.log("[deytra-ai]", label, "ok", msg?.stop_reason, types, `${Date.now() - started}ms`);
    return msg;
  } catch (e) {
    // Nunca se registra el mensaje completo: podría contener la clave.
    console.error("[deytra-ai]", label, "request failed", (e as Error)?.name ?? "error");
    return null;
  }
}

function textOf(msg: any): string {
  return (msg?.content ?? [])
    .filter((b: any) => b?.type === "text" && typeof b.text === "string")
    .map((b: any) => b.text)
    .join("\n");
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
  key: string | undefined,
  text: string,
  profileCity: string | null,
  categories: { slug: string; name: string }[],
): Promise<AiIntent | null> {
  if (!key) return null;
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
  const msg = await callClaude(
    key,
    { max_tokens: 600, system, messages: [{ role: "user", content: user }] },
    12000,
    "interpret",
  );
  const data = firstJson(textOf(msg), "{");
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

/** Busca en internet negocios o cuentas reales. Solo devuelve links que aparecieron en la búsqueda. */
export async function aiWebSuggestions(
  key: string | undefined,
  need: string,
  query: string,
  city: string | null,
  province: string | null,
  nationwide: boolean,
): Promise<Suggestion[] | null> {
  if (!key || !query) return null;
  const where = nationwide
    ? "con envío o atención a todo el país"
    : city
      ? `en ${city}${province ? `, ${province}` : ""} o alrededores`
      : "en Argentina";
  const system =
    "Sos la guía de Deytra. Buscá en internet opciones reales para resolver la necesidad de la persona y respondé SOLO un arreglo JSON (sin texto extra) de hasta 4 objetos con: " +
    '"name" (nombre del negocio, tienda, profesional o cuenta), "url" (el link exacto que encontraste en los resultados: sitio web, tienda online o perfil de Instagram), ' +
    '"description" (qué ofrece y por qué sirve, máximo 140 caracteres, en español rioplatense), ' +
    '"kind" (tienda, negocio, instagram o profesional), "scope" (local o nacional). ' +
    "Priorizá opciones argentinas, con datos verificables y vigentes. No incluyas directorios genéricos, notas periodísticas ni marketplaces enteros como opción. " +
    "Si no encontrás nada confiable, devolvé [].";
  const user = `Necesidad: """${need.slice(0, 600)}"""\nBuscá: ${query} ${where}`;
  const tool: Record<string, unknown> = {
    type: "web_search_20250305",
    name: "web_search",
    max_uses: 2,
    user_location: {
      type: "approximate",
      country: "AR",
      timezone: "America/Argentina/Buenos_Aires",
      ...(city && !nationwide ? { city } : {}),
      ...(province && !nationwide ? { region: province } : {}),
    },
  };
  const msg = await callClaude(
    key,
    { max_tokens: 2000, system, messages: [{ role: "user", content: user }], tools: [tool] },
    35000,
    "web",
  );
  if (!msg) return null;
  // Links realmente vistos en los resultados: evita links inventados.
  const seen = new Set<string>();
  for (const block of msg.content ?? []) {
    if (block?.type === "web_search_tool_result" && Array.isArray(block.content)) {
      for (const r of block.content) {
        try {
          if (r?.url) seen.add(new URL(r.url).hostname.replace(/^www\./, ""));
        } catch { /* url inválida */ }
      }
    }
    for (const c of block?.citations ?? []) {
      try {
        if (c?.url) seen.add(new URL(c.url).hostname.replace(/^www\./, ""));
      } catch { /* url inválida */ }
    }
  }
  const list = firstJson(textOf(msg), "[");
  if (!Array.isArray(list)) {
    console.log("[deytra-ai] web sin lista", seen.size, "sitios vistos");
    return [];
  }
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
