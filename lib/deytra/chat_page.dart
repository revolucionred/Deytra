// Chat interno entre dos personas con una conexión aceptada.
// Los mensajes llegan en vivo; los permisos los garantiza la base (RLS).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'deytra_data.dart';
import 'deytra_ui.dart';

class ChatPageWidget extends StatefulWidget {
  const ChatPageWidget({
    super.key,
    required this.connectionId,
    required this.myEntityId,
    required this.otherName,
    this.otherWhatsapp,
    this.topic,
  });
  final String connectionId;
  final String myEntityId;
  final String otherName;
  final String? otherWhatsapp;
  final String? topic;

  @override
  State<ChatPageWidget> createState() => _ChatPageWidgetState();
}

class _ChatPageWidgetState extends State<ChatPageWidget> {
  final _text = TextEditingController();
  final _scroll = ScrollController();
  final _focus = FocusNode();
  StreamSubscription<List<Map<String, dynamic>>>? _sub;
  Timer? _poll;
  List<Map<String, dynamic>> _messages = [];
  final List<Map<String, dynamic>> _pending = [];
  bool _loading = true;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _poll?.cancel();
    _text.dispose();
    _scroll.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    await _refresh();
    // En vivo; si el canal en vivo falla, se actualiza cada pocos segundos.
    try {
      _sub = DeytraData.messageStream(widget.connectionId).listen(
        (rows) => _apply(rows),
        onError: (_) => _startPolling(),
      );
    } catch (_) {
      _startPolling();
    }
  }

  void _startPolling() {
    _poll ??= Timer.periodic(const Duration(seconds: 6), (_) => _refresh());
  }

  Future<void> _refresh() async {
    try {
      final rows = await DeytraData.messages(widget.connectionId);
      _apply(rows);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (_messages.isEmpty) _error = DeytraData.friendlyError(e);
      });
    }
  }

  void _apply(List<Map<String, dynamic>> rows) {
    if (!mounted) return;
    final hadUnread = rows.any((m) =>
        m['sender_entity_id']?.toString() != widget.myEntityId &&
        m['read_at'] == null);
    setState(() {
      _messages = rows;
      _pending.removeWhere((p) => rows.any((r) =>
          r['body'] == p['body'] &&
          r['sender_entity_id']?.toString() == widget.myEntityId));
      _loading = false;
      _error = null;
    });
    if (hadUnread) DeytraData.markRead(widget.connectionId);
    _toBottom();
  }

  void _toBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _send() async {
    final body = _text.text.trim();
    if (body.isEmpty || _sending) return;
    setState(() {
      _sending = true;
      _pending.add({
        'body': body,
        'sender_entity_id': widget.myEntityId,
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'pending': true,
      });
      _text.clear();
    });
    _toBottom();
    try {
      await DeytraData.sendMessage(
        connectionId: widget.connectionId,
        senderEntityId: widget.myEntityId,
        body: body,
      );
      if (_sub == null || _poll != null) await _refresh();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _pending.removeWhere((p) => p['body'] == body);
        _text.text = body;
      });
      showDMessage(context, DeytraData.friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _sending = false);
      _focus.requestFocus();
    }
  }

  Future<void> _openWhatsapp() async {
    final n = widget.otherWhatsapp;
    if (n == null || n.isEmpty) return;
    await launchUrl(DeytraData.whatsappUri(n),
        mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final all = [..._messages, ..._pending];
    final hasWa = (widget.otherWhatsapp ?? '').isNotEmpty;
    return Scaffold(
      backgroundColor: DColors.cream,
      appBar: DHeader(
        title: widget.otherName,
        actions: [
          if (hasWa)
            IconButton(
              tooltip: 'Escribir por WhatsApp',
              onPressed: _openWhatsapp,
              icon: const Icon(Icons.chat_outlined, color: DColors.ink),
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: Column(children: [
          if ((widget.topic ?? '').isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
              child: Text('Sobre: ${widget.topic}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: DText.body(13, color: DColors.muted)),
            ),
          const Divider(height: 1, color: DColors.line),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: DColors.burnt))
                : _error != null
                    ? Padding(
                        padding: const EdgeInsets.all(24),
                        child: DEmpty(
                          icon: 'connect',
                          title: 'No pudimos abrir la conversación',
                          detail: _error!,
                          action: DButton(
                              label: 'Reintentar',
                              onPressed: _refresh,
                              expand: false),
                        ),
                      )
                    : all.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(24),
                            child: DEmpty(
                              icon: 'connect',
                              title: 'Empiecen a hablar',
                              detail:
                                  'Contale qué necesitás o preguntale lo que quieras. Los mensajes quedan solo entre ustedes dos.',
                            ),
                          )
                        : ListView.builder(
                            controller: _scroll,
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                            itemCount: all.length,
                            itemBuilder: (_, i) => _bubble(all, i),
                          ),
          ),
          _composer(),
        ]),
      ),
    );
  }

  Widget _bubble(List<Map<String, dynamic>> all, int i) {
    final m = all[i];
    final mine = m['sender_entity_id']?.toString() == widget.myEntityId;
    final at = DateTime.tryParse((m['created_at'] ?? '').toString())?.toLocal();
    final prev = i > 0
        ? DateTime.tryParse((all[i - 1]['created_at'] ?? '').toString())
            ?.toLocal()
        : null;
    final newDay = at != null &&
        (prev == null ||
            prev.year != at.year ||
            prev.month != at.month ||
            prev.day != at.day);
    final pending = m['pending'] == true;
    return Column(children: [
      if (newDay)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Text(_day(at), style: DText.label()),
        ),
      Align(
        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.78),
          child: Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
            decoration: BoxDecoration(
              color: mine ? DColors.charcoal : Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(18),
                topRight: const Radius.circular(18),
                bottomLeft: Radius.circular(mine ? 18 : 4),
                bottomRight: Radius.circular(mine ? 4 : 18),
              ),
              border: mine ? null : Border.all(color: DColors.line),
            ),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  SelectableText((m['body'] ?? '').toString(),
                      style: DText.body(15,
                          color: mine ? Colors.white : DColors.ink)),
                  const SizedBox(height: 2),
                  Text(
                      pending
                          ? 'Enviando'
                          : at == null
                              ? ''
                              : '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}'
                                  '${mine && m['read_at'] != null ? ' · Leído' : ''}',
                      style: DText.body(11,
                          color: mine
                              ? Colors.white.withOpacity(0.7)
                              : DColors.muted)),
                ]),
          ),
        ),
      ),
    ]);
  }

  String _day(DateTime? d) {
    if (d == null) return '';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final that = DateTime(d.year, d.month, d.day);
    final diff = today.difference(that).inDays;
    if (diff == 0) return 'HOY';
    if (diff == 1) return 'AYER';
    const months = [
      'ENE', 'FEB', 'MAR', 'ABR', 'MAY', 'JUN',
      'JUL', 'AGO', 'SEP', 'OCT', 'NOV', 'DIC'
    ];
    return '${d.day} ${months[d.month - 1]}';
  }

  Widget _composer() => Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: DColors.line)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
            child: TextField(
              controller: _text,
              focusNode: _focus,
              minLines: 1,
              maxLines: 5,
              maxLength: 2000,
              textCapitalization: TextCapitalization.sentences,
              style: DText.body(16),
              cursorColor: DColors.burnt,
              onSubmitted: (_) => _send(),
              decoration: InputDecoration(
                hintText: 'Escribí un mensaje',
                hintStyle: DText.body(15, color: DColors.muted),
                counterText: '',
                filled: true,
                fillColor: DColors.cream,
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: DColors.orange,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: _sending ? null : _send,
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Icon(Icons.arrow_upward_rounded,
                    color: DColors.ink, size: 22),
              ),
            ),
          ),
        ]),
      );
}
