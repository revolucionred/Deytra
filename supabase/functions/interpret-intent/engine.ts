// ============================================================================
// Prototipo del motor de matching. TypeScript puro, sin dependencia de Deno
// ni de Supabase — corre en Node para poder testearlo rápido con datos
// sintéticos. NO escribe nada en `public.matches` todavía (Fase 7: prototipo).
//
// Regla fundamental (innegociable): los hard constraints eliminan candidatos
// ANTES del ranking. Un candidato que no pasa un hard constraint nunca
// aparece en el resultado, sin importar qué tan alto sea su score semántico.
// ============================================================================

export type Modality = "presencial" | "remoto" | "hibrido" | "no_aplica";

// v2.1, punto 9 de la revisión externa: operadores semánticos mínimos, en vez de
// solo igualdad de string. `eq` sigue siendo el default (ver ConstraintOperatorSchema
// en intent_contract_v2.ts) para no romper los constraints que no declaran operator.
export type ConstraintOperator = "eq" | "gte" | "lte" | "contains" | "in";

export interface IntentConstraint {
  key: string;
  operator?: ConstraintOperator; // ausente = "eq", igual que en el schema Zod
  value: string | number | boolean | Array<string | number>;
  hardness: "hard" | "soft";
}

export interface MatchIntent {
  raw_text: string;
  category_raw: string;
  category_slug?: string;
  // v2.2, punto 1 de la revisión externa: category_id es la referencia CANÓNICA
  // (FK real a categories.id) — category_slug queda como representación estable
  // derivada, usada por interpretación/transporte y como fallback de matching
  // cuando category_id todavía no se resolvió (ver checkHardConstraints). En la
  // candidate generation SQL real (docs/10_intent_contract_v2_1.md, sección
  // candidate generation), el filtro de categoría en el WHERE ya usa category_id
  // — este campo en TypeScript es la misma fuente de verdad, no una paralela.
  category_id?: string | null;
  object_type: string;
  modality: Modality;
  location_importance: "required" | "preferred" | "indifferent";
  city?: string;
  latitude?: number;
  longitude?: number;
  radius_km?: number;
  budget_max?: number;
  currency?: string | null;
  urgency: "asap" | "flexible" | "unspecified";
  // v2.1, punto 10: `quantity`/`quantity_unit` ahora llegan al MatchIntent en vez de
  // perderse en la traducción StructuredIntentV2 -> MatchIntent (ver matching/src/from_intent.ts).
  quantity?: number;
  quantity_unit?: string;
  temporal_window_start?: string;
  temporal_window_end?: string;
  // v2.1, punto 8: cuándo la disponibilidad en esa ventana es un REQUISITO (hard
  // filter) y no solo un dato para rankear. Análogo a location_importance='required'
  // pero para tiempo. Ver matching/src/from_intent.ts para cómo se deriva de un
  // StructuredIntentV2 real (urgency='asap' o hay un window_start concreto).
  temporal_required?: boolean;
  constraints: IntentConstraint[];
}

// v2.2, punto 3 de la revisión externa: en el modelo real, esto representa una
// FILA DE `entity_capabilities` (una oferta/capacidad concreta de una entidad),
// NO la entidad completa — una entidad puede tener varias capacidades distintas
// (categoría, modalidad, ubicación y precio propios de CADA una), y no tiene
// sentido "aplanarlas" en una sola fila con arrays de todo. `id` acá es el id de
// la capability (`entity_capabilities.id`), no el id de la entidad — por eso
// existe `entity_id` como campo separado (necesario para poder resolver, más
// adelante, a qué entidad real pertenece esta capability y armar `matches` con
// `target_entity_id` + `target_capability_id`, ver punto 4). El catálogo sintético
// de matching/__tests__/scenarios.js sigue usando `category_slugs` (plural) como
// atajo de test para representar "esta entidad de test cubre estas categorías"
// sin modelar explícitamente varias capabilities por entidad — es una
// simplificación de test, documentada acá para que no se lea como el modelo real.
export interface CandidateEntity {
  id: string; // entity_capabilities.id en el modelo real (ver nota arriba)
  entity_id?: string; // entities.id dueña de esta capability — necesario para matches.target_entity_id
  name: string;
  category_slugs: string[]; // categorías que puede atender (ver nota de la interfaz sobre el alcance de test)
  // v2.2, punto 1: category_id resuelto (FK real) de ESTA capability — cuando está
  // presente, es la fuente de verdad preferida para el hard filter de categoría
  // (ver checkHardConstraints). Opcional porque el catálogo sintético de test no
  // lo declara (no hay categories reales en el sandbox) — sin él, el filtro cae
  // al comportamiento existente por category_slugs/category_raw, sin romper nada.
  category_id?: string | null;
  modality_supported: Modality[];
  city?: string;
  latitude?: number;
  longitude?: number;
  service_radius_km?: number; // hasta dónde viaja, si es presencial
  price_min?: number;
  price_max?: number;
  currency?: string;
  availability?: { start: string; end: string }[]; // ventanas ISO en las que el candidato está disponible
  attributes: Record<string, string | number | boolean>; // para chequear constraints hard/soft
  description: string; // texto libre, usado para el score semántico mock
  quality_score?: number; // 0..1, proxy de completitud de perfil
}

export interface Weights {
  category: number;
  distance: number;
  modality: number;
  softConstraints: number;
  semantic: number;
  completeness: number;
}

// EXPERIMENTAL — no son pesos "científicos", son un punto de partida razonable
// para testing. Deben calibrarse con datos reales antes de producción (ver
// checkpoint anterior, sección 6 / decisión pendiente de Sol).
export const DEFAULT_WEIGHTS: Weights = {
  category: 0.3,
  distance: 0.2,
  modality: 0.15,
  softConstraints: 0.15,
  semantic: 0.1,
  completeness: 0.1,
};

export interface ScoredCandidate {
  candidate: CandidateEntity;
  hard_constraints_passed: true; // si llegó acá, ya pasó todos los hard constraints
  score: number;
  score_breakdown: Record<string, number>;
  explanation: string[];
}

export interface RejectedCandidate {
  candidate: CandidateEntity;
  hard_constraints_passed: false;
  rejected_reason: string;
}

export interface MatchResult {
  accepted: ScoredCandidate[]; // ordenados por score desc
  rejected: RejectedCandidate[]; // para debug/explicabilidad, no se muestran al usuario
}

function haversineKm(
  lat1: number,
  lon1: number,
  lat2: number,
  lon2: number,
): number {
  const R = 6371;
  const dLat = ((lat2 - lat1) * Math.PI) / 180;
  const dLon = ((lon2 - lon1) * Math.PI) / 180;
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos((lat1 * Math.PI) / 180) *
      Math.cos((lat2 * Math.PI) / 180) *
      Math.sin(dLon / 2) ** 2;
  return R * 2 * Math.asin(Math.sqrt(a));
}

// Score semántico MOCK: similaridad de palabras (Jaccard) entre el texto del intent
// y la descripción del candidato. Placeholder documentado explícitamente para
// embeddings reales (pgvector) más adelante — NO se presenta como IA real.
function mockSemanticScore(intentText: string, candidateText: string): number {
  const tokenize = (s: string) =>
    new Set(s.toLowerCase().match(/[a-záéíóúñ]+/gi) ?? []);
  const a = tokenize(intentText);
  const b = tokenize(candidateText);
  if (a.size === 0 || b.size === 0) return 0;
  let intersection = 0;
  for (const t of a) if (b.has(t)) intersection++;
  const union = new Set([...a, ...b]).size;
  return union === 0 ? 0 : intersection / union;
}

// Quita acentos para comparar "plomería" con el slug "plomeria", "diseño" con "diseno", etc.
function normalizeForCompare(s: string): string {
  return s.normalize("NFD").replace(/[̀-ͯ]/g, "").toLowerCase();
}

// Un slug tipo "cuidado-infantil" matchea el category_raw en texto libre si TODAS sus
// palabras (separadas por guion) aparecen en el texto — no alcanza con que aparezca una
// sola palabra suelta y ambigua.
function categoryRawMatchesSlug(categoryRaw: string, slug: string): boolean {
  const raw = normalizeForCompare(categoryRaw);
  const normalizedSlug = normalizeForCompare(slug);
  if (raw.includes(normalizedSlug)) return true; // frase completa presente (con o sin guiones)
  const slugWords = normalizedSlug.split("-").filter(Boolean);
  return slugWords.length > 0 && slugWords.every((w) => raw.includes(w));
}

// v2.1, punto 9: evalúa un constraint contra un valor de atributo del candidato,
// según su operador. Único punto de la lógica de operadores — usado tanto para
// hard constraints (checkHardConstraints) como para soft (scoreCandidate), para
// no duplicar la semántica de cada operador en dos lugares.
function evaluateConstraint(attrValue: unknown, c: IntentConstraint): boolean {
  if (attrValue == null) return false;
  const op = c.operator ?? "eq";
  switch (op) {
    case "gte":
      return (
        typeof attrValue === "number" &&
        typeof c.value === "number" &&
        attrValue >= c.value
      );
    case "lte":
      return (
        typeof attrValue === "number" &&
        typeof c.value === "number" &&
        attrValue <= c.value
      );
    case "contains":
      return (
        typeof c.value === "string" &&
        String(attrValue).toLowerCase().includes(c.value.toLowerCase())
      );
    case "in":
      return (
        Array.isArray(c.value) &&
        c.value.some(
          (v) => String(v).toLowerCase() === String(attrValue).toLowerCase(),
        )
      );
    case "eq":
    default:
      if (typeof c.value === "boolean") return Boolean(attrValue) === c.value;
      if (Array.isArray(c.value)) return false; // 'eq' contra un array no tiene semántica definida — usar 'in'
      return String(attrValue).toLowerCase() === String(c.value).toLowerCase();
  }
}

// v2.1, punto 8: ¿el candidato tiene alguna ventana de disponibilidad que cubra la
// ventana requerida por el intent? Ausencia total de `availability` en el candidato
// se trata como "no hay dato" (no rechaza) — rechazar automáticamente a todo
// candidato sin `availability` declarada sería demasiado agresivo mientras la
// mayoría de los perfiles no cargan ese dato todavía; lo que SÍ rechaza es un
// candidato que declaró sus ventanas y ninguna cubre lo pedido.
function hasCompatibleAvailability(
  intent: MatchIntent,
  candidate: CandidateEntity,
): boolean {
  if (!candidate.availability || candidate.availability.length === 0)
    return true; // sin dato = no se rechaza
  if (!intent.temporal_window_start) return true; // no hay ventana concreta que chequear
  const reqStart = new Date(intent.temporal_window_start).getTime();
  const reqEnd = intent.temporal_window_end
    ? new Date(intent.temporal_window_end).getTime()
    : reqStart;
  return candidate.availability.some((w) => {
    const wStart = new Date(w.start).getTime();
    const wEnd = new Date(w.end).getTime();
    if (
      ![reqStart, reqEnd, wStart, wEnd].every(Number.isFinite) ||
      wEnd <= wStart ||
      reqEnd < reqStart
    )
      return false;
    // Positive-duration ranges are half-open: touching endpoints are not availability.
    return reqEnd === reqStart
      ? wStart <= reqStart && wEnd > reqStart
      : wStart < reqEnd && wEnd > reqStart;
  });
}

function checkHardConstraints(
  intent: MatchIntent,
  candidate: CandidateEntity,
): string | null {
  // 1. categoría — BUG REAL corregido en Fase 7 (encontrado vía los escenarios de
  // matching): la condición anterior era "!intent.category_slug || ...", que dejaba
  // pasar CUALQUIER candidato entero cuando el intent no traía category_slug todavía
  // resuelto (el caso más común: el mock/IA solo da category_raw en texto libre).
  // Sin category_slug, ahora se exige que el category_raw coincida con alguno de los
  // category_slugs del candidato (por frase completa o por todas sus palabras).
  //
  // BUG REAL #2 corregido en v2.1 (segunda pasada de revisión externa, encontrado vía
  // los escenarios #13/#14 sintéticos agregados para el punto 8): cuando el intent SÍ
  // trae un category_slug resuelto y específico (ej. "fotografia-producto"), la versión
  // anterior igual hacía un OR con el fallback de texto libre contra CADA slug del
  // candidato — así que un candidato que solo ofrece la categoría amplia "fotografia"
  // (sin "fotografia-producto") terminaba pasando igual, porque category_raw genérico
  // ("fotografía") matchea en texto libre contra el slug amplio "fotografia" de ESE
  // candidato, sin importar que el slug específico resuelto no coincida. Eso vuelve
  // inútil la resolución de category_slug específica apenas category_raw es genérico.
  // Ahora: con category_slug resuelto, la igualdad de slug es la ÚNICA fuente de verdad
  // (coincidencia exacta, sin fallback de texto libre) — el fallback de texto libre
  // queda reservado exclusivamente al caso sin category_slug en absoluto.
  // v2.2, punto 1: category_id (FK real) es la fuente de verdad PREFERIDA cuando
  // ambos lados (intent y candidate) lo tienen resuelto — igualdad exacta de UUID,
  // sin ninguna heurística de texto de por medio. Solo cuando falta de un lado o
  // del otro (candidate de test sin category_id, o intent cuyo category_slug
  // propuesto no resolvió contra `categories`) se cae al comportamiento existente
  // por category_slug/category_raw — así el fix del bug real #6 (ver más abajo)
  // sigue vigente para ese camino de fallback, no se duplica la lógica.
  const categoryOk =
    intent.category_id && candidate.category_id
      ? intent.category_id === candidate.category_id
      : intent.category_slug
        ? candidate.category_slugs.includes(intent.category_slug)
        : candidate.category_slugs.some((c) =>
            categoryRawMatchesSlug(intent.category_raw, c),
          );
  if (!categoryOk)
    return `categoría no coincide (busca "${intent.category_raw}"${intent.category_slug ? ` / slug "${intent.category_slug}"` : ""}${intent.category_id ? ` / category_id "${intent.category_id}"` : ""}, candidato ofrece [${candidate.category_slugs.join(", ")}]${candidate.category_id ? ` / category_id "${candidate.category_id}"` : ""})`;

  // 2. modalidad
  if (
    intent.modality !== "no_aplica" &&
    !candidate.modality_supported.includes(intent.modality)
  ) {
    return `modalidad incompatible (intent requiere ${intent.modality}, candidato soporta [${candidate.modality_supported.join(", ")}])`;
  }

  // 3. ubicación obligatoria (presencial + required)
  if (
    intent.modality === "presencial" &&
    intent.location_importance === "required"
  ) {
    if (
      intent.latitude != null &&
      intent.longitude != null &&
      candidate.latitude != null &&
      candidate.longitude != null
    ) {
      const dist = haversineKm(
        intent.latitude,
        intent.longitude,
        candidate.latitude,
        candidate.longitude,
      );
      const maxDist = intent.radius_km ?? candidate.service_radius_km ?? 30;
      if (dist > maxDist)
        return `fuera de rango (${dist.toFixed(1)}km > ${maxDist}km permitidos)`;
    } else if (
      intent.city &&
      candidate.city &&
      intent.city.toLowerCase() !== candidate.city.toLowerCase()
    ) {
      return `ciudad no coincide (intent="${intent.city}", candidato="${candidate.city}")`;
    } else if (!intent.city && !intent.latitude) {
      return "ubicación requerida pero el intent no la especifica (no debería llegar acá si needs_clarification funcionó bien)";
    }
  }

  // 4. presupuesto
  if (intent.budget_max != null && candidate.price_min != null) {
    const sameCurrency =
      !intent.currency ||
      !candidate.currency ||
      intent.currency === candidate.currency;
    if (sameCurrency && candidate.price_min > intent.budget_max) {
      return `precio mínimo del candidato (${candidate.price_min} ${candidate.currency ?? ""}) supera el presupuesto (${intent.budget_max} ${intent.currency ?? "moneda no especificada"})`;
    }
  }

  // 5. constraints hard explícitos (v2.1: vía evaluateConstraint, soporta operadores)
  for (const c of intent.constraints.filter((c) => c.hardness === "hard")) {
    const attrValue = candidate.attributes[c.key];
    if (attrValue == null)
      return `candidato no declara el atributo requerido "${c.key}"`;
    if (!evaluateConstraint(attrValue, c)) {
      return `atributo "${c.key}" no cumple (operador ${c.operator ?? "eq"}, requiere ${JSON.stringify(c.value)}, candidato tiene ${JSON.stringify(attrValue)})`;
    }
  }

  // 6. disponibilidad temporal (v2.1, punto 8) — solo bloquea cuando el intent la
  // marca explícitamente como requisito (temporal_required), igual que location_importance.
  if (
    intent.temporal_required &&
    !hasCompatibleAvailability(intent, candidate)
  ) {
    const windowLabel =
      intent.temporal_window_end &&
      intent.temporal_window_end !== intent.temporal_window_start
        ? `${intent.temporal_window_start} a ${intent.temporal_window_end}`
        : intent.temporal_window_start;
    return `sin disponibilidad en la ventana requerida (${windowLabel})`;
  }

  return null; // pasó todo
}

function scoreCandidate(
  intent: MatchIntent,
  candidate: CandidateEntity,
  weights: Weights,
): ScoredCandidate {
  const breakdown: Record<string, number> = {};
  const explanation: string[] = [];

  // categoría: 1.0 si coincide exacto por slug, 0.6 si coincide por texto libre
  breakdown.category =
    (intent.category_id && candidate.category_id === intent.category_id) ||
    (intent.category_slug &&
      candidate.category_slugs.includes(intent.category_slug))
      ? 1.0
      : 0.6;
  explanation.push(
    `Coincidencia de categoría: ${(breakdown.category * 100).toFixed(0)}%`,
  );

  // distancia
  if (
    intent.latitude != null &&
    intent.longitude != null &&
    candidate.latitude != null &&
    candidate.longitude != null
  ) {
    const dist = haversineKm(
      intent.latitude,
      intent.longitude,
      candidate.latitude,
      candidate.longitude,
    );
    const maxDist = intent.radius_km ?? candidate.service_radius_km ?? 30;
    breakdown.distance = Math.max(0, 1 - dist / (maxDist * 1.5));
    explanation.push(
      `A ${dist.toFixed(1)}km (score de distancia ${(breakdown.distance * 100).toFixed(0)}%)`,
    );
  } else {
    breakdown.distance = intent.modality === "remoto" ? 1.0 : 0.5; // remoto: la distancia no importa, se puntúa neutro-alto
  }

  // modalidad: bonus si el candidato soporta exactamente la modalidad pedida y nada más ambiguo
  breakdown.modality = candidate.modality_supported.includes(intent.modality)
    ? 1.0
    : 0.0;

  // soft constraints (v2.1: vía evaluateConstraint, misma semántica de operadores que los hard)
  const softs = intent.constraints.filter((c) => c.hardness === "soft");
  if (softs.length === 0) {
    breakdown.softConstraints = 0.5; // neutro: no hay info para premiar ni penalizar
  } else {
    const matched = softs.filter((c) =>
      evaluateConstraint(candidate.attributes[c.key], c),
    ).length;
    breakdown.softConstraints = matched / softs.length;
    explanation.push(
      `Cumple ${matched}/${softs.length} preferencias declaradas`,
    );
  }

  // semántico (mock)
  breakdown.semantic = mockSemanticScore(
    `${intent.raw_text} ${intent.category_raw}`,
    candidate.description,
  );

  // completitud de perfil
  breakdown.completeness = candidate.quality_score ?? 0.5;

  if (intent.quantity != null) {
    explanation.push(
      `Cantidad solicitada: ${intent.quantity}${intent.quantity_unit ? ` ${intent.quantity_unit}` : ""}`,
    );
  }

  const score =
    breakdown.category * weights.category +
    breakdown.distance * weights.distance +
    breakdown.modality * weights.modality +
    breakdown.softConstraints * weights.softConstraints +
    breakdown.semantic * weights.semantic +
    breakdown.completeness * weights.completeness;

  return {
    candidate,
    hard_constraints_passed: true,
    score: Math.round(score * 1000) / 1000,
    score_breakdown: breakdown,
    explanation,
  };
}

export function runMatching(
  intent: MatchIntent,
  catalog: CandidateEntity[],
  weights: Weights = DEFAULT_WEIGHTS,
): MatchResult {
  const accepted: ScoredCandidate[] = [];
  const rejected: RejectedCandidate[] = [];

  for (const candidate of catalog) {
    const rejection = checkHardConstraints(intent, candidate);
    if (rejection) {
      rejected.push({
        candidate,
        hard_constraints_passed: false,
        rejected_reason: rejection,
      });
      continue;
    }
    accepted.push(scoreCandidate(intent, candidate, weights));
  }

  accepted.sort((a, b) => b.score - a.score);
  return { accepted, rejected };
}
