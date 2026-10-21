// Avisos: quién apareció para lo que buscabas, solicitudes y conexiones aceptadas.
// También permite ver y cortar las alertas de "Avisame cuando aparezca".
import 'package:flutter/material.dart';
import '/custom_code/actions/index.dart' as actions;
import 'connections_page.dart';
import 'deytra_data.dart';
import 'deytra_ui.dart';

class NotificationsPageWidget extends StatefulWidget {
  const NotificationsPageWidget({super.key});
  @override
  State<NotificationsPageWidget> createState() =>
      _NotificationsPageWidgetState();
}

class _NotificationsPageWidgetState extends State<NotificationsPageWidget> {
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _alerts = [];
  bool _loading = true;
  String? _error;
  bool _showAlerts = false;

  @override
  void initState() {
    super.initState();
    _load(markRead: true);
  }

  Future<void> _load({bool markRead = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await Future.wait([
        DeytraData.notifications(),
        DeytraData.myAlerts(),
      ]);
      if (!mounted) return;
      setState(() {
        _items = r[0];
        _alerts = r[1];
        _loading = false;
      });
      if (markRead && _items.any((n) => n['read_at'] == null)) {
        DeytraData.markNotificationsRead();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = DeytraData.friendlyError(e);
      });
    }
  }

  Future<void> _open(Map<String, dynamic> n) async {
    final kind = (n['kind'] ?? '').toString();
    if (kind == 'alert_match') {
      final text = (n['search_text'] ?? '').toString();
      if (text.isEmpty) return;
      await actions.openDeytraSearch(context, text, '');
    } else {
      await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ConnectionsPageWidget()));
    }
  }

  Future<void> _stop(Map<String, dynamic> a) async {
    final ok = await confirmD(context,
        title: '¿Dejar de avisarte?',
        detail: 'Ya no te vamos a avisar cuando aparezca alguien para esta búsqueda.',
        confirm: 'Dejar de avisarme');
    if (!ok) return;
    try {
      await DeytraData.stopAlert(a['id'].toString());
      await _load();
    } catch (e) {
      if (mounted) showDMessage(context, DeytraData.friendlyError(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DColors.cream,
      appBar: const DHeader(title: 'Avisos'),
      body: SafeArea(
        child: RefreshIndicator(
          color: DColors.burnt,
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
            children: [
              Row(children: [
                DChip(
                  label: 'Novedades',
                  selected: !_showAlerts,
                  onTap: () => setState(() => _showAlerts = false),
                ),
                const SizedBox(width: 8),
                DChip(
                  label: _alerts.isEmpty
                      ? 'Lo que espero'
                      : 'Lo que espero · ${_alerts.length}',
                  selected: _showAlerts,
                  onTap: () => setState(() => _showAlerts = true),
                ),
              ]),
              const SizedBox(height: 16),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.only(top: 48),
                  child: Center(
                      child: CircularProgressIndicator(color: DColors.burnt)),
                )
              else if (_error != null)
                DEmpty(
                  title: 'No pudimos cargar tus avisos',
                  detail: _error!,
                  action: DButton(
                      label: 'Reintentar', onPressed: _load, expand: false),
                )
              else if (_showAlerts)
                ..._alertList()
              else
                ..._newsList(),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _newsList() {
    if (_items.isEmpty) {
      return const [
        DEmpty(
          icon: 'saved',
          title: 'Todavía no hay novedades',
          detail:
              'Cuando alguien quiera contactarte o aparezca quien ofrece lo que buscaste, lo vas a ver acá.',
        ),
      ];
    }
    return [
      for (final n in _items)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: DCard(
            onTap: () => _open(n),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 40,
                height: 40,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: DColors.peach,
                    borderRadius: BorderRadius.circular(12)),
                child: DIcon(
                    n['kind'] == 'alert_match' ? 'search' : 'connect',
                    color: DColors.burnt),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text((n['title'] ?? '').toString(),
                          style: DText.display(15,
                              weight: n['read_at'] == null
                                  ? FontWeight.w800
                                  : FontWeight.w600)),
                      if ((n['body'] ?? '').toString().isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(n['body'].toString(),
                            style: DText.body(14, color: DColors.muted)),
                      ],
                      if (n['kind'] == 'alert_match' &&
                          (n['search_text'] ?? '').toString().isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text('Buscaste: "${n['search_text']}"',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: DText.body(13, color: DColors.muted)),
                      ],
                      const SizedBox(height: 6),
                      Text(_ago(n['created_at']),
                          style: DText.body(12, color: DColors.muted)),
                    ]),
              ),
              if (n['read_at'] == null)
                Container(
                  width: 9,
                  height: 9,
                  margin: const EdgeInsets.only(top: 6, left: 6),
                  decoration: const BoxDecoration(
                      color: DColors.orange, shape: BoxShape.circle),
                ),
            ]),
          ),
        ),
    ];
  }

  List<Widget> _alertList() {
    if (_alerts.isEmpty) {
      return const [
        DEmpty(
          icon: 'saved',
          title: 'No estás esperando nada',
          detail:
              'Cuando busques algo que todavía nadie ofrece, tocá "Avisame cuando aparezca" y te avisamos acá.',
        ),
      ];
    }
    return [
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(
            'Te avisamos cuando alguien publique algo que resuelva estas búsquedas. Cada alerta dura 60 días.',
            style: DText.body(14, color: DColors.muted)),
      ),
      for (final a in _alerts)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: DCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('"${a['search_text'] ?? ''}"',
                  style: DText.body(15, weight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(
                  [
                    if ((a['city'] ?? '').toString().isNotEmpty)
                      'Cerca de ${a['city']}',
                    'Hasta el ${_date(a['expires_at'])}',
                  ].join(' · '),
                  style: DText.body(13, color: DColors.muted)),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => _stop(a),
                  child: Text('Dejar de avisarme',
                      style: DText.body(14,
                          weight: FontWeight.w600, color: DColors.action)),
                ),
              ),
            ]),
          ),
        ),
    ];
  }

  static String _date(dynamic v) {
    final d = DateTime.tryParse((v ?? '').toString())?.toLocal();
    if (d == null) return '';
    return '${d.day}/${d.month}';
  }

  static String _ago(dynamic v) {
    final d = DateTime.tryParse((v ?? '').toString())?.toLocal();
    if (d == null) return '';
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return 'Recién';
    if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Hace ${diff.inHours} h';
    if (diff.inDays == 1) return 'Ayer';
    if (diff.inDays < 7) return 'Hace ${diff.inDays} días';
    return '${d.day}/${d.month}';
  }
}
