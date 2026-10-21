// Cuenta: mi perfil, lo que ofrezco, cerrar sesión y eliminar la cuenta.
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '/auth/supabase_auth/auth_util.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import 'deytra_data.dart';
import 'deytra_ui.dart';
import 'admin_page.dart';
import 'legal_page.dart';
import 'offer_page.dart';

class AccountPageWidget extends StatefulWidget {
  const AccountPageWidget({super.key});
  static String routeName = 'AccountPage';
  static String routePath = '/cuenta';
  @override
  State<AccountPageWidget> createState() => _AccountPageWidgetState();
}

class _AccountPageWidgetState extends State<AccountPageWidget> {
  final _name = TextEditingController();
  final _city = TextEditingController();
  final _bio = TextEditingController();
  final _instagram = TextEditingController();
  final _whatsapp = TextEditingController();
  Map<String, dynamic>? _entity;
  List<Map<String, dynamic>> _offers = [];
  bool _loading = true;
  bool _saving = false;
  bool _deleting = false;
  bool _isAdmin = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _city.dispose();
    _bio.dispose();
    _instagram.dispose();
    _whatsapp.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final entity = await DeytraData.myEntity();
      final admin = await DeytraData.isAdmin();
      final offers = entity == null
          ? <Map<String, dynamic>>[]
          : await DeytraData.myOffers(entity['id'].toString());
      if (!mounted) return;
      setState(() {
        _entity = entity;
        _offers = offers;
        _isAdmin = admin;
        _name.text = (entity?['name'] ?? '').toString();
        _city.text = (entity?['city'] ?? '').toString();
        _bio.text = (entity?['description'] ?? '').toString();
        _instagram.text = (entity?['instagram_url'] ?? '')
            .toString()
            .replaceFirst(RegExp(r'^https?://(www\.)?instagram\.com/'), '@');
        final wa = (entity?['whatsapp'] ?? '').toString();
        _whatsapp.text = wa.isEmpty ? '' : '+$wa';
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = DeytraData.friendlyError(e);
      });
    }
  }

  Future<void> _saveProfile() async {
    if (_entity == null) return;
    if (_name.text.trim().length < 2) {
      showDMessage(context, 'Tu nombre no puede quedar vacío.', error: true);
      return;
    }
    if (_whatsapp.text.trim().isNotEmpty &&
        DeytraData.normalizeWhatsapp(_whatsapp.text) == null) {
      showDMessage(context,
          'Revisá el WhatsApp: escribilo con código de área, por ejemplo 341 555 1234.',
          error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      await DeytraData.updateProfile(
        entityId: _entity!['id'].toString(),
        name: _name.text,
        city: _city.text,
        description: _bio.text,
        instagramUrl: _instagram.text,
        whatsapp: _whatsapp.text,
      );
      if (mounted) showDMessage(context, 'Perfil actualizado.');
    } catch (e) {
      if (mounted) showDMessage(context, DeytraData.friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _openOffer([Map<String, dynamic>? offer]) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => OfferPageWidget(offer: offer)),
    );
    if (changed == true) _load();
  }

  Future<void> _toggle(Map<String, dynamic> o) async {
    try {
      await DeytraData.setOfferActive(o['id'].toString(), o['is_active'] != true);
      await _load();
    } catch (e) {
      if (mounted) showDMessage(context, DeytraData.friendlyError(e), error: true);
    }
  }

  Future<void> _remove(Map<String, dynamic> o) async {
    final ok = await confirmD(context,
        title: '¿Eliminar esta publicación?',
        detail: 'Deja de aparecer en las búsquedas. No se puede deshacer.',
        confirm: 'Eliminar',
        danger: true);
    if (!ok) return;
    try {
      await DeytraData.deleteOffer(o['id'].toString());
      await _load();
    } catch (e) {
      if (mounted) showDMessage(context, DeytraData.friendlyError(e), error: true);
    }
  }

  Future<void> _logout() async {
    await authManager.signOut();
    if (!mounted) return;
    context.goNamedAuth(AuthPageWidget.routeName, context.mounted);
  }

  Future<void> _deleteAccount() async {
    final ok = await confirmD(context,
        title: '¿Eliminar tu cuenta?',
        detail:
            'Se borran tu perfil, lo que publicaste, tus búsquedas y tus conexiones. No se puede deshacer.',
        confirm: 'Eliminar cuenta',
        danger: true);
    if (!ok) return;
    setState(() => _deleting = true);
    try {
      await DeytraData.deleteAccount();
      if (!mounted) return;
      context.goNamedAuth(AuthPageWidget.routeName, context.mounted);
    } catch (e) {
      if (mounted) {
        setState(() => _deleting = false);
        showDMessage(context, DeytraData.friendlyError(e), error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DColors.cream,
      appBar: const DHeader(title: 'Tu cuenta'),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: DColors.burnt))
            : _error != null
                ? Padding(
                    padding: const EdgeInsets.all(24),
                    child: DEmpty(
                      title: 'No pudimos cargar tu cuenta',
                      detail: _error!,
                      action: DButton(
                          label: 'Reintentar', onPressed: _load, expand: false),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
                    children: [
                      if (_isAdmin) ...[
                        DCard(
                          onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) => const AdminPageWidget())),
                          child: Row(children: [
                            const Icon(Icons.insights_outlined,
                                color: DColors.burnt),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Panel de Deytra',
                                        style: DText.display(16)),
                                    Text(
                                        'Uso, lo que falta en la app, gasto de IA y denuncias',
                                        style: DText.body(13,
                                            color: DColors.muted)),
                                  ]),
                            ),
                            const DIcon('arrow-right', size: 20),
                          ]),
                        ),
                        const SizedBox(height: 28),
                      ],
                      Text('LO QUE OFRECÉS', style: DText.label()),
                      const SizedBox(height: 10),
                      if (_offers.isEmpty)
                        DCard(
                          onTap: () => _openOffer(),
                          child: Row(children: [
                            Container(
                              width: 44,
                              height: 44,
                              padding: const EdgeInsets.all(11),
                              decoration: BoxDecoration(
                                  color: DColors.peach,
                                  borderRadius: BorderRadius.circular(14)),
                              child: const DIcon('opportunity',
                                  color: DColors.burnt),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Publicá lo que sabés hacer',
                                        style: DText.display(16)),
                                    const SizedBox(height: 2),
                                    Text(
                                        'Cocinar, enseñar, arreglar, cuidar. Todo suma.',
                                        style: DText.body(13,
                                            color: DColors.muted)),
                                  ]),
                            ),
                            const DIcon('arrow-right', size: 20),
                          ]),
                        )
                      else ...[
                        for (final o in _offers)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _offerCard(o),
                          ),
                        DButton(
                            label: 'Agregar otra',
                            secondary: true,
                            onPressed: () => _openOffer()),
                      ],
                      const SizedBox(height: 32),
                      Text('TU PERFIL', style: DText.label()),
                      const SizedBox(height: 10),
                      DField(controller: _name, label: 'Nombre', maxLength: 60),
                      const SizedBox(height: 16),
                      DField(
                          controller: _city,
                          label: 'Ciudad',
                          hint: 'Ej.: Carcarañá',
                          maxLength: 80),
                      const SizedBox(height: 16),
                      DField(
                          controller: _bio,
                          label: 'Sobre vos',
                          maxLines: 4,
                          maxLength: 400),
                      const SizedBox(height: 16),
                      DField(
                        controller: _instagram,
                        label: 'Instagram',
                        hint: '@tuusuario',
                        maxLength: 80,
                        helper:
                            'Solo lo ve quien aceptaste como conexión.',
                      ),
                      const SizedBox(height: 16),
                      DField(
                        controller: _whatsapp,
                        label: 'WhatsApp (opcional)',
                        hint: 'Ej.: 341 555 1234',
                        maxLength: 24,
                        keyboardType: TextInputType.phone,
                        helper:
                            'Solo lo ve quien aceptaste como conexión. Si no lo cargás, igual pueden hablar por el chat de Deytra.',
                      ),
                      const SizedBox(height: 20),
                      DButton(
                          label: 'Guardar perfil',
                          busy: _saving,
                          onPressed: _saveProfile),
                      const SizedBox(height: 32),
                      Text('LEGALES', style: DText.label()),
                      const SizedBox(height: 4),
                      _legalLink('Política de privacidad', LegalDoc.privacy),
                      _legalLink('Términos y condiciones', LegalDoc.terms),
                      const SizedBox(height: 24),
                      DButton(
                          label: 'Cerrar sesión',
                          secondary: true,
                          onPressed: _logout),
                      const SizedBox(height: 12),
                      DButton(
                          label: 'Eliminar mi cuenta',
                          danger: true,
                          busy: _deleting,
                          onPressed: _deleteAccount),
                    ],
                  ),
      ),
    );
  }

  /// Comparte lo que ofrezco por WhatsApp, con el link para encontrarme en Deytra.
  Future<void> _share(Map<String, dynamic> o) async {
    final title = (o['title'] ?? '').toString();
    final city = (o['city'] ?? _city.text).toString().trim();
    final text = 'Ahora también me encontrás en Deytra: $title'
        '${city.isEmpty ? '' : ' en $city'}. Contá lo que necesitás y te conecta '
        'con quien puede resolverlo. https://revolucionred.github.io/Deytra/';
    await launchUrl(
        Uri.parse('https://wa.me/?text=${Uri.encodeComponent(text)}'),
        mode: LaunchMode.externalApplication);
  }

  Widget _legalLink(String label, LegalDoc doc) => ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(label, style: DText.body(15)),
        trailing: const DIcon('arrow-right', size: 18),
        onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => LegalPageWidget(doc: doc))),
      );

  Widget _offerCard(Map<String, dynamic> o) {
    final active = o['is_active'] == true;
    final details = [
      (o['category_raw'] ?? '').toString(),
      modalityLabel(o['modality']?.toString()),
      (o['city'] ?? '').toString(),
    ].where((s) => s.isNotEmpty).join(' · ');
    return DCard(
      onTap: () => _openOffer(o),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
              child: Text((o['title'] ?? '').toString(),
                  style: DText.display(16))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: active ? const Color(0xFFE6F2EC) : DColors.cream,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(active ? 'Visible' : 'Pausada',
                style: DText.body(12,
                    weight: FontWeight.w600,
                    color: active ? DColors.success : DColors.muted)),
          ),
        ]),
        const SizedBox(height: 4),
        Text(details, style: DText.body(13, color: DColors.muted)),
        const SizedBox(height: 8),
        Wrap(children: [
          TextButton(
            onPressed: () => _toggle(o),
            child: Text(active ? 'Pausar' : 'Volver a mostrar',
                style: DText.body(14,
                    weight: FontWeight.w600, color: DColors.action)),
          ),
          TextButton(
            onPressed: () => _share(o),
            child: Text('Compartir',
                style: DText.body(14,
                    weight: FontWeight.w600, color: DColors.action)),
          ),
          TextButton(
            onPressed: () => _remove(o),
            child: Text('Eliminar',
                style: DText.body(14, color: DColors.error)),
          ),
        ]),
      ]),
    );
  }
}
