import { createClient } from "npm:@supabase/supabase-js@2.117.2";
import { cors, reply, validTz, interpret, norm } from "./interpretation.ts";
import { geocode, type Geo } from "./geo.ts";
import { aiConfig, aiInterpret, aiWebSuggestions, type Suggestion } from "./ai.ts";
import {
  rankCapabilities,
  type Capability,
  type Availability,
} from "./matching.ts";

type Env = (name: string) => string | undefined;
type Factory = typeof createClient;
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const MAX_TEXT = 2000;
const CAP_FIELDS =
  "id,entity_id,object_type,category_id,category_raw,title,description,modality,city,country_code,latitude,longitude,radius_km,price_min,price_max,currency,attributes,is_active";

export async function handleRequest(
  req: Request,
  factory: Factory = createClient,
  env: Env = (k) => Deno.env.get(k),
): Promise<Response> {
  const request_id = crypto.randomUUID();
  const c = cors(req.headers.get("origin"));
  const fail = (code: string, status: number, intent_id?: string) =>
    reply(
      status,
      {
        ok: false,
        error: { code, message: "Could not complete this request", request_id },
        ...(intent_id ? { intent_id } : {}),
      },
      c.headers,
    );
  if (req.method === "OPTIONS")
    return new Response(null, {
      status: c.allowed ? 204 : 403,
      headers: c.headers,
    });
  if (!c.allowed) return fail("origin_not_allowed", 403);
  if (req.method !== "POST") return fail("method_not_allowed", 405);
  const auth = req.headers.get("authorization") ?? "";
  if (!/^Bearer\s+\S+$/i.test(auth)) return fail("unauthorized", 401);
  try {
    const url = env("SUPABASE_URL");
    let clientKey = env("SUPABASE_ANON_KEY"),
      serviceKey = env("SUPABASE_SERVICE_ROLE_KEY");
    try {
      clientKey =
        JSON.parse(env("SUPABASE_PUBLISHABLE_KEYS") ?? "{}").default ??
        clientKey;
    } catch {
      /* legacy fallback */
    }
    try {
      serviceKey =
        JSON.parse(env("SUPABASE_SECRET_KEYS") ?? "{}").default ?? serviceKey;
    } catch {
      /* legacy fallback */
    }
    if (!url || !clientKey) return fail("server_config", 500);
    const jwt = auth.replace(/^Bearer\s+/i, "");
    const userDb = factory(url, clientKey, {
      global: { headers: { Authorization: auth } },
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const {
      data: { user },
      error: authError,
    } = await userDb.auth.getUser(jwt);
    if (authError || !user) return fail("invalid_session", 401);
    let body;
    try {
      body = await req.json();
    } catch {
      return fail("invalid_json", 400);
    }
    if (!body || typeof body !== "object" || Array.isArray(body))
      return fail("invalid_request", 400);
    const raw = typeof body.raw_text === "string" ? body.raw_text.trim() : "";
    const entity = typeof body.entity_id === "string" ? body.entity_id : "";
    // Preserve v5's fallback for the existing FlutterFlow action until it sends IANA.
    // New clients must supply the actual zone; make the fallback explicit in output.
    const timezoneAssumed = body.user_timezone == null;
    const tz = timezoneAssumed
      ? "America/Argentina/Buenos_Aires"
      : typeof body.user_timezone === "string" ? body.user_timezone : "";
    const previousId = body.previous_intent_id;
    const answer =
      typeof body.clarification_answer === "string"
        ? body.clarification_answer.trim()
        : "";
    if (
      !raw ||
      raw.length > MAX_TEXT ||
      !UUID.test(entity) ||
      !validTz(tz) ||
      (previousId != null &&
        (typeof previousId !== "string" || !UUID.test(previousId))) ||
      (body.locale_hint != null && !["es", "en"].includes(body.locale_hint)) ||
      (body.clarification_answer != null &&
        typeof body.clarification_answer !== "string") ||
      answer.length > MAX_TEXT ||
      (answer && !previousId)
    )
      return fail("invalid_request", 400);

    const { data: owned, error: ownerError } = await userDb
      .from("entities")
      .select("id,is_active,city")
      .eq("id", entity)
      .eq("owner_profile_id", user.id)
      .maybeSingle();
    if (ownerError) return fail("entity_lookup_failed", 503);
    if (!owned || owned.is_active === false)
      return fail("entity_forbidden", 403);
    let previous = null;
    if (previousId) {
      const { data, error } = await userDb
        .from("intents")
        .select("*")
        .eq("id", previousId)
        .eq("entity_id", entity)
        .maybeSingle();
      if (error) return fail("previous_intent_lookup_failed", 503);
      if (!data) return fail("previous_intent_not_found", 404);
      if (data.raw_text !== raw) return fail("original_text_mismatch", 409);
      previous = data;
    }
    const history = Array.isArray(previous?.metadata?.clarification_history)
      ? (previous.metadata.clarification_history
          .filter((x: unknown) => typeof x === "string")
          .slice(-5) as string[])
      : [];
    if (answer) {
      if (history.length >= 5)
        return fail("clarification_limit", 422, previousId);
      // interpret() asks about category before location when both are missing.
      const locationMissing =
        Array.isArray(previous?.missing_fields) &&
        previous.missing_fields.includes("location") &&
        !previous.missing_fields.includes("category");
      const normalizedAnswer =
        locationMissing && !/^(en|in)\s/i.test(answer)
          ? `en ${answer}`
          : answer;
      if (history.at(-1) !== normalizedAnswer) history.push(normalizedAnswer);
    }
    const parseText = [raw, ...history].join("\n");
    if (parseText.length > 6000) return fail("text_too_long", 400, previousId);
    const intent = interpret(parseText, tz, body.locale_hint);
    // v9: la IA entiende el pedido; si no está disponible, quedan las reglas.
    // Proveedor de IA elegido con los secretos (Anthropic por defecto, u OpenAI).
    const aiCfg = aiConfig(env);
    const { data: catRows } = await userDb
      .from("categories")
      .select("slug,name_es")
      .eq("is_active", true);
    const ai = await aiInterpret(
      aiCfg,
      parseText,
      owned.city ?? null,
      (catRows ?? []).map((r) => ({ slug: r.slug as string, name: r.name_es as string })),
    );
    if (ai) {
      intent.understood_by = "ai";
      if (ai.direction) intent.direction = ai.direction;
      if (ai.object_type) intent.object_type = ai.object_type;
      if (ai.category_slugs?.length) {
        intent.category_slugs = ai.category_slugs;
        intent.category_slug = ai.category_slugs[0];
        intent.category_raw = ai.category_slugs[0];
        intent.confidence = 0.9;
      }
      if (ai.city) {
        intent.city = ai.city;
        intent.location_raw = ai.city;
      }
      if (ai.modality) intent.modality = ai.modality;
      intent.ships_nationwide = !!ai.ships_nationwide;
    } else intent.understood_by = "rules";
    // Lo que publican las personas se guarda como "service" (incluye vender cosas):
    // un producto se busca en el mismo universo para no perder al particular que vende.
    const isProduct = intent.object_type === "product";
    if (isProduct) intent.object_type = "service";
    intent.location_importance =
      intent.ships_nationwide || intent.modality === "remoto" || intent.modality === "no_aplica"
        ? "indifferent"
        : intent.modality === "hibrido"
          ? "preferred"
          : "required";
    // Sin ciudad en el pedido: se usa la del perfil en vez de preguntar.
    if (!intent.city && intent.location_importance !== "indifferent" && owned.city) {
      intent.city = owned.city;
      intent.location_raw = owned.city;
      intent.location_source = "profile";
    } else intent.location_source = intent.city ? "stated" : "none";
    // Guarda las localidades reconocidas: los avisos de "Avisame" las usan para medir distancias.
    const remember = async (pairs: [string, Geo | null][]) => {
      const rows = pairs
        .filter((p): p is [string, Geo] => !!p[1])
        .map(([raw, g]) => ({
          name_norm: norm(raw),
          name: g.name,
          province: g.province,
          latitude: g.lat,
          longitude: g.lon,
          updated_at: new Date().toISOString(),
        }));
      if (!rows.length || !serviceKey) return;
      try {
        await factory(url, serviceKey, {
          auth: { persistSession: false, autoRefreshToken: false },
        })
          .from("geo_places")
          .upsert(rows, { onConflict: "name_norm" });
      } catch {
        // Nunca debe frenar una búsqueda.
      }
    };
    const rawCity = intent.city;
    const place = intent.city ? await geocode(intent.city) : null;
    if (rawCity && place) await remember([[rawCity, place], [place.name, place]]);
    if (place) {
      intent.city = place.name;
      intent.province = place.province;
      intent.latitude = place.lat;
      intent.longitude = place.lon;
      intent.radius_km = 30;
      intent.geocode_status = "resolved";
    }
    {
      const hasCategory = !!intent.category_slugs?.length || !!intent.category_slug;
      const needsPlace = intent.location_importance === "required" && !intent.city;
      intent.missing_fields = [
        ...(hasCategory ? [] : ["category"]),
        ...(needsPlace ? ["location"] : []),
      ];
      intent.needs_clarification = !hasCategory || needsPlace;
      intent.clarification_question = !hasCategory
        ? "¿Podés contarme un poco más sobre qué necesitás?"
        : needsPlace
          ? "¿En qué ciudad o zona lo necesitás?"
          : undefined;
    }
    // v8: una necesidad puede resolverse con varias categorías.
    const slugs = intent.category_slugs?.length
      ? intent.category_slugs
      : intent.category_slug ? [intent.category_slug] : [];
    let category_ids: string[] = [];
    if (slugs.length) {
      const { data, error } = await userDb
        .from("categories")
        .select("id,slug")
        .in("slug", slugs)
        .eq("is_active", true);
      if (error) return fail("category_lookup_failed", 503, previousId);
      const bySlug = new Map((data ?? []).map((r) => [r.slug, r.id as string]));
      category_ids = slugs.map((x) => bySlug.get(x)).filter((x): x is string => !!x);
    }
    // Known keyword with no active catalog category must not become a broad search.
    if (slugs.length && !category_ids.length)
      return fail("category_unavailable", 422, previousId);
    // Con una sola categoría se mantiene el comportamiento de v7 (category_id canónico).
    const category_id: string | null = category_ids.length === 1 ? category_ids[0] : null;
    const categoryFilter: string | null | string[] =
      category_ids.length > 1 ? category_ids : category_id;
    const row = {
      entity_id: entity,
      raw_text: raw,
      status: "active",
      language: intent.language,
      direction: intent.direction,
      object_type: intent.object_type,
      category_id,
      category_raw: intent.category_raw,
      category_confidence: intent.confidence,
      modality: intent.modality,
      urgency: intent.urgency,
      geocode_status: intent.geocode_status,
      location_importance: intent.location_importance,
      location_raw: intent.location_raw ?? null,
      city: intent.geocode_status === "resolved" ? (intent.city ?? null) : null,
      country_code: null,
      latitude: intent.latitude ?? null,
      longitude: intent.longitude ?? null,
      radius_km: intent.radius_km ?? null,
      time_window_start: intent.time_window_start ?? null,
      time_window_end: intent.time_window_end ?? null,
      time_raw: intent.time_raw ?? null,
      budget_min: intent.budget_min ?? null,
      budget_max: intent.budget_max ?? null,
      currency: intent.currency ?? null,
      currency_inferred: false,
      budget_raw: intent.budget_raw ?? null,
      quantity: intent.quantity ?? null,
      quantity_unit: intent.quantity_unit ?? null,
      constraints: [],
      field_provenance: {
        category: intent.category_slug ? "inferred" : "unknown",
        location: intent.location_raw ? "stated" : "unknown",
        temporal: intent.time_raw ? "stated" : "unknown",
        budget: intent.budget_raw ? "stated" : "unknown",
      },
      needs_clarification: intent.needs_clarification,
      clarification_question: intent.clarification_question ?? null,
      missing_fields: intent.missing_fields,
      confidence: intent.confidence,
      interpreted_at: new Date().toISOString(),
      metadata: {
        ...(previous?.metadata ?? {}),
        clarification_history: history,
        user_timezone: tz,
        category_ids,
        category_slugs: slugs,
        understood_by: intent.understood_by,
        location_source: intent.location_source,
        ships_nationwide: !!intent.ships_nationwide,
        is_product: isProduct,
      },
    };
    const write = previous
      ? userDb
          .from("intents")
          .update(row)
          .eq("id", previous.id)
          .eq("entity_id", entity)
      : userDb.from("intents").insert(row);
    const { data: saved, error: saveError } = await write.select("id").single();
    if (saveError || !saved) return fail("persist_failed", 503, previousId);
    const id = saved.id as string;
    const success = (extra: Record<string, unknown>) =>
      reply(
        200,
        { ok: true, request_id, intent_id: id, intent, timezone_assumed: timezoneAssumed, ...extra },
        c.headers,
      );
    // Sugerencias de internet (negocios y cuentas reales) cuando la app tiene pocas opciones.
    // Ahorro: los resultados se reutilizan durante 3 días para el mismo rubro y la misma zona,
    // así dos personas que buscan lo mismo no pagan dos búsquedas.
    const suggest = async (internalCount: number): Promise<Suggestion[]> => {
      if (internalCount >= 3 || !aiCfg || intent.direction !== "seek") return [];
      const nationwide =
        !!intent.ships_nationwide || intent.location_importance === "indifferent";
      const zone = nationwide ? "ar" : norm(intent.city ?? "ar");
      const topic = slugs.length
        ? [...slugs.slice(0, 3)].sort().join("+")
        : norm(ai?.web_query ?? raw.slice(0, 80));
      const web_key = `${topic}|${zone}`;
      const save = (extra: Record<string, unknown>) =>
        userDb
          .from("intents")
          .update({ metadata: { ...row.metadata, web_key, ...extra } })
          .eq("id", id)
          .eq("entity_id", entity);
      if (serviceKey) {
        const shared = factory(url, serviceKey, {
          auth: { persistSession: false, autoRefreshToken: false },
        });
        const { data: hits } = await shared
          .from("intents")
          .select("metadata")
          .eq("metadata->>web_key", web_key)
          .eq("metadata->>web_used", "true")
          .gte("created_at", new Date(Date.now() - 3 * 864e5).toISOString())
          .neq("id", id)
          .order("created_at", { ascending: false })
          .limit(5);
        for (const h of hits ?? []) {
          const list = (h as { metadata?: { web_list?: unknown } }).metadata?.web_list;
          if (Array.isArray(list) && list.length) {
            await save({ web_cached: true, suggestions: list.length });
            return list as Suggestion[];
          }
        }
      }
      const since = new Date(Date.now() - 864e5).toISOString();
      const { count } = await userDb
        .from("intents")
        .select("id", { count: "exact", head: true })
        .eq("entity_id", entity)
        .gte("created_at", since)
        .eq("metadata->>web_used", "true");
      if ((count ?? 0) >= 15) return [];
      const list = await aiWebSuggestions(
        aiCfg,
        raw,
        ai?.web_query ?? raw.slice(0, 120),
        nationwide ? null : (intent.city ?? null),
        intent.province ?? null,
        nationwide,
      );
      // Solo cuenta para el límite diario si la búsqueda realmente se hizo.
      if (list === null) return [];
      await save({
        web_used: true,
        web_provider: aiCfg.provider,
        suggestions: list.length,
        web_list: list,
      });
      return list;
    };
    if (intent.needs_clarification)
      return success({
        matching_status: "clarification",
        clarification: {
          question: intent.clarification_question,
          missing_fields: intent.missing_fields,
        },
        matches: [],
      });
    // Explicit scope from archived launch contract: seek -> public capabilities.
    // Offer is saved privately; never match two offers or publish it silently.
    if (intent.direction === "offer")
      return success({ matching_status: "offer_saved", matches: [] });
    if (!serviceKey) return fail("matching_not_configured", 503, id);
    const admin = factory(url, serviceKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
    let q = userDb
      .from("entity_capabilities")
      .select(CAP_FIELDS)
      .eq("is_active", true)
      .eq("object_type", intent.object_type)
      .neq("entity_id", entity)
      .order("id")
      .limit(200);
    if (category_ids.length > 1) q = q.in("category_id", category_ids);
    else if (category_id) q = q.eq("category_id", category_id);
    const { data: rows, error: candidateError } = await q;
    if (candidateError) return fail("matching_failed", 503, id);
    let blocked = new Set<string>();
    const { data: blockRows, error: blockError } = await admin
      .from("blocks")
      .select("blocker_entity_id,blocked_entity_id")
      .or(`blocker_entity_id.eq.${entity},blocked_entity_id.eq.${entity}`);
    if (!blockError)
      blocked = new Set(
        (blockRows ?? []).map((b) =>
          b.blocker_entity_id === entity ? b.blocked_entity_id : b.blocker_entity_id,
        ),
      );
    const candidates = ((rows ?? []) as Capability[]).filter(
      (x) => !blocked.has(x.entity_id),
    );
    if (!candidates.length)
      return success({ matching_status: "empty", matches: [], suggestions: await suggest(0) });
    const ids = candidates.map((x) => x.id);
    // Embedded relation avoids truncating a flattened availability query at the API row cap.
    const { data: withAvailability, error: availabilityError } = await userDb
      .from("entity_capabilities")
      .select(
        "id,entity_capability_availability(capability_id,starts_at,ends_at,recurrence,is_active)",
      )
      .in("id", ids);
    if (availabilityError) return fail("availability_lookup_failed", 503, id);
    const availability = (withAvailability ?? []).flatMap(
      (x) => x.entity_capability_availability ?? [],
    ) as Availability[];
    const entityIds = [...new Set(candidates.map((x) => x.entity_id))];
    const { data: entities, error: entityError } = await admin
      .from("entities")
      .select("id,name,avatar_url,is_active")
      .in("id", entityIds);
    if (entityError) return fail("matching_failed", 503, id);
    const entityMap = new Map(
      (entities ?? [])
        .filter((e) => e.is_active !== false)
        .map((e) => [e.id, e]),
    );
    const pending = [
      ...new Set(
        candidates
          .filter((x) => x.latitude == null && x.city)
          .map((x) => x.city as string),
      ),
    ].slice(0, 40);
    const geocoded = await Promise.all(
      pending.map(async (name) => [name, await geocode(name)] as [string, Geo | null]),
    );
    const located = new Map(geocoded);
    await remember(geocoded);
    for (const cand of candidates) {
      const g = cand.latitude == null && cand.city ? located.get(cand.city) : null;
      if (g) {
        cand.latitude = g.lat;
        cand.longitude = g.lon;
      }
    }
    const pool = candidates.filter((x) => entityMap.has(x.entity_id));
    let ranked = rankCapabilities(intent, categoryFilter, pool, availability, entity);
    let expanded_radius = false;
    // Si no hay nada cerca, se amplía el radio antes de rendirse.
    if (!ranked.length && intent.location_importance === "required" && intent.latitude != null) {
      intent.radius_km = 120;
      ranked = rankCapabilities(intent, categoryFilter, pool, availability, entity);
      expanded_radius = ranked.length > 0;
    }
    if (!ranked.length)
      return success({ matching_status: "empty", matches: [], suggestions: await suggest(0) });
    const payload = ranked.map((m) => ({
      target_entity_id: m.capability.entity_id,
      target_capability_id: m.capability.id,
      score: m.score,
      hard_constraints_passed: m.hard_constraints_passed,
      score_breakdown: m.score_breakdown,
      reason:
        "Deterministic matching; verify availability/location as indicated",
      metadata: {
        unverified: m.unverified,
        availability_status: m.availability_status,
      },
    }));
    // One transactional RPC: no partial success, stable IDs when retried for the same intent.
    const { data: recorded, error: recordError } = await admin.rpc(
      "record_matches_batch",
      { p_caller_user_id: user.id, p_source_intent_id: id, p_matches: payload },
    );
    if (recordError || !Array.isArray(recorded))
      return fail("match_persist_failed", 503, id);
    const matchIds = new Map(
      recorded.map((x: { capability_id: string; match_id: string }) => [
        x.capability_id,
        x.match_id,
      ]),
    );
    if (ranked.some((m) => !matchIds.get(m.capability.id)))
      return fail("match_persist_failed", 503, id);
    return success({
      matching_status: "results",
      expanded_radius,
      suggestions: await suggest(ranked.length),
      matches: ranked.map((m) => ({
        distance_km: m.distance_km,
        match_id: matchIds.get(m.capability.id),
        capability_id: m.capability.id,
        entity_id: m.capability.entity_id,
        entity_name: entityMap.get(m.capability.entity_id)?.name ?? null,
        entity_avatar_url:
          entityMap.get(m.capability.entity_id)?.avatar_url ?? null,
        title: m.capability.title,
        description: m.capability.description,
        city: m.capability.city,
        modality: m.capability.modality,
        price_min: m.capability.price_min,
        price_max: m.capability.price_max,
        currency: m.capability.currency,
        score: m.score,
        hard_constraints_passed: m.hard_constraints_passed,
        unverified: m.unverified,
        availability_status: m.availability_status,
      })),
    });
  } catch {
    console.error("[interpret-intent] unhandled request", request_id);
    return fail("internal_error", 500);
  }
}
