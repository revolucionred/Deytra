// Solicitudes de contacto: las que recibí y las que envié.
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'chat_page.dart';
import 'deytra_data.dart';
import 'deytra_ui.dart';

class ConnectionsPageWidget extends StatefulWidget {
  const ConnectionsPageWidget({super.key});
  static String routeName = 'ConnectionsPage';
  static String routePath = '/conexiones';
  @override
  State<ConnectionsPageWidget> createState() => _ConnectionsPageWidgetState();
}

class _ConnectionsPageWidgetState extends State<ConnectionsPageWidget> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;
  bool _showReceived = true;
  String? _myEntityId;
  final Set<String> _busy = {};

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
      final results = await Future.wait([
        DeytraData.connections(),
        DeytraData.myEntityId(),
      ]);
      if (!mounted) return;
      setState(() {
        _items = results[0] as List<Map<String, dynamic>>;
        _myEntityId = results[1] as String?;
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

  Future<void> _respond(Map<String, dynamic> c, bool accept) async {
    final id = c['id'].toString();
    setState(() => _busy.add(id));
    try {
      await DeytraData.respondConnection(id, accept);
      if (!mounted) return;
      showDMessage(context,
          accept
              ? 'Aceptaste. Ya pueden hablar por el chat.'
              : 'Solicitud rechazada.');
      await _load();
    } catch (e) {
      if (mounted) showDMessage(context, DeytraData.friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  Future<void> _openChat(Map<String, dynamic> c) async {
    final me = (c['my_entity_id'] ?? _myEntityId)?.toString();
    if (me == null) return;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ChatPageWidget(
        connectionId: c['id'].toString(),
        myEntityId: me,
        otherName: (c['other_name'] ?? 'Conversación').toString(),
        otherWhatsapp: (c['other_whatsapp'] ?? '').toString(),
        topic: (c['capability_title'] ?? '').toString(),
      ),
    ));
    if (mounted) _load();
  }

  Future<void> _cancel(Map<String, dynamic> c) async {
    final ok = await confirmD(context,
        title: '¿Retirar la solicitud?',
        detail: 'La otra persona ya no la va a ver.',
        confirm: 'Retirar');
    if (!ok) return;
    final id = c['id'].toString();
    setState(() => _busy.add(id));
    try {
      await DeytraData.cancelConnection(id);
      await _load();
    } catch (e) {
      if (mounted) showDMessage(context, DeytraData.friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  Future<void> _safety(Map<String, dynamic> c) async {
    final other = c['other_entity_id']?.toString();
    if (other == null || _myEntityId == null) return;
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: DColors.cream,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text((c['other_name'] ?? 'Esta persona').toString(),
                    style: DText.display(18)),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.flag_outlined, color: DColors.ink),
                  title: Text('Reportar', style: DText.body(15)),
                  subtitle: Text('Spam, engaño o conducta inapropiada',
                      style: DText.body(13, color: DColors.muted)),
                  onTap: () => Navigator.of(ctx).pop('report'),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.block, color: DColors.error),
                  title: Text('Bloquear',
                      style: DText.body(15, color: DColors.error)),
                  subtitle: Text('No vas a aparecer en sus búsquedas ni ella en las tuyas',
                      style: DText.body(13, color: DColors.muted)),
                  onTap: () => Navigator.of(ctx).pop('block'),
                ),
              ]),
        ),
      ),
    );
    if (!mounted || choice == null) return;
    try {
      if (choice == 'block') {
        final ok = await confirmD(context,
            title: '¿Bloquear a esta persona?',
            detail: 'Podés desbloquearla más adelante desde tu cuenta.',
            confirm: 'Bloquear',
            danger: true);
        if (!ok) return;
        await DeytraData.block(myEntityId: _myEntityId!, otherEntityId: other);
        if (mounted) showDMessage(context, 'Persona bloqueada.');
      } else {
        await DeytraData.report(
            myEntityId: _myEntityId!, otherEntityId: other, reason: 'otro');
        if (mounted) {
          showDMessage(context, 'Gracias. Vamos a revisar el reporte.');
        }
      }
    } catch (e) {
      if (mounted) showDMessage(context, DeytraData.friendlyError(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = _items
        .where((c) => (c['i_am_requester'] == true) != _showReceived)
        .toList();
    final pendingReceived = _items
        .where((c) => c['i_am_requester'] != true && c['status'] == 'pending')
        .length;
    int unreadIn(bool received) => _items
        .where((c) => (c['i_am_requester'] != true) == received)
        .fold(0, (n, c) => n + ((c['unread'] as num?)?.toInt() ?? 0));
    final receivedBadge = pendingReceived + unreadIn(true);
    final sentBadge = unreadIn(false);
    return Scaffold(
      backgroundColor: DColors.cream,
      appBar: const DHeader(title: 'Conexiones'),
      body: SafeArea(
        child: RefreshIndicator(
          color: DColors.burnt,
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
            children: [
              Row(children: [
                DChip(
                  label: receivedBadge > 0
                      ? 'Recibidas · $receivedBadge'
                      : 'Recibidas',
                  selected: _showReceived,
                  onTap: () => setState(() => _showReceived = true),
                ),
                const SizedBox(width: 8),
                DChip(
                  label: sentBadge > 0 ? 'Enviadas · $sentBadge' : 'Enviadas',
                  selected: !_showReceived,
                  onTap: () => setState(() => _showReceived = false),
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
                  title: 'No pudimos cargar tus conexiones',
                  detail: _error!,
                  action: DButton(
                      label: 'Reintentar', onPressed: _load, expand: false),
                )
              else if (list.isEmpty)
                DEmpty(
                  icon: 'connect',
                  title: _showReceived
                      ? 'Todavía no te escribió nadie'
                      : 'Todavía no pediste ningún contacto',
                  detail: _showReceived
                      ? 'Cuando alguien quiera contactarte por lo que ofrecés, lo vas a ver acá.'
                      : 'Buscá lo que necesitás y pedí contacto desde los resultados.',
                )
              else
                ...list.map((c) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _card(c),
                    )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _card(Map<String, dynamic> c) {
    final status = (c['status'] ?? 'pending').toString();
    final received = c['i_am_requester'] != true;
    final busy = _busy.contains(c['id'].toString());
    final name = (c['other_name'] ?? 'Persona sin nombre').toString();
    final city = (c['other_city'] ?? '').toString();
    final need = (c['need_text'] ?? '').toString();
    final offer = (c['capability_title'] ?? '').toString();
    final intro = (c['intro_message'] ?? '').toString();
    final instagram = (c['other_instagram_url'] ?? '').toString();
    final whatsapp = (c['other_whatsapp'] ?? '').toString();
    final lastMessage = (c['last_message'] ?? '').toString();
    final unread = (c['unread'] as num?)?.toInt() ?? 0;
    final (statusText, statusColor) = switch (status) {
      'accepted' => ('Aceptada', DColors.success),
      'rejected' => ('No aceptada', DColors.muted),
      _ => ('Pendiente', DColors.action),
    };
    return DCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: DColors.peach,
            child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: DText.display(16, color: DColors.burnt)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: DText.display(16)),
              if (city.isNotEmpty)
                Text(city, style: DText.body(13, color: DColors.muted)),
            ]),
          ),
          Text(statusText,
              style: DText.body(12, weight: FontWeight.w700, color: statusColor)),
          IconButton(
            tooltip: 'Más opciones',
            visualDensity: VisualDensity.compact,
            onPressed: () => _safety(c),
            icon: const Icon(Icons.more_horiz, color: DColors.muted),
          ),
        ]),
        if (offer.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text('SOBRE', style: DText.label()),
          const SizedBox(height: 4),
          Text(offer, style: DText.body(14, weight: FontWeight.w600)),
        ],
        if (need.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(received ? 'LO QUE NECESITA' : 'LO QUE BUSCABAS',
              style: DText.label()),
          const SizedBox(height: 4),
          Text('"$need"',
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: DText.body(14, color: DColors.muted)),
        ],
        if (intro.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text('MENSAJE', style: DText.label()),
          const SizedBox(height: 4),
          Text(intro, style: DText.body(14)),
        ],
        if (status == 'accepted') ...[
          if (lastMessage.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
                '${c['last_from_me'] == true ? 'Vos: ' : ''}$lastMessage',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: DText.body(14,
                    weight: unread > 0 ? FontWeight.w700 : FontWeight.w400,
                    color: unread > 0 ? DColors.ink : DColors.muted)),
          ],
          const SizedBox(height: 14),
          DButton(
            label: unread > 0
                ? 'Abrir chat · $unread ${unread == 1 ? 'mensaje nuevo' : 'mensajes nuevos'}'
                : lastMessage.isEmpty
                    ? 'Escribirle por el chat'
                    : 'Abrir chat',
            onPressed: () => _openChat(c),
          ),
          if (whatsapp.isNotEmpty) ...[
            const SizedBox(height: 10),
            DButton(
              label: 'Escribirle por WhatsApp',
              secondary: true,
              onPressed: () => launchUrl(DeytraData.whatsappUri(whatsapp),
                  mode: LaunchMode.externalApplication),
            ),
          ],
          if (instagram.isNotEmpty) ...[
            const SizedBox(height: 10),
            DButton(
              label: 'Ver su Instagram',
              secondary: true,
              onPressed: () => launchUrl(Uri.parse(instagram),
                  mode: LaunchMode.externalApplication),
            ),
          ],
        ],
        if (received && status == 'pending') ...[
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
                child: DButton(
                    label: 'No, gracias',
                    secondary: true,
                    onPressed: busy ? null : () => _respond(c, false))),
            const SizedBox(width: 10),
            Expanded(
                child: DButton(
                    label: 'Aceptar',
                    busy: busy,
                    onPressed: () => _respond(c, true))),
          ]),
        ],
        if (!received && status == 'pending') ...[
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: busy ? null : () => _cancel(c),
              child: Text('Retirar solicitud',
                  style: DText.body(14,
                      weight: FontWeight.w600, color: DColors.action)),
            ),
          ),
        ],
      ]),
    );
  }
}
