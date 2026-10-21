// Panel de Deytra: solo lo ve la dueña (lo controla la base con is_deytra_admin).
// Muestra cómo se usa la app, qué se busca y no aparece (a quién invitar),
// cuánto gasta la IA y las denuncias.
import 'package:flutter/material.dart';
import 'deytra_data.dart';
import 'deytra_ui.dart';

class AdminPageWidget extends StatefulWidget {
  const AdminPageWidget({super.key});
  @override
  State<AdminPageWidget> createState() => _AdminPageWidgetState();
}

class _AdminPageWidgetState extends State<AdminPageWidget> {
  int _days = 30;
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final d = await DeytraData.adminOverview(_days);
      if (!mounted) return;
      setState(() {
        _data = d;
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

  Map<String, dynamic> _map(String k) =>
      Map<String, dynamic>.from((_data?[k] as Map?) ?? const {});
  List<Map<String, dynamic>> _list(String k) => ((_data?[k] as List?) ?? const [])
      .map((e) => Map<String, dynamic>.from(e as Map))
      .toList();
  static int _n(dynamic v) => (v as num?)?.toInt() ?? 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DColors.cream,
      appBar: const DHeader(title: 'Panel de Deytra'),
      body: SafeArea(
        child: RefreshIndicator(
          color: DColors.burnt,
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
            children: [
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final d in const [7, 30, 90])
                  DChip(
                    label: 'Últimos $d días',
                    selected: _days == d,
                    onTap: () {
                      if (_days == d) return;
                      setState(() => _days = d);
                      _load();
                    },
                  ),
              ]),
              const SizedBox(height: 20),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.only(top: 48),
                  child: Center(
                      child: CircularProgressIndicator(color: DColors.burnt)),
                )
              else if (_error != null)
                DEmpty(
                  title: 'No pudimos cargar el panel',
                  detail: _error!,
                  action: DButton(
                      label: 'Reintentar', onPressed: _load, expand: false),
                )
              else
                ..._content(),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _content() {
    final t = _map('totals');
    final ai = _map('ai');
    final searches = _n(t['searches']);
    final answered = _n(t['searches_answered']);
    final rate = searches == 0 ? 0 : (answered * 100 / searches).round();
    final conns = _n(t['connections']);
    final accepted = _n(t['accepted']);
    return [
      _section('ACTIVIDAD'),
      _tiles([
        ('Búsquedas', '$searches', '$rate % encontró algo en Deytra'),
        ('Conexiones', '$conns', '$accepted aceptadas'),
        ('Mensajes', '${_n(t['messages'])}', 'en el chat'),
        ('Esperando aviso', '${_n(t['alerts_active'])}', 'búsquedas guardadas'),
      ]),
      const SizedBox(height: 12),
      _tiles([
        ('Personas', '${_n(t['people'])}', '${_n(t['new_people'])} nuevas'),
        ('Ofertas visibles', '${_n(t['offers_active'])}', '${_n(t['offers_new'])} nuevas'),
      ]),
      const SizedBox(height: 28),
      _section('BÚSQUEDAS POR DÍA · ÚLTIMAS 2 SEMANAS'),
      _DailyBars(points: _list('daily')),
      const SizedBox(height: 28),
      _section('LO QUE BUSCAN Y NO ENCUENTRAN'),
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(
            'Esta es tu lista de a quién invitar primero: rubros y zonas donde la gente buscó y en Deytra no había nadie.',
            style: DText.body(14, color: DColors.muted)),
      ),
      ..._unanswered(),
      const SizedBox(height: 28),
      _section('RUBROS MÁS BUSCADOS'),
      _ranking(_list('top_topics'), 'topic'),
      const SizedBox(height: 28),
      _section('CIUDADES'),
      _ranking(_list('top_cities'), 'city'),
      const SizedBox(height: 28),
      _section('INTELIGENCIA ARTIFICIAL'),
      _tiles([
        ('Gasto estimado', 'USD ${((ai['cost_usd'] as num?) ?? 0).toStringAsFixed(2)}', 'en el período'),
        ('Búsquedas en internet', '${_n(ai['web_searches'])}', '${_n(ai['web_reused'])} reutilizadas sin costo'),
      ]),
      const SizedBox(height: 6),
      Text(
          'El gasto es una estimación con los precios actuales. El dato exacto está en la consola del proveedor de IA.',
          style: DText.body(12, color: DColors.muted)),
      const SizedBox(height: 28),
      _section('DENUNCIAS'),
      ..._reports(),
    ];
  }

  Widget _section(String label) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(label, style: DText.label()),
      );

  Widget _tiles(List<(String, String, String)> items) => LayoutBuilder(
        builder: (context, c) {
          final w = (c.maxWidth - 12) / 2;
          return Wrap(spacing: 12, runSpacing: 12, children: [
            for (final (label, value, detail) in items)
              SizedBox(
                width: w,
                child: DCard(
                  padding: 16,
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(label, style: DText.body(13, color: DColors.muted)),
                        const SizedBox(height: 6),
                        Text(value, style: DText.display(26)),
                        const SizedBox(height: 4),
                        Text(detail,
                            style: DText.body(12, color: DColors.muted)),
                      ]),
                ),
              ),
          ]);
        },
      );

  List<Widget> _unanswered() {
    final rows = _list('unanswered');
    if (rows.isEmpty) {
      return [
        Text('Por ahora todas las búsquedas encontraron algo, o todavía no hay búsquedas.',
            style: DText.body(14, color: DColors.muted)),
      ];
    }
    return [
      for (final r in rows)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: DCard(
            padding: 14,
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${r['topic']} · ${r['city']}',
                          style: DText.body(15, weight: FontWeight.w700)),
                      if ((r['example'] ?? '').toString().isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text('"${r['example']}"',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: DText.body(13, color: DColors.muted)),
                      ],
                    ]),
              ),
              const SizedBox(width: 10),
              Text('${_n(r['n'])}',
                  style: DText.display(18, color: DColors.ink)),
            ]),
          ),
        ),
    ];
  }

  Widget _ranking(List<Map<String, dynamic>> rows, String key) {
    if (rows.isEmpty) {
      return Text('Sin datos en este período.',
          style: DText.body(14, color: DColors.muted));
    }
    final max = rows.map((r) => _n(r['n'])).fold<int>(1, (a, b) => b > a ? b : a);
    return DCard(
      padding: 16,
      child: Column(children: [
        for (final r in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(children: [
              SizedBox(
                width: 120,
                child: Text((r[key] ?? '').toString(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: DText.body(13)),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, c) => Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      width: (c.maxWidth * _n(r['n']) / max).clamp(4.0, c.maxWidth),
                      height: 12,
                      decoration: const BoxDecoration(
                        color: DColors.burnt,
                        borderRadius: BorderRadius.horizontal(right: Radius.circular(4)),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 28,
                child: Text('${_n(r['n'])}',
                    textAlign: TextAlign.right,
                    style: DText.body(13, weight: FontWeight.w600)),
              ),
            ]),
          ),
      ]),
    );
  }

  List<Widget> _reports() {
    final rows = _list('reports');
    if (rows.isEmpty) {
      return [
        Text('No hay denuncias.', style: DText.body(14, color: DColors.muted)),
      ];
    }
    return [
      for (final r in rows)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: DCard(
            padding: 14,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text((r['reported_name'] ?? 'Perfil eliminado').toString(),
                  style: DText.body(15, weight: FontWeight.w700)),
              const SizedBox(height: 3),
              Text(
                  [
                    (r['reason'] ?? '').toString(),
                    if ((r['details'] ?? '').toString().isNotEmpty)
                      r['details'].toString(),
                  ].join(' · '),
                  style: DText.body(13, color: DColors.muted)),
              const SizedBox(height: 3),
              Text(
                  r['status'] == 'open' ? 'Sin revisar' : r['status'].toString(),
                  style: DText.body(12,
                      weight: FontWeight.w600,
                      color: r['status'] == 'open' ? DColors.action : DColors.muted)),
            ]),
          ),
        ),
    ];
  }
}

/// Barras de búsquedas por día: una sola serie, sin leyenda (el título la nombra),
/// etiqueta directa solo en el máximo y en hoy, y el valor de cada día al tocar.
class _DailyBars extends StatelessWidget {
  const _DailyBars({required this.points});
  final List<Map<String, dynamic>> points;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return Text('Sin datos.', style: DText.body(14, color: DColors.muted));
    }
    final values = points.map((p) => (p['searches'] as num?)?.toInt() ?? 0).toList();
    final max = values.fold<int>(0, (a, b) => b > a ? b : a);
    final maxIdx = values.indexOf(max);
    const h = 120.0;
    return DCard(
      padding: 16,
      child: Column(children: [
        SizedBox(
          height: h + 18,
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            for (var i = 0; i < values.length; i++)
              Expanded(
                child: Tooltip(
                  message: '${_label(points[i]['day'])}: ${values[i]} '
                      '${values[i] == 1 ? 'búsqueda' : 'búsquedas'}',
                  triggerMode: TooltipTriggerMode.tap,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1),
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (values[i] > 0 &&
                              (i == maxIdx || i == values.length - 1))
                            Text('${values[i]}',
                                style: DText.body(11,
                                    weight: FontWeight.w700,
                                    color: DColors.ink)),
                          const SizedBox(height: 2),
                          Container(
                            height: max == 0
                                ? 2
                                : (h * values[i] / max).clamp(2.0, h),
                            decoration: BoxDecoration(
                              color: values[i] == 0
                                  ? DColors.line
                                  : DColors.burnt,
                              borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(4)),
                            ),
                          ),
                        ]),
                  ),
                ),
              ),
          ]),
        ),
        const Divider(height: 1, color: DColors.line),
        const SizedBox(height: 6),
        Row(children: [
          Text(_label(points.first['day']),
              style: DText.body(11, color: DColors.muted)),
          const Spacer(),
          Text('Hoy', style: DText.body(11, color: DColors.muted)),
        ]),
      ]),
    );
  }

  static String _label(dynamic v) {
    final d = DateTime.tryParse((v ?? '').toString());
    return d == null ? '' : '${d.day}/${d.month}';
  }
}
