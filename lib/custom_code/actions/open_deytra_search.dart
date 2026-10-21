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

// FlutterFlow: Include BuildContext; String rawText/entityId; no return value.
import 'dart:async';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show FunctionException;
import '/deytra/deytra_data.dart';

Future<void> openDeytraSearch(
  BuildContext context,
  String rawText,
  String entityId,
) async {
  if (!context.mounted) return;
  final ownerId = SupaFlow.client.auth.currentUser?.id;
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _DeytraSearchDialog(
        rawText: rawText, entityId: entityId, ownerId: ownerId),
  );
}

class _DeytraSearchDialog extends StatefulWidget {
  const _DeytraSearchDialog(
      {required this.rawText, required this.entityId, required this.ownerId});
  final String rawText;
  final String entityId;
  final String? ownerId;
  @override
  State<_DeytraSearchDialog> createState() => _DeytraSearchDialogState();
}

class _DeytraSearchDialogState extends State<_DeytraSearchDialog> {
  static const _orange = Color(0xFFFF8A3D);
  static const _burnt = Color(0xFFD35400);
  static const _charcoal = Color(0xFF1F1F1F);
  static const _cream = Color(0xFFF8F6F2);
  static final _uuid = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
    caseSensitive: false,
  );
  final _answer = TextEditingController();
  StreamSubscription<dynamic>? _authChanges;
  late final String _original = widget.rawText.trim();
  late String _entityId = widget.entityId.trim();
  late final String? _ownerId = widget.ownerId;
  String? _intentId;
  String? _alertFor; // búsqueda para la que ya se pidió aviso
  bool _alertBusy = false;
  String? _pendingAnswer;
  String? _fieldError;
  String _status = 'loading';
  String _question = '';
  String _category =
      ''; // Display-only search context from the accepted response.
  String _error = '';
  bool _busy = false;
  bool _sessionChanged = false;
  bool _uncertain = false;
  bool _canRetry = false;
  bool _timezoneAssumed = false;
  bool _hasTimeWindow = false;
  bool _needsLocationAnswer = false;
  int _attempt = 0;
  List<Map<String, dynamic>> _matches = [];
  List<Map<String, dynamic>> _suggestions = [];
  bool _expanded = false;
  String _place = '';
  @override
  void initState() {
    super.initState();
    void handleAuthUpdate() {
      final auth = SupaFlow.client.auth;
      if (mounted &&
          (auth.currentUser?.id != _ownerId ||
              (_ownerId != null && auth.currentSession == null))) {
        _attempt++;
        _fail('session_changed', invoked: false);
      }
    }

    _authChanges = SupaFlow.client.auth.onAuthStateChange.listen(
      (_) => handleAuthUpdate(),
      onError: (Object error, StackTrace stackTrace) => handleAuthUpdate(),
    );
    handleAuthUpdate();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _submit();
    });
  }

  @override
  void dispose() {
    _attempt++;
    _authChanges?.cancel();
    _answer.dispose();
    super.dispose();
  }

  bool _validId(dynamic value) => value is String && _uuid.hasMatch(value);
  String _errorMessage(String code) {
    switch (code) {
      case 'invalid_request':
      case 'text_too_long':
        return 'Escribí qué necesitás en hasta 2000 caracteres.';
      case 'unauthorized':
      case 'invalid_session':
      case 'session_changed':
        return 'Ingresá a tu cuenta y volvé a abrir la búsqueda.';
      case 'profile_required':
      case 'entity_forbidden':
        return 'Completá o seleccioná un perfil activo de tu cuenta.';
      case 'clarification_limit':
        return 'Cerrá esta ventana e iniciá una nueva búsqueda con todos los detalles.';
      case 'original_text_mismatch':
      case 'previous_intent_not_found':
        return 'Cerrá esta ventana e iniciá una nueva búsqueda.';
      case 'category_unavailable':
        return 'Esa categoría todavía no está disponible. Revisá la descripción.';
      case 'origin_not_allowed':
        return 'La búsqueda no está habilitada en esta versión.';
      case 'server_config':
      case 'matching_not_configured':
        return 'La búsqueda no está disponible. Intentá más tarde.';
      case 'timeout':
      case 'request_failed':
        return 'No pudimos confirmar el resultado. Revisá tu conexión.';
      default:
        return _intentId == null
            ? 'No pudimos completar la búsqueda. Tu texto sigue en la pantalla principal.'
            : 'La búsqueda quedó guardada, pero no pudimos cargar su resultado.';
    }
  }

  void _fail(String code, {required bool invoked}) {
    const beforeWrite = {
      'invalid_json',
      'invalid_request',
      'text_too_long',
      'unauthorized',
      'invalid_session',
      'session_changed',
      'origin_not_allowed',
      'method_not_allowed',
      'server_config',
      'entity_lookup_failed',
      'entity_forbidden',
      'profile_required',
      'previous_intent_lookup_failed',
      'previous_intent_not_found',
      'original_text_mismatch',
      'clarification_limit',
      'category_lookup_failed',
      'category_unavailable',
    };
    const retryableBeforeWrite = {
      'entity_lookup_failed',
      'previous_intent_lookup_failed',
      'category_lookup_failed',
    };
    const afterWrite = {
      'matching_not_configured',
      'matching_failed',
      'availability_lookup_failed',
      'match_persist_failed',
    };
    if (!mounted) return;
    setState(() {
      if (code == 'session_changed') {
        _sessionChanged = true;
        _intentId = null;
        _pendingAnswer = null;
        _answer.clear();
      }
      _busy = false;
      _status = 'error';
      _matches = [];
      _suggestions = [];
      if (invoked && afterWrite.contains(code)) _pendingAnswer = null;
      _uncertain = invoked &&
          !beforeWrite.contains(code) &&
          (_intentId == null || _pendingAnswer != null);
      _canRetry = !_uncertain &&
          code != 'matching_not_configured' &&
          (!beforeWrite.contains(code) || retryableBeforeWrite.contains(code));
      _error = _errorMessage(code);
    });
  }

  void _accept(dynamic value) {
    if (value is! Map || value.keys.any((key) => key is! String)) {
      throw const FormatException('invalid_response');
    }
    final data = Map<String, dynamic>.from(value);
    final receivedId = data['intent_id'];
    if (receivedId != null) {
      if (!_validId(receivedId) ||
          (_intentId != null && receivedId != _intentId)) {
        throw const FormatException('invalid_response');
      }
      _intentId = receivedId as String;
    }
    if (data['ok'] == false) {
      final error = data['error'];
      final code = error is Map && error['code'] is String
          ? error['code'] as String
          : 'request_failed';
      _fail(code, invoked: true);
      return;
    }
    final status = data['matching_status'];
    final matches = data['matches'];
    if (data['ok'] != true ||
        !_validId(receivedId) ||
        !['clarification', 'results', 'empty', 'offer_saved']
            .contains(status) ||
        matches is! List ||
        (status == 'results' ? matches.isEmpty : matches.isNotEmpty)) {
      throw const FormatException('invalid_response');
    }
    final checked = <Map<String, dynamic>>[];
    final seen = <String>{};
    for (final item in matches) {
      if (item is! Map ||
          item.keys.any((key) => key is! String) ||
          !_validId(item['match_id']) ||
          !_validId(item['entity_id']) ||
          !_validId(item['capability_id']) ||
          !seen.add(item['match_id'] as String) ||
          item['unverified'] is! List ||
          (item['unverified'] as List).any((warning) => warning is! String) ||
          !['not_requested', 'compatible', 'unknown']
              .contains(item['availability_status']) ||
          (item['hard_constraints_passed'] != null &&
              item['hard_constraints_passed'] != true)) {
        throw const FormatException('invalid_response');
      }
      checked.add(Map<String, dynamic>.from(item));
    }
    String question = '';
    bool needsLocationAnswer = false;
    if (status == 'clarification') {
      final clarification = data['clarification'];
      final text = clarification is Map ? clarification['question'] : null;
      if (text is! String || text.trim().isEmpty) {
        throw const FormatException('invalid_response');
      }
      question = text;
      final missing =
          clarification is Map ? clarification['missing_fields'] : null;
      needsLocationAnswer = missing is List &&
          missing.contains('location') &&
          !missing.contains('category');
    }
    final intent = data['intent'];
    setState(() {
      _busy = false;
      _status = status as String;
      _question = question;
      _needsLocationAnswer = needsLocationAnswer;
      _matches = checked;
      _suggestions = (data['suggestions'] is List ? data['suggestions'] as List : const [])
          .whereType<Map>()
          .where((x) =>
              x['name'] is String &&
              x['url'] is String &&
              (x['url'] as String).startsWith('http'))
          .map((x) => Map<String, dynamic>.from(x))
          .take(4)
          .toList();
      _expanded = data['expanded_radius'] == true;
      _place = intent is Map ? _text(intent['city']) : '';
      final slugs = intent is Map && intent['category_slugs'] is List
          ? (intent['category_slugs'] as List).whereType<String>().toList()
          : <String>[];
      if (slugs.isEmpty && intent is Map) {
        final one = _text(intent['category_slug']);
        if (one.isNotEmpty) slugs.add(one);
      }
      _category = slugs.take(4).map(_readable).join(', ');
      _pendingAnswer = null;
      _fieldError = null;
      _uncertain = false;
      _canRetry = false;
      _timezoneAssumed = data['timezone_assumed'] == true;
      _hasTimeWindow = intent is Map && intent['time_window_start'] is String;
    });
    _answer.clear();
  }

  Future<void> _submit() async {
    if (!mounted || _busy || _sessionChanged) return;
    final attempt = ++_attempt;
    bool invoked = false;
    setState(() {
      _busy = true;
      _status = 'loading';
      _matches = [];
      _suggestions = [];
      _fieldError = null;
      _error = '';
      _canRetry = false;
    });
    final client = SupaFlow.client;
    final user = client.auth.currentUser;
    if (user?.id != _ownerId ||
        (_ownerId != null && client.auth.currentSession == null)) {
      _fail('session_changed', invoked: false);
      return;
    }
    if (_ownerId == null ||
        user == null ||
        client.auth.currentSession == null) {
      _fail('unauthorized', invoked: false);
      return;
    }
    if (_original.isEmpty ||
        _original.length > 2000 ||
        (_pendingAnswer != null &&
            (_pendingAnswer!.isEmpty ||
                _pendingAnswer!.length > 2000 ||
                _intentId == null))) {
      _fail('invalid_request', invoked: false);
      return;
    }
    if (_entityId.isNotEmpty && !_validId(_entityId)) {
      _fail('invalid_request', invoked: false);
      return;
    }
    try {
      if (_entityId.isEmpty) {
        final entity = await client
            .from('entities')
            .select('id')
            .eq('owner_profile_id', user.id)
            .eq('entity_type', 'person')
            .or('is_active.is.null,is_active.eq.true')
            .maybeSingle()
            .timeout(const Duration(seconds: 15));
        if (!mounted || attempt != _attempt) return;
        _entityId = entity?['id']?.toString() ?? '';
        if (!_validId(_entityId)) {
          _fail('profile_required', invoked: false);
          return;
        }
      }
      if (!mounted || attempt != _attempt) return;
      if (client.auth.currentUser?.id != _ownerId ||
          client.auth.currentSession == null) {
        _fail('session_changed', invoked: false);
        return;
      }
      invoked = true;
      final response = await client.functions.invoke('interpret-intent', body: {
        'raw_text': _original,
        'entity_id': _entityId,
        'locale_hint': 'es',
        if (_intentId != null) 'previous_intent_id': _intentId,
        if (_pendingAnswer != null) 'clarification_answer': _pendingAnswer,
      }).timeout(const Duration(seconds: 55));
      if (!mounted || attempt != _attempt) return;
      if (client.auth.currentUser?.id != _ownerId ||
          client.auth.currentSession == null) {
        _fail('session_changed', invoked: invoked);
        return;
      }
      _accept(response.data);
    } on FunctionException catch (error) {
      if (!mounted || attempt != _attempt) return;
      if (client.auth.currentUser?.id != _ownerId ||
          client.auth.currentSession == null) {
        _fail('session_changed', invoked: invoked);
        return;
      }
      try {
        if (error.details is Map && (error.details as Map)['ok'] == false) {
          _accept(error.details);
        } else {
          _fail(error.status == 401 ? 'invalid_session' : 'request_failed',
              invoked: invoked);
        }
      } catch (_) {
        _fail('invalid_response', invoked: invoked);
      }
    } on TimeoutException catch (_) {
      if (!mounted || attempt != _attempt) return;
      _fail('timeout', invoked: invoked);
    } on FormatException catch (_) {
      if (!mounted || attempt != _attempt) return;
      _fail('invalid_response', invoked: invoked);
    } catch (_) {
      if (!mounted || attempt != _attempt) return;
      _fail(invoked ? 'request_failed' : 'entity_lookup_failed',
          invoked: invoked);
    }
  }

  void _continue() {
    if (_busy) return;
    final text = _answer.text.trim();
    if (text.isEmpty || text.length > 2000 || _intentId == null) {
      setState(() =>
          _fieldError = 'Escribí una respuesta de hasta 2000 caracteres.');
      return;
    }
    _pendingAnswer = text;
    FocusScope.of(context).unfocus();
    _submit();
  }

  String _text(dynamic value, [String fallback = '']) =>
      value is String && value.trim().isNotEmpty ? value.trim() : fallback;
  String _modality(dynamic value) =>
      const {
        'presencial': 'Presencial',
        'remoto': 'Remoto',
        'hibrido': 'Híbrido',
      }[value] ??
      'Modalidad sin informar';
  String _price(Map<String, dynamic> match) {
    String? amount(dynamic value) =>
        value is num && value.isFinite ? '$value' : null;
    final low = amount(match['price_min']);
    final high = amount(match['price_max']);
    if (low == null && high == null) return 'Precio a consultar';
    final value = low != null && high != null
        ? (low == high ? low : '$low–$high')
        : low != null
            ? 'Desde $low'
            : 'Hasta $high';
    final currency = _text(match['currency']);
    return currency.isEmpty
        ? '$value · moneda por confirmar'
        : '$value $currency';
  }

  static const _muted = Color(0xFF5F5B56);
  static const _line = Color(0xFFD9D6D1);
  static const _peach = Color(0xFFFFE4D0);
  TextStyle _type(double size,
          {FontWeight weight = FontWeight.w400, Color color = _charcoal}) =>
      GoogleFonts.plusJakartaSans(
          fontSize: size, fontWeight: weight, color: color, height: 1.4);

  static const Map<String, String> _names = {
    'jardineria': 'jardinería',
    'paisajismo': 'paisajismo',
    'viveros-plantas': 'viveros y plantas',
    'hogar-jardin': 'hogar y jardín',
    'decoracion': 'decoración',
    'carpinteria': 'carpintería',
    'pintura': 'pintura',
    'comunicacion-negocios': 'comunicación para negocios',
    'redes-sociales': 'redes sociales',
    'diseno-grafico': 'diseño gráfico',
    'creadores-contenido': 'creadores de contenido',
    'autos-mecanica': 'autos y mecánica',
    'nutricion': 'nutrición',
    'comida-casera': 'comida casera',
    'recetas-contenido': 'recetas',
    'deporte-entrenamiento': 'deporte y entrenamiento',
    'musica': 'música',
    'clases-particulares': 'clases particulares',
    'educacion': 'educación',
    'reposteria': 'repostería',
    'herreria': 'herrería',
    'plomeria': 'plomería',
    'cuidado-ninos': 'cuidado de niños',
    'cuidado-mayores': 'cuidado de mayores',
    'tramites': 'trámites',
    'fotografia': 'fotografía',
  };

  static String _readable(String slug) =>
      _names[slug] ?? slug.replaceAll('-', ' ');

  Widget _badge(String label, IconData icon, {bool warning = false}) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
            color: warning ? _peach : _cream,
            borderRadius: BorderRadius.circular(9)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: warning ? _burnt : _muted),
          const SizedBox(width: 6),
          Flexible(
              child: Text(label,
                  style: _type(12,
                      weight: FontWeight.w500,
                      color: warning ? _charcoal : _muted))),
        ]),
      );

  Widget _notice(String text, {IconData icon = Icons.info_outline}) =>
      Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: _peach, borderRadius: BorderRadius.circular(12)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: _burnt, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: _type(13))),
        ]),
      );

  Widget _statePanel(IconData icon, String title, String detail,
          {bool loading = false}) =>
      Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 16),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _line)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
              width: 40,
              height: 40,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: _cream, borderRadius: BorderRadius.circular(12)),
              child: loading
                  ? const CircularProgressIndicator(
                      color: _burnt,
                      strokeWidth: 2,
                      semanticsLabel: 'Buscando coincidencias')
                  : Icon(icon, size: 20, color: _burnt)),
          const SizedBox(height: 16),
          Text(title, style: _type(20, weight: FontWeight.w700)),
          const SizedBox(height: 7),
          Text(detail, style: _type(14, color: _muted)),
        ]),
      );

  Widget _card(Map<String, dynamic> match) {
    final warnings = List<String>.from(match['unverified'] as List);
    final city = _text(match['city']);
    final availability = match['availability_status'];
    final needsAvailability =
        warnings.contains('availability') || availability == 'unknown';
    final labels = <String>{
      if (warnings.contains('location')) 'Ubicación por confirmar',
      if (needsAvailability) 'Disponibilidad por confirmar',
      if (warnings.contains('budget')) 'Presupuesto por confirmar',
      if (warnings.any(
              (x) => !['location', 'availability', 'budget'].contains(x)) ||
          (match['hard_constraints_passed'] == null && warnings.isEmpty))
        'Hay datos por confirmar',
    };
    final schedule = needsAvailability
        ? 'Confirmá el horario con este perfil.'
        : availability == 'compatible'
            ? 'Disponibilidad declarada compatible'
            : 'Disponibilidad sin evaluar';
    final scheduleDetail = needsAvailability
        ? 'La información disponible no alcanza para confirmarlo.'
        : availability == 'compatible'
            ? 'Según los horarios publicados. Reconfirmá antes de acordar.'
            : 'No se evaluó un horario para esta búsqueda.';
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
            padding: const EdgeInsets.all(16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                        color: _cream, borderRadius: BorderRadius.circular(11)),
                    child: const Icon(Icons.work_outline,
                        color: _burnt, size: 19)),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text('PROPUESTA',
                          style: _type(10,
                              weight: FontWeight.w700, color: _muted)),
                      const SizedBox(height: 3),
                      Text(_text(match['title'], 'Propuesta sin título'),
                          style: _type(18, weight: FontWeight.w700)),
                      const SizedBox(height: 3),
                      Text(
                          _text(match['entity_name'],
                              'Perfil sin nombre público'),
                          style: _type(13,
                              weight: FontWeight.w500, color: _muted)),
                    ])),
              ]),
              const SizedBox(height: 12),
              Wrap(spacing: 6, runSpacing: 6, children: [
                _badge(
                    city.isEmpty
                        ? 'Ubicación sin informar'
                        : match['distance_km'] is num
                            ? '$city · a ${(match['distance_km'] as num).round()} km'
                            : city,
                    Icons.location_on_outlined),
                _badge(_modality(match['modality']), Icons.laptop_outlined),
              ]),
              const SizedBox(height: 12),
              Text(
                  _text(match['description'],
                      'Esta propuesta no incluye una descripción.'),
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                  style: _type(14, color: _muted)),
              const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Divider(height: 1, color: _line)),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.event_outlined,
                    size: 18,
                    color: availability == 'compatible' && !needsAvailability
                        ? _burnt
                        : _muted),
                const SizedBox(width: 8),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(schedule, style: _type(13, weight: FontWeight.w600)),
                      const SizedBox(height: 3),
                      Text(scheduleDetail, style: _type(12, color: _muted)),
                    ])),
              ]),
              if (labels.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text('ANTES DE AVANZAR',
                    style: _type(10, weight: FontWeight.w700, color: _muted)),
                const SizedBox(height: 7),
                Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: labels
                        .map((label) =>
                            _badge(label, Icons.info_outline, warning: true))
                        .toList()),
              ],
            ])),
        Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
                color: _cream, border: Border(top: BorderSide(color: _line))),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('PRECIO',
                  style: _type(10, weight: FontWeight.w700, color: _muted)),
              const SizedBox(height: 3),
              Text(_price(match), style: _type(17, weight: FontWeight.w700)),
              const SizedBox(height: 3),
              Text('Alcance y condiciones a confirmar.',
                  style: _type(12, color: _muted)),
              const SizedBox(height: 12),
              _contactButton(match),
            ])),
      ]),
    );
  }

  final Set<String> _requested = {};
  final Set<String> _requesting = {};

  Widget _contactButton(Map<String, dynamic> match) {
    final id = match['match_id'] as String;
    final done = _requested.contains(id);
    final busy = _requesting.contains(id);
    return SizedBox(
      width: double.infinity,
      child: TextButton(
        onPressed: done || busy ? null : () => _requestContact(match),
        style: TextButton.styleFrom(
          backgroundColor: done ? Colors.white : _orange,
          disabledBackgroundColor: done ? Colors.white : _orange.withOpacity(0.6),
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: done ? const BorderSide(color: _line) : BorderSide.none),
        ),
        child: busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: _charcoal))
            : Text(done ? 'Solicitud enviada' : 'Pedir contacto',
                style: _type(14, weight: FontWeight.w700)),
      ),
    );
  }

  Future<void> _requestContact(Map<String, dynamic> match) async {
    final id = match['match_id'] as String;
    final message = await _askIntro(match);
    if (message == null || !mounted) return;
    setState(() => _requesting.add(id));
    try {
      await SupaFlow.client.from('connections').insert({
        'match_id': id,
        'requester_entity_id': _entityId,
        'recipient_entity_id': match['entity_id'],
        'intro_message': message.trim().isEmpty ? null : message.trim(),
        'status': 'pending',
      }).timeout(const Duration(seconds: 15));
      if (!mounted) return;
      setState(() => _requested.add(id));
    } catch (e) {
      if (!mounted) return;
      final dup = e.toString().contains('23505') ||
          e.toString().contains('duplicate');
      if (dup) {
        setState(() => _requested.add(id));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text('No pudimos enviar la solicitud. Probá de nuevo.',
                style: _type(14, color: Colors.white))));
      }
    } finally {
      if (mounted) setState(() => _requesting.remove(id));
    }
  }

  Future<String?> _askIntro(Map<String, dynamic> match) {
    final controller = TextEditingController(
        text: 'Hola, vi tu publicación en Deytra. ¿Podemos hablar?');
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cream,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Pedir contacto', style: _type(19, weight: FontWeight.w700)),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
              'Le avisamos a ${_text(match['entity_name'], 'esta persona')}. Si acepta, van a poder hablar.',
              style: _type(14, color: _muted)),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            maxLines: 4,
            minLines: 2,
            maxLength: 400,
            style: _type(15),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              counterText: '',
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _line)),
            ),
          ),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('Cancelar', style: _type(14, weight: FontWeight.w600))),
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(controller.text),
              child: Text('Enviar',
                  style: _type(14, weight: FontWeight.w700, color: _burnt))),
        ],
      ),
    );
  }

  List<Widget> _body() {
    if (_busy || _status == 'loading')
      return [
        _statePanel(Icons.search, 'Buscando para vos',
            'Revisamos quién lo ofrece en Deytra y, si hace falta, también buscamos en internet. Puede tardar unos segundos.',
            loading: true),
        _notice(
            'Si cerrás, la búsqueda podría guardarse aunque no veas el resultado.'),
      ];
    if (_status == 'error')
      return [
        _statePanel(
            Icons.error_outline, 'No pudimos completar este paso', _error),
        if (_uncertain)
          _notice(
              'Podría haberse guardado. No la repetimos para evitar duplicados.'),
        if (_pendingAnswer != null)
          _notice('Aclaración conservada: $_pendingAnswer',
              icon: Icons.notes_outlined),
      ];
    if (_status == 'clarification')
      return [
        _statePanel(Icons.question_answer_outlined, 'Un detalle más',
            'Completá este dato para continuar con la misma búsqueda.'),
        Padding(
            padding: const EdgeInsets.only(top: 20, bottom: 12),
            child: Text(_question, style: _type(19, weight: FontWeight.w700))),
        TextField(
          controller: _answer,
          minLines: 2,
          maxLines: 5,
          maxLength: 2000,
          style: _type(15),
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            labelText: 'Tu respuesta',
            hintText: 'Agregá el detalle que falta',
            errorText: _fieldError,
            labelStyle: _type(14, color: _muted),
            floatingLabelStyle: _type(14, weight: FontWeight.w600),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.all(16),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: _line)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: _orange, width: 2)),
          ),
        ),
        if (_needsLocationAnswer)
          Text('Ej.: Funes, Roldán o Rosario.',
              style: _type(13, color: _muted)),
      ];
    if (_status == 'offer_saved')
      return [
        _statePanel(Icons.storefront_outlined, 'Parece que querés ofrecer algo',
            'Para que te encuentren, publicalo desde "Ofrecer lo que hago" en el inicio.'),
        _notice('Si en realidad estás buscando, contalo como necesidad. '
            'Ej.: "Busco quien me corte el pasto".'),
      ];
    if (_status == 'empty')
      return [
        _statePanel(
            Icons.travel_explore_outlined,
            _suggestions.isEmpty
                ? 'Todavía nadie lo ofrece en Deytra'
                : 'Todavía nadie lo ofrece en Deytra, pero encontré opciones',
            _place.isEmpty
                ? 'Apenas alguien lo publique, va a aparecer acá.'
                : 'Buscamos cerca de $_place. Apenas alguien lo publique, va a aparecer acá.'),
        _alertBox(),
        ..._suggestionSection(),
      ];
    return [
      Padding(
          padding: const EdgeInsets.only(top: 20, bottom: 6),
          child: Text(
              '${_matches.length} '
              '${_matches.length == 1 ? 'propuesta para explorar' : 'propuestas para explorar'}',
              style: _type(20, weight: FontWeight.w700))),
      Text('Revisá lo que ofrece cada perfil y los datos que faltan confirmar.',
          style: _type(14, color: _muted)),
      Container(
          margin: const EdgeInsets.only(top: 12),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _line)),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 14),
            childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            leading: const Icon(Icons.tune, size: 18, color: _muted),
            iconColor: _charcoal,
            collapsedIconColor: _muted,
            title: Text('Cómo se ordenan estas propuestas',
                style: _type(13, weight: FontWeight.w600)),
            children: [
              Text(
                  'Ordenadas por pertinencia y cercanía. '
                  'Confirmá horario y presupuesto con cada persona antes de acordar.',
                  style: _type(13, color: _muted))
            ],
          )),
      if (_expanded)
        _notice('No había opciones a menos de 30 km, así que ampliamos la búsqueda.',
            icon: Icons.radar_outlined),
      ..._matches.map(_card),
      if (_matches.length < 3) _alertBox(),
      ..._suggestionSection(),
    ];
  }

  /// "Avisame cuando aparezca": guarda la búsqueda y avisa cuando alguien la publique.
  Widget _alertBox() {
    final id = _intentId;
    if (id == null) return const SizedBox.shrink();
    final saved = _alertFor == id;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: saved ? const Color(0xFFE6F2EC) : const Color(0xFFFFEFE4),
          borderRadius: BorderRadius.circular(16)),
      child: Row(children: [
        Icon(saved ? Icons.check_circle_outline : Icons.notifications_active_outlined,
            color: saved ? const Color(0xFF24734F) : _burnt, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
              saved
                  ? 'Listo. Te avisamos en Avisos cuando alguien lo publique.'
                  : '¿Querés que te avisemos cuando alguien lo ofrezca?',
              style: _type(14, weight: FontWeight.w600)),
        ),
        if (!saved) ...[
          const SizedBox(width: 8),
          TextButton(
            onPressed: _alertBusy
                ? null
                : () async {
                    setState(() => _alertBusy = true);
                    try {
                      await DeytraData.createAlert(id);
                      if (mounted) setState(() => _alertFor = id);
                    } catch (_) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                            content: Text('No pudimos guardar el aviso. Probá de nuevo.')));
                      }
                    } finally {
                      if (mounted) setState(() => _alertBusy = false);
                    }
                  },
            style: TextButton.styleFrom(
              backgroundColor: _charcoal,
              minimumSize: const Size(0, 40),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _alertBusy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text('Avisame', style: _type(14, weight: FontWeight.w700, color: Colors.white)),
          ),
        ],
      ]),
    );
  }

  List<Widget> _suggestionSection() {
    if (_suggestions.isEmpty) return const [];
    return [
      Padding(
          padding: const EdgeInsets.only(top: 24, bottom: 4),
          child: Text('También encontré en internet',
              style: _type(18, weight: FontWeight.w700))),
      Text('Negocios y cuentas externas a Deytra. Revisalos antes de comprar o contratar.',
          style: _type(13, color: _muted)),
      ..._suggestions.map(_suggestionCard),
    ];
  }

  Widget _suggestionCard(Map<String, dynamic> s) {
    final kind = _text(s['kind'], 'negocio');
    final icon = kind == 'instagram'
        ? Icons.photo_camera_outlined
        : kind == 'tienda'
            ? Icons.shopping_bag_outlined
            : kind == 'profesional'
                ? Icons.person_outline
                : Icons.storefront_outlined;
    final scope = s['scope'] == 'nacional' ? 'Envíos a todo el país' : 'En tu zona';
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                  color: _cream, borderRadius: BorderRadius.circular(11)),
              child: Icon(icon, color: _burnt, size: 19)),
          const SizedBox(width: 12),
          Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('SUGERENCIA EXTERNA',
                style: _type(10, weight: FontWeight.w700, color: _muted)),
            const SizedBox(height: 3),
            Text(_text(s['name']), style: _type(17, weight: FontWeight.w700)),
          ])),
        ]),
        if (_text(s['description']).isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(_text(s['description']), style: _type(14, color: _muted)),
        ],
        const SizedBox(height: 10),
        _badge(scope, Icons.local_shipping_outlined),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: () => launchUrl(Uri.parse(_text(s['url'])),
                mode: LaunchMode.externalApplication),
            style: TextButton.styleFrom(
              backgroundColor: _cream,
              minimumSize: const Size(0, 46),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(color: _line)),
            ),
            child: Text(kind == 'instagram' ? 'Ver en Instagram' : 'Abrir sitio',
                style: _type(14, weight: FontWeight.w700)),
          ),
        ),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => _invite(s),
            icon: const Icon(Icons.person_add_alt_1_outlined,
                size: 18, color: _burnt),
            label: Text('Invitarlo a Deytra',
                style: _type(13, weight: FontWeight.w600, color: _burnt)),
          ),
        ),
      ]),
    );
  }

  /// Abre WhatsApp con una invitación lista para reenviar al negocio sugerido.
  Future<void> _invite(Map<String, dynamic> s) async {
    final name = _text(s['name']);
    final text = 'Hola${name.isEmpty ? '' : ' $name'}. Te encontré en internet '
        'buscando algo que ofrecés y me gustaría que estés en Deytra, una app '
        'donde la gente de la zona cuenta lo que necesita y encuentra quién se lo '
        'resuelve. Sumarte es gratis: https://revolucionred.github.io/Deytra/';
    await launchUrl(
        Uri.parse('https://wa.me/?text=${Uri.encodeComponent(text)}'),
        mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final compact = size.width < 480;
    return Dialog(
      backgroundColor: _cream,
      insetPadding: EdgeInsets.all(compact ? 12 : 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints:
            BoxConstraints(maxWidth: 720, maxHeight: size.height * .88),
        child: DefaultTextStyle(
            style: _type(15),
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                      padding: EdgeInsets.fromLTRB(
                          compact ? 18 : 24, 18, compact ? 18 : 24, 18),
                      decoration: const BoxDecoration(
                          color: _cream,
                          border: Border(bottom: BorderSide(color: _line))),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Expanded(
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Image.network(
                                    'https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/deytra-aefqye/assets/xkmv4o21mcrj/logo.png',
                                    width: 108,
                                    height: 38,
                                    fit: BoxFit.contain,
                                    semanticLabel: 'Deytra',
                                    errorBuilder: (_, __, ___) => Text('Deytra',
                                        style:
                                            _type(18, weight: FontWeight.w700)),
                                  ),
                                ),
                              ),
                              Text('EXPLORAR',
                                  style: _type(10,
                                      weight: FontWeight.w600, color: _muted)),
                            ]),
                            const SizedBox(height: 16),
                            Text('Tu próxima conexión',
                                style: _type(compact ? 23 : 26,
                                    weight: FontWeight.w700)),
                          ])),
                  Flexible(
                      child: SingleChildScrollView(
                          padding: EdgeInsets.fromLTRB(
                              compact ? 16 : 24, 16, compact ? 16 : 24, 20),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (!_sessionChanged && _original.isNotEmpty)
                                  Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                          color: Colors.white,
                                          border: Border.all(color: _line),
                                          borderRadius:
                                              BorderRadius.circular(20)),
                                      child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text('TU BÚSQUEDA',
                                                style: _type(10,
                                                    weight: FontWeight.w700,
                                                    color: _muted)),
                                            const SizedBox(height: 6),
                                            Text(_original,
                                                maxLines: 4,
                                                overflow: TextOverflow.ellipsis,
                                                style: _type(15,
                                                    weight: FontWeight.w500)),
                                            if (!_busy &&
                                                _status != 'error' &&
                                                _category.isNotEmpty)
                                              Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                          top: 8),
                                                  child: Text(
                                                      'Lo buscamos en: $_category',
                                                      style: _type(13,
                                                          color: _muted))),
                                          ])),
                                ..._body(),
                                if (!_busy &&
                                    _status != 'error' &&
                                    _timezoneAssumed &&
                                    _hasTimeWindow)
                                  _notice(
                                      'Las referencias de horario se interpretaron con la '
                                      'zona horaria de Buenos Aires.',
                                      icon: Icons.schedule),
                              ]))),
                  Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: compact ? 16 : 24, vertical: 14),
                      decoration: const BoxDecoration(
                          color: Colors.white,
                          border: Border(top: BorderSide(color: _line))),
                      child: Wrap(
                          alignment: WrapAlignment.end,
                          spacing: 10,
                          runSpacing: 8,
                          children: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              style: TextButton.styleFrom(
                                  foregroundColor: _charcoal,
                                  minimumSize: const Size(88, 48),
                                  textStyle:
                                      _type(14, weight: FontWeight.w600)),
                              child: const Text('Cerrar'),
                            ),
                            if (!_busy && _status == 'clarification')
                              ElevatedButton(
                                onPressed: _continue,
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: _orange,
                                    foregroundColor: _charcoal,
                                    elevation: 0,
                                    minimumSize: const Size(140, 48),
                                    textStyle:
                                        _type(14, weight: FontWeight.w700),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(24))),
                                child: const Text('Continuar búsqueda'),
                              ),
                            if (!_busy && _status == 'error' && _canRetry)
                              ElevatedButton(
                                onPressed: _submit,
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: _orange,
                                    foregroundColor: _charcoal,
                                    elevation: 0,
                                    minimumSize: const Size(140, 48),
                                    textStyle:
                                        _type(14, weight: FontWeight.w700),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(24))),
                                child: const Text('Reintentar'),
                              ),
                          ])),
                ])),
      ),
    );
  }
}
