// Pantalla "Ofrecer algo": cualquier persona, tenga o no un negocio,
// publica lo que sabe hacer para que otros la encuentren.
import 'package:flutter/material.dart';
import 'deytra_data.dart';
import 'deytra_ui.dart';

class OfferPageWidget extends StatefulWidget {
  const OfferPageWidget({super.key, this.offer});
  static String routeName = 'OfferPage';
  static String routePath = '/ofrecer';

  /// Si llega una oferta, la pantalla la edita.
  final Map<String, dynamic>? offer;

  @override
  State<OfferPageWidget> createState() => _OfferPageWidgetState();
}

class _OfferPageWidgetState extends State<OfferPageWidget> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _city = TextEditingController();
  final _price = TextEditingController();
  final _filter = TextEditingController();
  List<Map<String, dynamic>> _categories = [];
  String? _categoryId;
  String _modality = 'presencial';
  String? _entityId;
  bool _loading = true;
  bool _saving = false;
  String? _loadError;

  static const _examples = [
    'Corto el pasto y mantengo jardines',
    'Cocino viandas caseras para la semana',
    'Doy clases de guitarra a principiantes',
    'Hago tortas para cumpleaños',
  ];

  final String _hint =
      _examples[DateTime.now().millisecondsSinceEpoch % _examples.length];

  bool get _editing => widget.offer != null;

  @override
  void initState() {
    super.initState();
    final o = widget.offer;
    if (o != null) {
      _title.text = (o['title'] ?? '').toString();
      _description.text = (o['description'] ?? '').toString();
      _city.text = (o['city'] ?? '').toString();
      final p = o['price_min'];
      if (p != null) _price.text = p.toString();
      _categoryId = o['category_id']?.toString();
      _modality = (o['modality'] ?? 'presencial').toString();
    }
    _filter.addListener(() => setState(() {}));
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final results = await Future.wait([
        DeytraData.categories(),
        DeytraData.myEntity(),
      ]);
      final entity = results[1] as Map<String, dynamic>?;
      if (!mounted) return;
      setState(() {
        _categories = results[0] as List<Map<String, dynamic>>;
        _entityId = entity?['id']?.toString();
        if (!_editing && _city.text.isEmpty) {
          _city.text = (entity?['city'] ?? '').toString();
        }
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = DeytraData.friendlyError(e);
      });
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _city.dispose();
    _price.dispose();
    _filter.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.length < 4) {
      showDMessage(context, 'Contá en una frase qué ofrecés.', error: true);
      return;
    }
    if (_categoryId == null) {
      showDMessage(context, 'Elegí el rubro que mejor te describe.',
          error: true);
      return;
    }
    if (_modality != 'remoto' && _city.text.trim().isEmpty) {
      showDMessage(context, 'Indicá tu ciudad para que te encuentren cerca.',
          error: true);
      return;
    }
    if (_entityId == null) {
      showDMessage(context, 'Completá tu perfil antes de publicar.',
          error: true);
      return;
    }
    final priceText = _price.text.replaceAll(RegExp(r'[^0-9]'), '');
    final cat = _categories.firstWhere((c) => c['id'] == _categoryId,
        orElse: () => <String, dynamic>{});
    setState(() => _saving = true);
    try {
      await DeytraData.saveOffer(
        id: widget.offer?['id']?.toString(),
        entityId: _entityId!,
        title: title,
        categoryId: _categoryId!,
        categoryName: (cat['name_es'] ?? '').toString(),
        description: _description.text,
        modality: _modality,
        city: _modality == 'remoto' ? null : _city.text,
        priceFrom: priceText.isEmpty ? null : int.parse(priceText),
      );
      if (!mounted) return;
      showDMessage(context,
          _editing ? 'Cambios guardados.' : 'Listo. Ya te pueden encontrar.');
      Navigator.of(context).maybePop(true);
    } catch (e) {
      if (mounted) showDMessage(context, DeytraData.friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DColors.cream,
      appBar: DHeader(title: _editing ? 'Editar lo que ofrecés' : 'Ofrecer algo'),
      body: SafeArea(
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: DColors.burnt))
            : _loadError != null
                ? Padding(
                    padding: const EdgeInsets.all(24),
                    child: DEmpty(
                      title: 'No pudimos cargar esta pantalla',
                      detail: _loadError!,
                      action: DButton(
                          label: 'Reintentar', onPressed: _load, expand: false),
                    ),
                  )
                : _form(),
      ),
    );
  }

  Widget _form() {
    final q = _filter.text.trim().toLowerCase();
    final visible = _categories
        .where((c) =>
            q.isEmpty ||
            (c['name_es'] ?? '').toString().toLowerCase().contains(q) ||
            c['id'] == _categoryId)
        .toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      children: [
        Text(
          'No hace falta tener un negocio. Si sabés hacer algo que a otra persona le sirve, publicalo.',
          style: DText.body(15, color: DColors.muted),
        ),
        const SizedBox(height: 24),
        DField(
          controller: _title,
          label: '¿Qué ofrecés?',
          hint: 'Ej.: $_hint',
          maxLength: 90,
        ),
        const SizedBox(height: 24),
        Text('Rubro', style: DText.body(14, weight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextField(
          controller: _filter,
          style: DText.body(15),
          decoration: InputDecoration(
            isDense: true,
            hintText: 'Buscar rubro',
            hintStyle: DText.body(14, color: DColors.muted),
            prefixIcon: const Padding(
              padding: EdgeInsets.all(12),
              child: DIcon('search', size: 18, color: DColors.muted),
            ),
            filled: true,
            fillColor: Colors.white,
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: DColors.line)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: DColors.orange)),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final c in visible)
              DChip(
                label: (c['name_es'] ?? '').toString(),
                selected: c['id'] == _categoryId,
                onTap: () => setState(() => _categoryId = c['id']?.toString()),
              ),
          ],
        ),
        const SizedBox(height: 24),
        Text('¿Cómo lo hacés?', style: DText.body(14, weight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final m in const ['presencial', 'remoto', 'hibrido'])
            DChip(
              label: modalityLabel(m),
              selected: _modality == m,
              onTap: () => setState(() => _modality = m),
            ),
        ]),
        if (_modality != 'remoto') ...[
          const SizedBox(height: 24),
          DField(
            controller: _city,
            label: 'Ciudad o zona',
            hint: 'Ej.: Carcarañá',
            maxLength: 80,
          ),
        ],
        const SizedBox(height: 24),
        DField(
          controller: _description,
          label: 'Contalo con tus palabras (opcional)',
          hint: 'Qué incluye, cómo trabajás, desde cuándo lo hacés',
          maxLines: 5,
          maxLength: 600,
        ),
        const SizedBox(height: 24),
        DField(
          controller: _price,
          label: 'Precio de referencia en pesos (opcional)',
          hint: 'Ej.: 15000',
          keyboardType: TextInputType.number,
          maxLength: 10,
          helper: 'Es solo orientativo. El precio final lo acuerdan entre ustedes.',
        ),
        const SizedBox(height: 32),
        DButton(
          label: _editing ? 'Guardar cambios' : 'Publicar',
          busy: _saving,
          onPressed: _save,
        ),
      ],
    );
  }
}
