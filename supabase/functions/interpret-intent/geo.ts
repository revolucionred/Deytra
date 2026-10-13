// Geolocalización de localidades argentinas con el servicio oficial Georef
// (apis.datos.gob.ar). Gratuito y sin clave. Cache en memoria por instancia.
import { norm } from "./interpretation.ts";

export type Geo = { name: string; province: string | null; lat: number; lon: number };

const cache = new Map<string, Geo | null>();
const GEOREF = "https://apis.datos.gob.ar/georef/api/localidades";

export async function geocode(name: string | null | undefined): Promise<Geo | null> {
  const raw = (name ?? "").trim();
  if (!raw || raw.length > 80) return null;
  const key = norm(raw);
  if (cache.has(key)) return cache.get(key) ?? null;
  // Admite "Roldán, Santa Fe": la parte después de la coma es la provincia.
  const [city, province] = raw.split(",").map((s) => s.trim());
  const params = new URLSearchParams({
    nombre: city,
    max: "1",
    aplanar: "true",
    campos: "nombre,provincia.nombre,centroide.lat,centroide.lon",
  });
  if (province) params.set("provincia", province);
  let geo: Geo | null = null;
  try {
    const res = await fetch(`${GEOREF}?${params}`, {
      signal: AbortSignal.timeout(4000),
    });
    if (res.ok) {
      const body = await res.json();
      const hit = body?.localidades?.[0];
      const lat = Number(hit?.centroide_lat);
      const lon = Number(hit?.centroide_lon);
      if (hit && Number.isFinite(lat) && Number.isFinite(lon)) {
        geo = {
          name: String(hit.nombre ?? city),
          province: hit.provincia_nombre ? String(hit.provincia_nombre) : null,
          lat,
          lon,
        };
      }
    }
  } catch {
    // Sin red o servicio caído: se sigue comparando por nombre de ciudad.
    return null;
  }
  if (cache.size > 2000) cache.clear();
  cache.set(key, geo);
  return geo;
}

export function distanceKm(aLat: number, aLon: number, bLat: number, bLon: number) {
  const R = 6371;
  const dLat = ((bLat - aLat) * Math.PI) / 180;
  const dLon = ((bLon - aLon) * Math.PI) / 180;
  const x =
    Math.sin(dLat / 2) ** 2 +
    Math.cos((aLat * Math.PI) / 180) *
      Math.cos((bLat * Math.PI) / 180) *
      Math.sin(dLon / 2) ** 2;
  return R * 2 * Math.asin(Math.sqrt(x));
}
