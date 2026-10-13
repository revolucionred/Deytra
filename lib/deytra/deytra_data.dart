// Acceso a datos de Deytra (Supabase). Todas las reglas de permisos viven en
// la base (RLS y funciones): este archivo nunca usa claves privadas.
import 'package:supabase_flutter/supabase_flutter.dart';
import '/backend/supabase/supabase.dart';

class DeytraData {
  DeytraData._();
  static SupabaseClient get _db => SupaFlow.client;
  static const _timeout = Duration(seconds: 20);

  static String? get uid => _db.auth.currentUser?.id;

  /// Perfil de persona del usuario actual (se crea en el onboarding).
  static Future<Map<String, dynamic>?> myEntity() async {
    final id = uid;
    if (id == null) return null;
    final row = await _db
        .from('entities')
        .select()
        .eq('owner_profile_id', id)
        .eq('entity_type', 'person')
        .maybeSingle()
        .timeout(_timeout);
    return row == null ? null : Map<String, dynamic>.from(row);
  }

  static Future<String?> myEntityId() async =>
      (await myEntity())?['id']?.toString();

  static Future<void> updateProfile({
    required String entityId,
    required String name,
    String? city,
    String? description,
    String? instagramUrl,
  }) async {
    await _db
        .from('entities')
        .update({
          'name': name.trim(),
          'city': _clean(city),
          'description': _clean(description),
          'instagram_url': _instagram(instagramUrl),
        })
        .eq('id', entityId)
        .timeout(_timeout);
    final id = uid;
    if (id != null) {
      await _db
          .from('users')
          .update({'display_name': name.trim(), 'bio': _clean(description)})
          .eq('id', id)
          .timeout(_timeout);
    }
  }

  // ---------- Categorías ----------
  static List<Map<String, dynamic>>? _categoriesCache;
  static Future<List<Map<String, dynamic>>> categories() async {
    if (_categoriesCache != null) return _categoriesCache!;
    final rows = await _db
        .from('categories')
        .select('id,slug,name_es,parent_id')
        .eq('is_active', true)
        .order('name_es')
        .timeout(_timeout);
    _categoriesCache =
        (rows as List).map((e) => Map<String, dynamic>.from(e)).toList();
    return _categoriesCache!;
  }

  // ---------- Lo que ofrezco ----------
  static Future<List<Map<String, dynamic>>> myOffers(String entityId) async {
    final rows = await _db
        .from('entity_capabilities')
        .select(
            'id,title,description,category_id,category_raw,modality,city,price_min,price_max,currency,is_active,created_at')
        .eq('entity_id', entityId)
        .order('created_at', ascending: false)
        .timeout(_timeout);
    return (rows as List).map((e) => Map<String, dynamic>.from(e)).toList();
  }

  static Future<void> saveOffer({
    String? id,
    required String entityId,
    required String title,
    required String categoryId,
    required String categoryName,
    String? description,
    required String modality,
    String? city,
    num? priceFrom,
  }) async {
    final data = <String, dynamic>{
      'entity_id': entityId,
      // Las necesidades cotidianas se buscan como servicio (ver interpret-intent v8).
      'object_type': 'service',
      'title': title.trim(),
      'category_id': categoryId,
      'category_raw': categoryName,
      'description': _clean(description),
      'modality': modality,
      'city': _clean(city),
      'price_min': priceFrom,
      'currency': priceFrom == null ? null : 'ARS',
      'is_active': true,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    if (id == null) {
      await _db.from('entity_capabilities').insert(data).timeout(_timeout);
    } else {
      await _db
          .from('entity_capabilities')
          .update(data)
          .eq('id', id)
          .timeout(_timeout);
    }
  }

  static Future<void> setOfferActive(String id, bool active) => _db
      .from('entity_capabilities')
      .update({
        'is_active': active,
        'updated_at': DateTime.now().toUtc().toIso8601String()
      })
      .eq('id', id)
      .timeout(_timeout);

  static Future<void> deleteOffer(String id) =>
      _db.from('entity_capabilities').delete().eq('id', id).timeout(_timeout);

  // ---------- Conexiones ----------
  static Future<List<Map<String, dynamic>>> connections() async {
    final rows = await _db.rpc('list_my_connections').timeout(_timeout);
    return (rows as List).map((e) => Map<String, dynamic>.from(e)).toList();
  }

  static Future<void> requestConnection({
    required String matchId,
    required String requesterEntityId,
    required String recipientEntityId,
    String? message,
  }) =>
      _db.from('connections').insert({
        'match_id': matchId,
        'requester_entity_id': requesterEntityId,
        'recipient_entity_id': recipientEntityId,
        'intro_message': _clean(message),
        'status': 'pending',
      }).timeout(_timeout);

  /// Solo quien recibe puede aceptar o rechazar (lo garantiza la base).
  static Future<void> respondConnection(String id, bool accept) => _db
      .from('connections')
      .update({'status': accept ? 'accepted' : 'rejected'})
      .eq('id', id)
      .timeout(_timeout);

  static Future<void> cancelConnection(String id) =>
      _db.from('connections').delete().eq('id', id).timeout(_timeout);

  // ---------- Seguridad ----------
  static Future<void> block(
          {required String myEntityId, required String otherEntityId}) =>
      _db.from('blocks').upsert({
        'blocker_entity_id': myEntityId,
        'blocked_entity_id': otherEntityId,
      }, onConflict: 'blocker_entity_id,blocked_entity_id').timeout(_timeout);

  static Future<void> report({
    required String myEntityId,
    required String otherEntityId,
    required String reason,
    String? details,
    String? capabilityId,
  }) =>
      _db.from('reports').insert({
        'reporter_entity_id': myEntityId,
        'reported_entity_id': otherEntityId,
        'reported_capability_id': capabilityId,
        'reason': reason,
        'details': _clean(details),
      }).timeout(_timeout);

  static Future<void> deleteAccount() async {
    await _db.rpc('delete_my_account').timeout(_timeout);
    try {
      await _db.auth.signOut();
    } catch (_) {
      // La cuenta ya no existe: la sesión local se descarta igual.
    }
  }

  static Future<void> signOut() => _db.auth.signOut();

  // ---------- Utilidades ----------
  static String? _clean(String? s) {
    final t = s?.trim() ?? '';
    return t.isEmpty ? null : t;
  }

  static String? _instagram(String? s) {
    var t = _clean(s);
    if (t == null) return null;
    t = t.replaceAll(RegExp(r'\s'), '');
    if (t.startsWith('http')) return t;
    t = t.replaceFirst(RegExp(r'^@'), '');
    return 'https://instagram.com/$t';
  }

  /// Mensaje claro para el usuario a partir de cualquier error.
  static String friendlyError(Object e) {
    final s = e.toString();
    if (s.contains('TimeoutException')) {
      return 'La conexión está lenta. Probá de nuevo en un momento.';
    }
    if (s.contains('42501') || s.contains('permission')) {
      return 'No tenés permiso para hacer esto.';
    }
    if (s.contains('duplicate') || s.contains('23505')) {
      return 'Esto ya estaba hecho.';
    }
    if (s.contains('SocketException') || s.contains('Failed host lookup')) {
      return 'Sin conexión a internet.';
    }
    return 'Algo no salió bien. Probá de nuevo.';
  }
}
