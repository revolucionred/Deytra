// Automatic FlutterFlow imports
import '/flutter_flow/ff_builtin_enums.dart';
import '/backend/supabase/supabase.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/custom_code/actions/index.dart'; // Imports other custom actions
import '/flutter_flow/custom_functions.dart'; // Imports custom functions
import 'package:flutter/material.dart' hide RepeatMode;
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

Future<dynamic> interpretIntent(
  String rawText,
  String entityId,
) async {
  final client = SupaFlow.client;
  final text = rawText.trim();
  if (text.isEmpty || text.length > 2000) {
    throw Exception('Escribí qué necesitás, en hasta 2000 caracteres.');
  }
  final user = client.auth.currentUser;
  if (user == null) {
    throw Exception('Ingresá a tu cuenta para buscar coincidencias.');
  }
  var resolvedEntityId = entityId.trim();
  if (resolvedEntityId.isEmpty) {
    final entity = await client
        .from('entities')
        .select('id')
        .eq('owner_profile_id', user.id)
        .eq('entity_type', 'person')
        .maybeSingle();
    resolvedEntityId = entity?['id']?.toString() ?? '';
  }
  if (resolvedEntityId.isEmpty) {
    throw Exception('Completá tu perfil antes de buscar coincidencias.');
  }
  final response = await client.functions.invoke(
    'interpret-intent',
    body: {'raw_text': text, 'entity_id': resolvedEntityId},
  );
  final data = response.data;
  if (data is Map) {
    return Map<String, dynamic>.from(data);
  }
  throw Exception('No pudimos procesar la búsqueda. Intentá nuevamente.');
}
