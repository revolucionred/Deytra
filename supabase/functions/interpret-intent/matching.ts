import {
  runMatching,
  type CandidateEntity,
  type MatchIntent,
} from "./engine.ts";
import { type Intent, norm } from "./interpretation.ts";
import { distanceKm } from "./geo.ts";

export interface Capability {
  id: string;
  entity_id: string;
  object_type: string;
  category_id: string | null;
  category_raw: string | null;
  title: string;
  description: string | null;
  modality: CandidateEntity["modality_supported"][number];
  city: string | null;
  country_code: string | null;
  latitude: number | null;
  longitude: number | null;
  radius_km: number | null;
  price_min: number | null;
  price_max: number | null;
  currency: string | null;
  attributes: Record<string, string | number | boolean>;
  is_active: boolean;
}
export interface Availability {
  capability_id: string;
  starts_at: string | null;
  ends_at: string | null;
  recurrence: string | null;
  is_active: boolean;
}
export interface RankedMatch {
  capability: Capability;
  distance_km: number | null;
  score: number;
  score_breakdown: Record<string, number>;
  hard_constraints_passed: true | null;
  unverified: string[];
  availability_status: "not_requested" | "compatible" | "unknown";
}

// The archived launch contract matches SEEK needs against public OFFER capabilities.
// Missing schedule data remains discoverable, explicitly unverified (never "passed").
export function rankCapabilities(
  intent: Intent,
  categoryIdOrList: string | null | string[],
  capabilities: Capability[],
  availability: Availability[],
  sourceEntityId: string,
): RankedMatch[] {
  if (intent.direction !== "seek") return [];
  const out: RankedMatch[] = [];
  for (const c of capabilities) {
    if (
      !c.is_active ||
      c.entity_id === sourceEntityId ||
      c.object_type !== intent.object_type
    )
      continue;
    // v8: una necesidad puede abarcar varias categorías (ej. patio: jardinería,
    // paisajismo, viveros). Cada candidato se evalúa con SU categoría si está en la lista.
    const categoryId = Array.isArray(categoryIdOrList)
      ? c.category_id && categoryIdOrList.includes(c.category_id)
        ? c.category_id
        : null
      : categoryIdOrList;
    if (Array.isArray(categoryIdOrList) && !categoryId) continue;
    if (categoryId && c.category_id !== categoryId) continue;
    // v9: con coordenadas se filtra por radio (cercanos incluidos); sin ellas, por nombre.
    if (intent.location_importance === "required") {
      const both =
        intent.latitude != null && intent.longitude != null &&
        c.latitude != null && c.longitude != null;
      if (both) {
        const d = distanceKm(intent.latitude!, intent.longitude!, c.latitude!, c.longitude!);
        if (d > (intent.radius_km ?? 30)) continue;
      } else if (!intent.city || !c.city || norm(intent.city) !== norm(c.city)) continue;
    }
    const rows = availability.filter(
      (a) => a.capability_id === c.id && a.is_active,
    );
    // Recurrence isn't implemented: never treat one stored date as expanded recurrence.
    const windows = rows
      .filter(
        (a) =>
          !a.recurrence &&
          a.starts_at &&
          a.ends_at &&
          Number.isFinite(Date.parse(a.starts_at)) &&
          Number.isFinite(Date.parse(a.ends_at)) &&
          Date.parse(a.ends_at) > Date.parse(a.starts_at),
      )
      .map((a) => ({ start: a.starts_at!, end: a.ends_at! }));
    const temporal = !!intent.time_window_start || intent.urgency === "asap";
    const incompleteSchedule = rows.some(
      (a) =>
        !!a.recurrence ||
        !a.starts_at ||
        !a.ends_at ||
        !Number.isFinite(Date.parse(a.starts_at)) ||
        !Number.isFinite(Date.parse(a.ends_at)) ||
        Date.parse(a.ends_at) <= Date.parse(a.starts_at),
    );
    const unverified: string[] = [];
    if (
      temporal &&
      (!intent.time_window_start || !windows.length || incompleteSchedule)
    )
      unverified.push("availability");
    if (
      intent.location_importance === "required" &&
      intent.geocode_status !== "resolved"
    )
      unverified.push("location");
    const comparableBudget =
      intent.budget_max != null &&
      c.price_min != null &&
      !!intent.currency &&
      !!c.currency &&
      intent.currency === c.currency;
    if (intent.budget_max != null && !comparableBudget)
      unverified.push("budget");
    const mi: MatchIntent = {
      raw_text: intent.category_raw,
      category_raw: intent.category_raw,
      category_id: categoryId,
      category_slug: intent.category_slug,
      object_type: intent.object_type,
      modality: intent.modality,
      location_importance: intent.location_importance,
      city: intent.city,
      latitude: intent.latitude,
      longitude: intent.longitude,
      radius_km: intent.radius_km,
      urgency: intent.urgency,
      budget_max: comparableBudget ? intent.budget_max : undefined,
      currency: intent.currency,
      temporal_window_start: intent.time_window_start,
      temporal_window_end: intent.time_window_end,
      temporal_required: temporal && !incompleteSchedule,
      constraints: [],
    };
    const candidate: CandidateEntity = {
      id: c.id,
      entity_id: c.entity_id,
      name: c.title,
      category_id: c.category_id,
      category_slugs:
        categoryId && c.category_id === categoryId
          ? [intent.category_slug ?? c.category_raw ?? ""]
          : [c.category_raw ?? ""],
      modality_supported:
        c.modality === "hibrido"
          ? ["presencial", "remoto", "hibrido"]
          : [c.modality],
      city: c.city ?? undefined,
      latitude: c.latitude ?? undefined,
      longitude: c.longitude ?? undefined,
      service_radius_km: c.radius_km ?? undefined,
      price_min: c.price_min ?? undefined,
      price_max: c.price_max ?? undefined,
      currency: c.currency ?? undefined,
      attributes: c.attributes ?? {},
      description: c.description ?? "",
      availability: windows,
    };
    const result = runMatching(mi, [candidate]).accepted[0];
    if (!result) continue;
    out.push({
      capability: c,
      distance_km:
        intent.latitude != null && intent.longitude != null && c.latitude != null && c.longitude != null
          ? Math.round(distanceKm(intent.latitude, intent.longitude, c.latitude, c.longitude) * 10) / 10
          : null,
      score: result.score,
      score_breakdown: result.score_breakdown,
      hard_constraints_passed: unverified.length ? null : true,
      unverified,
      availability_status: !temporal
        ? "not_requested"
        : unverified.includes("availability")
          ? "unknown"
          : "compatible",
    });
  }
  return out
    .sort(
      (a, b) =>
        b.score - a.score || a.capability.id.localeCompare(b.capability.id),
    )
    .slice(0, 20);
}
