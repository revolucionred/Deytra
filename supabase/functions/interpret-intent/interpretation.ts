export type Intent = {
  language: "es" | "en";
  direction: "seek" | "offer";
  object_type:
    | "service"
    | "product"
    | "job_opportunity"
    | "venue"
    | "collaboration"
    | "other";
  category_raw: string;
  category_slug?: string;
  category_slugs?: string[];
  latitude?: number;
  longitude?: number;
  radius_km?: number;
  province?: string | null;
  ships_nationwide?: boolean;
  location_source?: "stated" | "profile" | "none";
  understood_by?: "ai" | "rules";
  modality: "presencial" | "remoto" | "hibrido" | "no_aplica";
  location_raw?: string;
  city?: string;
  geocode_status: "none" | "ambiguous" | "resolved";
  location_importance: "required" | "preferred" | "indifferent";
  urgency: "asap" | "flexible" | "unspecified";
  time_raw?: string;
  time_window_start?: string;
  time_window_end?: string;
  budget_min?: number;
  budget_max?: number;
  currency?: string;
  budget_raw?: string;
  quantity?: number;
  quantity_unit?: string;
  needs_clarification: boolean;
  clarification_question?: string;
  missing_fields: string[];
  confidence: number;
};
const JSON_HEADERS = { "content-type": "application/json; charset=utf-8" };
const MAX_TEXT = 2000;
const CATEGORY_RULES: [string, RegExp][] = [
  [
    "fotografia-producto",
    /fot[oó]graf(?:o|a|ía).*(producto|e-?commerce)|producto.*fot[oó]graf|product\s+photo/i,
  ],
  ["fotografia", /fot[oó]graf|photo(graph|grapher)?/i],
  ["video", /video|filmaci[oó]n|vide[oó]grafo/i],
  ["audiovisual", /audiovisual|producci[oó]n audiovisual/i],
  ["marketing", /marketing|publicidad|campaign/i],
  [
    "redes-sociales",
    /redes sociales|social media|community manager|instagram|tiktok/i,
  ],
  ["diseno-grafico", /diseñ[oa]|diseño gr[aá]fico|graphic design/i],
  ["branding", /branding|marca|identidad visual/i],
  [
    "desarrollo-web",
    /p[aá]gina web|sitio web|website|web developer|desarrollo web/i,
  ],
  ["programacion", /programador|developer|software|app\b/i],
  ["eventos", /evento|sal[oó]n|catering|fiesta/i],
  ["gastronomia", /comida|catering|chef|gastronom/i],
  ["limpieza", /limpieza|cleaning/i],
  ["plomeria", /plomer|plumb/i],
  ["electricidad", /electricista|electrical/i],
  ["construccion", /construcci[oó]n|albañil|obra\b/i],
  ["salud", /m[eé]dic|salud|kinesi|psic[oó]log|doctor|health/i],
  ["educacion", /profesor|clases|teacher|tutor|educaci[oó]n/i],
  ["idiomas", /ingl[eé]s|idioma|english|language/i],
  ["legal", /abogad|legal|lawyer/i],
  ["contabilidad", /contador|contable|accountant/i],
  ["belleza", /maquill|peluquer|estetic|beauty/i],
  ["transporte", /flete|transporte|chofer|driver|mudanza/i],
  ["turismo", /viaje|turismo|travel/i],
  ["inmobiliaria", /departamento|casa|alquiler|inmobili|property|apartment/i],
  ["ventas", /vendedor|ventas|sales/i],
  ["empleo", /empleado|trabajo|vacante|puesto|job|employee|hire|hiring/i],
];
// v8: necesidades cotidianas de particulares -> varias categorías posibles.
// El orden importa: la primera categoría es la principal.
const NEED_RULES: [RegExp, string[]][] = [
  [/patio|jard[ií]n|parque|c[eé]sped|pasto|cortar el pasto|poda|plantas?\b|vivero|huerta/i,
    ["jardineria", "paisajismo", "viveros-plantas", "hogar-jardin"]],
  [/decorar|decoraci[oó]n|ambientar|living|dormitorio|interiorismo/i,
    ["decoracion", "hogar-jardin", "carpinteria", "pintura"]],
  [/pintar|pintor|pintura de (la )?(casa|pared)/i, ["pintura", "reparaciones"]],
  [/carpinter|mueble|placard|estanter/i, ["carpinteria", "reparaciones"]],
  [/herrer|reja|port[oó]n/i, ["herreria", "reparaciones"]],
  [/arregl|repar|cambiar (una|la) |se rompi[oó]|gotea|canilla|enchufe/i,
    ["reparaciones", "plomeria", "electricidad"]],
  [/mudanza|mudarme|flete/i, ["mudanzas", "transporte"]],
  [/comer (m[aá]s )?(sano|saludable)|(comida|vida) saludable|dieta|alimentaci[oó]n|bajar de peso|nutricion|nutri[oó]log/i,
    ["nutricion", "comida-casera", "recetas-contenido", "deporte-entrenamiento"]],
  [/vianda|comida (para|de) (toda )?la semana|cocine (para|en)|comida casera|tupper/i,
    ["comida-casera", "nutricion"]],
  [/receta|cocinar|aprender a cocinar/i, ["recetas-contenido", "comida-casera", "clases-particulares"]],
  [/torta|pasteler|cumplea[nñ]os.*(torta|mesa dulce)|mesa dulce|reposter/i, ["reposteria", "eventos"]],
  [/entrenar|gimnasio|entrenador|personal trainer|correr|ponerme en forma|yoga|pilates/i,
    ["deporte-entrenamiento", "bienestar"]],
  [/guitarra|piano|canto|m[uú]sic|banda|dj\b/i, ["musica", "clases-particulares", "eventos"]],
  [/clases? de|apoyo escolar|aprender|profe(sor)? particular/i, ["clases-particulares", "educacion"]],
  [/ni[nñ]era|cuidar (a )?(mi|mis) (hijo|hija|nene|nena)|cuidado de ni[nñ]os/i, ["cuidado-ninos"]],
  [/cuidar (a )?(mi )?(abuel|mam[aá]|pap[aá])|acompa[nñ]ante|cuidado de (adultos|mayores)/i, ["cuidado-mayores", "salud"]],
  [/perro|gato|mascota|paseador|veterinari|peluquer[ií]a canina/i, ["mascotas"]],
  [/auto|mec[aá]nic|chapa|gomer[ií]a|service del auto/i, ["autos-mecanica"]],
  [/costur|modista|arreglo de ropa|ropa a medida/i, ["moda-costura"]],
  [/manualidad|cer[aá]mica|pintura art[ií]stica|taller de arte/i, ["arte-manualidades", "clases-particulares"]],
  [/emprendimiento|mi negocio|mi marca|comunicaci[oó]n|redes de mi/i,
    ["comunicacion-negocios", "redes-sociales", "marketing", "agencias", "diseno-grafico", "creadores-contenido"]],
  [/influencer|creador(a)? de contenido|cuenta(s)? de instagram|tiktoker|youtuber/i, ["creadores-contenido"]],
  [/tr[aá]mite|gestor[ií]a|papeles|registro automotor/i, ["tramites", "legal"]],
];
export function cors(origin: string | null) {
  const allowed =
    !origin ||
    /^https?:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/.test(origin) ||
    /^https:\/\/[a-z0-9-]+\.(flutterflow\.app|flutterflow\.io)$/.test(origin);
  return {
    allowed,
    headers: {
      ...JSON_HEADERS,
      "access-control-allow-origin":
        origin && allowed ? origin : "https://app.flutterflow.io",
      "access-control-allow-headers":
        "authorization, apikey, content-type, x-client-info",
      "access-control-allow-methods": "POST, OPTIONS",
      vary: "Origin",
    },
  };
}
export function reply(
  status: number,
  body: unknown,
  headers: Record<string, string>,
) {
  return new Response(JSON.stringify(body), { status, headers });
}
export function validTz(tz: string) {
  try {
    new Intl.DateTimeFormat("en-US", { timeZone: tz }).format(new Date());
    return !!tz && tz.length <= 64;
  } catch {
    return false;
  }
}
export function norm(s: string) {
  return s
    .normalize("NFD")
    .replace(/\p{Diacritic}/gu, "")
    .toLowerCase()
    .trim();
}
function detectLanguage(s: string): "es" | "en" {
  return /\b(need|looking|hire|job|tomorrow|today|in person|remote)\b/i.test(s)
    ? "en"
    : "es";
}
function needCategories(text: string): string[] {
  const out: string[] = [];
  for (const [re, slugs] of NEED_RULES)
    if (re.test(text)) for (const s of slugs) if (!out.includes(s)) out.push(s);
  return out.slice(0, 8);
}
function categories(text: string): string[] {
  // v8: primero la necesidad cotidiana ("decorar mi casa" no es inmobiliaria);
  // si no hay, la regla de oficio específica de v7.
  const need = needCategories(text);
  if (need.length) return need;
  for (const [slug, re] of CATEGORY_RULES) if (re.test(text)) return [slug];
  return [];
}
function category(text: string) {
  return categories(text)[0];
}
function objectType(t: string) {
  if (/\b(trabajo|empleado|vacante|puesto|job|employee|hire|hiring)\b/i.test(t))
    return "job_opportunity" as const;
  if (
    /fot[oó]graf|vide[oó]graf|diseñ|contador|abogad|plomer|electricista|programador|developer|community manager|marketing|limpieza|catering|chef|profesor|teacher|kinesi|psic[oó]log|m[eé]dic/i.test(
      t,
    )
  )
    return "service" as const;
  if (
    /\b(departamento|casa|sal[oó]n|espacio|local|venue|apartment|property)\b/i.test(
      t,
    )
  )
    return "venue" as const;
  if (
    /\b(auto|coche|celular|producto|comprar|vender|buyer|car|phone|product)\b/i.test(
      t,
    )
  )
    return "product" as const;
  if (/\b(socio|colabor|inversor|partner|collaborat|investor)\b/i.test(t))
    return "collaboration" as const;
  return "service" as const;
}
function direction(t: string, obj: Intent["object_type"]) {
  if (obj === "job_opportunity")
    return /\b(empleado|personal|vacante|contratar|hiring|hire|employee|publicamos)\b/i.test(
      t,
    )
      ? "offer"
      : "seek";
  if (obj === "product")
    return /\b(comprador|vendo|vender|ofrezco|buyer|selling|sell)\b/i.test(t)
      ? "offer"
      : "seek";
  if (obj === "venue")
    return /\b(inquilino|alquilo mi|ofrezco|tenant|rent out)\b/i.test(t)
      ? "offer"
      : "seek";
  if (obj === "service")
    return /\b(clientes|ofrezco|brindo|soy (?:fot[oó]graf|contador|diseñ|program)|clients|i offer|my services)\b/i.test(
      t,
    )
      ? "offer"
      : "seek";
  return /\b(ofrezco|offer|vendo|selling)\b/i.test(t) ? "offer" : "seek";
}
const KNOWN_CITIES = [
  "Carcarañá", "Rosario", "Funes", "Roldán", "Pérez", "Granadero Baigorria",
  "Villa Gobernador Gálvez", "Cañada de Gómez", "San Lorenzo", "Capitán Bermúdez",
  "Santa Fe", "Rafaela", "Venado Tuerto", "Córdoba", "Villa Carlos Paz",
  "Buenos Aires", "CABA", "La Plata", "Mar del Plata", "Bahía Blanca", "Mendoza",
  "Tucumán", "Salta", "Neuquén", "Paraná", "Montevideo", "Punta del Este",
];
function extractCity(t: string) {
  const low = norm(t);
  // La más larga primero ("Villa Gobernador Gálvez" antes que "Gálvez").
  for (const c of [...KNOWN_CITIES].sort((a, b) => b.length - a.length))
    if (new RegExp(`(^|[^a-z])${norm(c)}([^a-z]|$)`).test(low)) return c;
  const m = t.match(
    /\b(?:en|in)\s+([A-ZÁÉÍÓÚÑ][\p{L}.-]+(?:\s+[A-ZÁÉÍÓÚÑ][\p{L}.-]+){0,2})/u,
  );
  return m?.[1]?.trim();
}
function parseMoney(t: string) {
  const m =
    t.match(
      /(?:hasta|max(?:imo)?|presupuesto(?: de)?|budget(?: of)?|\$)\s*\$?\s*([\d.]+(?:,\d+)?)/i,
    ) || t.match(/\$\s*([\d.]+(?:,\d+)?)/);
  if (!m) return {};
  const raw = m[1];
  const n =
    raw.includes(".") && !raw.includes(",")
      ? Number(raw.replace(/\./g, ""))
      : Number(raw.replace(/\./g, "").replace(",", "."));
  return Number.isFinite(n) ? { budget_max: n, budget_raw: m[0] } : {};
}
function parseQuantity(t: string) {
  const m = t.match(/\b(\d+)\s*(personas?|people|unidades?|units?)\b/i);
  return m ? { quantity: Number(m[1]), quantity_unit: m[2] } : {};
}
function localParts(now: Date, tz: string) {
  const parts = new Intl.DateTimeFormat("en-CA", {
    timeZone: tz,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).formatToParts(now);
  const get = (x: string) => Number(parts.find((p) => p.type === x)?.value);
  return { y: get("year"), m: get("month"), d: get("day") };
}
function offsetAt(date: Date, tz: string) {
  const p = new Intl.DateTimeFormat("en-US", {
    timeZone: tz,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    second: "2-digit",
    hourCycle: "h23",
  }).formatToParts(date);
  const g = (x: string) => Number(p.find((v) => v.type === x)?.value);
  return (
    Date.UTC(
      g("year"),
      g("month") - 1,
      g("day"),
      g("hour"),
      g("minute"),
      g("second"),
    ) - date.getTime()
  );
}
function zonedToUtc(
  y: number,
  m: number,
  d: number,
  h: number,
  min: number,
  tz: string,
) {
  let guess = new Date(Date.UTC(y, m - 1, d, h, min));
  for (let i = 0; i < 2; i++)
    guess = new Date(Date.UTC(y, m - 1, d, h, min) - offsetAt(guess, tz));
  return guess;
}
function temporal(t: string, tz: string) {
  const low = norm(t);
  const now = new Date();
  let add = 0;
  if (/\bmanana\b|\btomorrow\b/.test(low)) add = 1;
  else if (/\bhoy\b|\btoday\b/.test(low)) add = 0;
  else return {};
  const p = localParts(now, tz);
  const base = new Date(Date.UTC(p.y, p.m - 1, p.d + add));
  const y = base.getUTCFullYear(),
    m = base.getUTCMonth() + 1,
    d = base.getUTCDate();
  let h1 = 9,
    h2 = 18;
  if (/\btarde\b|\bafternoon\b/.test(low)) {
    h1 = 12;
    h2 = 18;
  } else if (/\bmorning\b/.test(low)) {
    h1 = 8;
    h2 = 12;
  } else if (/\bnoche\b|\bevening\b|\bnight\b/.test(low)) {
    h1 = 18;
    h2 = 23;
  }
  return {
    time_raw:
      add === 1
        ? low.includes("tomorrow")
          ? "tomorrow"
          : "mañana"
        : low.includes("today")
          ? "today"
          : "hoy",
    time_window_start: zonedToUtc(y, m, d, h1, 0, tz).toISOString(),
    time_window_end: zonedToUtc(y, m, d, h2, 0, tz).toISOString(),
  };
}
export function interpret(
  text: string,
  tz: string,
  locale?: "es" | "en",
): Intent {
  const language = locale ?? detectLanguage(text);
  // v8: las necesidades cotidianas se resuelven con personas que ofrecen un servicio.
  const obj = needCategories(text).length ? ("service" as const) : objectType(text);
  const dir = direction(text, obj);
  const slugs = categories(text);
  const slug = slugs[0];
  const city = extractCity(text);
  let modality: Intent["modality"] = /\b(remoto|remote|online)\b/i.test(text)
    ? "remoto"
    : /\b(hibrid|hybrid)\b/i.test(text)
      ? "hibrido"
      : /\b(presencial|in person)\b/i.test(text)
        ? "presencial"
        : "no_aplica";
  const physical =
    /fot[oó]graf|plomer|electricista|limpieza|catering|sal[oó]n|mudanza|construcci[oó]n|patio|jard[ií]n|pasto|poda|pint(ar|or)|carpinter|herrer|arregl|repar|flete|ni[nñ]era|cuidar|paseador|mec[aá]nic|vianda/i.test(
      text,
    );
  if (modality === "no_aplica" && physical) modality = "presencial";
  const location_importance =
    modality === "presencial" ? "required" : "indifferent";
  const tm = temporal(text, tz);
  const money = parseMoney(text);
  const qty = parseQuantity(text);
  const missing: string[] = [];
  if (!slug) missing.push("category");
  if (location_importance === "required" && !city) missing.push("location");
  if (!(money as any).budget_max) missing.push("budget");
  if (!(qty as any).quantity) missing.push("quantity");
  const needs = !slug || (location_importance === "required" && !city);
  let question: string | undefined;
  if (!slug)
    question =
      language === "en"
        ? "Could you tell me a bit more about what you're looking for?"
        : "¿Podés contarme un poco más sobre qué necesitás?";
  else if (location_importance === "required" && !city)
    question =
      language === "en"
        ? "Where do you need this?"
        : "¿En qué ciudad o zona lo necesitás?";
  return {
    language,
    direction: dir,
    object_type: obj,
    category_raw: slug ?? text.slice(0, 120),
    category_slug: slug,
    category_slugs: slugs,
    modality,
    location_raw: city,
    city,
    geocode_status: city ? "ambiguous" : "none",
    location_importance,
    urgency: /\b(urgente|ya|ahora|asap|urgent)\b/i.test(text)
      ? "asap"
      : "unspecified",
    ...tm,
    ...money,
    ...qty,
    needs_clarification: needs,
    clarification_question: question,
    missing_fields: missing,
    confidence: slug ? 0.82 : 0.45,
  };
}
function lexical(a: string, b: string) {
  const A = new Set(
      norm(a)
        .split(/\W+/)
        .filter((x) => x.length > 2),
    ),
    B = new Set(
      norm(b)
        .split(/\W+/)
        .filter((x) => x.length > 2),
    );
  if (!A.size || !B.size) return 0;
  let n = 0;
  for (const x of A) if (B.has(x)) n++;
  return n / Math.max(A.size, B.size);
}
