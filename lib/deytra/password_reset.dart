// Recuperar contraseña: pedir el correo de recuperación y, al volver desde ese
// correo, elegir una contraseña nueva.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '/backend/supabase/supabase.dart';
import 'deytra_ui.dart';

class DeytraRecovery {
  DeytraRecovery._();

  /// Se pone en true cuando la persona entró desde el link de recuperación.
  static final pending = ValueNotifier<bool>(false);
  static StreamSubscription<AuthState>? _sub;

  /// Llamar antes de iniciar Supabase: detecta el link aunque el evento llegue antes.
  static void checkLaunchUrl() {
    final u = Uri.base.toString();
    if (u.contains('type=recovery')) pending.value = true;
  }

  /// Llamar después de iniciar Supabase.
  static void listen() {
    _sub ??= SupaFlow.client.auth.onAuthStateChange.listen((s) {
      if (s.event == AuthChangeEvent.passwordRecovery) pending.value = true;
    }, onError: (_) {});
  }

  static String _redirect() {
    if (!kIsWeb) return 'https://revolucionred.github.io/Deytra/';
    final b = Uri.base;
    final i = b.path.indexOf('/Deytra/');
    final path = i >= 0 ? b.path.substring(0, i + 8) : '/';
    return '${b.origin}$path';
  }
}

/// Diálogo "¿Olvidaste tu contraseña?".
Future<void> showForgotPassword(BuildContext context, {String? email}) async {
  final ctrl = TextEditingController(text: email ?? '');
  var busy = false;
  String? error;
  var sent = false;
  await showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setD) => AlertDialog(
        backgroundColor: DColors.cream,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(sent ? 'Revisá tu correo' : 'Recuperar contraseña',
            style: DText.display(19)),
        content: sent
            ? Text(
                'Si ese correo tiene una cuenta en Deytra, te mandamos un link para elegir una contraseña nueva. Mirá también en spam o promociones.',
                style: DText.body(14, color: DColors.muted))
            : Column(mainAxisSize: MainAxisSize.min, children: [
                Text(
                    'Escribí el correo con el que te registraste y te mandamos un link.',
                    style: DText.body(14, color: DColors.muted)),
                const SizedBox(height: 16),
                DField(
                  controller: ctrl,
                  label: 'Correo',
                  hint: 'tu@correo.com',
                  keyboardType: TextInputType.emailAddress,
                ),
                if (error != null) ...[
                  const SizedBox(height: 8),
                  Text(error!, style: DText.body(13, color: DColors.error)),
                ],
              ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(sent ? 'Listo' : 'Cancelar',
                style: DText.body(14, weight: FontWeight.w600)),
          ),
          if (!sent)
            TextButton(
              onPressed: busy
                  ? null
                  : () async {
                      final mail = ctrl.text.trim();
                      if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(mail)) {
                        setD(() => error = 'Revisá el correo.');
                        return;
                      }
                      setD(() {
                        busy = true;
                        error = null;
                      });
                      try {
                        await SupaFlow.client.auth.resetPasswordForEmail(mail,
                            redirectTo: DeytraRecovery._redirect());
                        setD(() => sent = true);
                      } on AuthException catch (e) {
                        setD(() => error = e.statusCode == '429'
                            ? 'Pediste varios links seguidos. Esperá unos minutos.'
                            : 'No pudimos enviar el correo. Probá de nuevo.');
                      } catch (_) {
                        setD(() => error = 'Sin conexión. Probá de nuevo.');
                      } finally {
                        setD(() => busy = false);
                      }
                    },
              child: busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: DColors.burnt))
                  : Text('Enviar link',
                      style: DText.body(14,
                          weight: FontWeight.w700, color: DColors.action)),
            ),
        ],
      ),
    ),
  );
}

/// Diálogo para elegir la contraseña nueva (después de abrir el link del correo).
Future<void> showNewPassword(BuildContext context) async {
  final a = TextEditingController();
  final b = TextEditingController();
  var busy = false;
  String? error;
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setD) => AlertDialog(
        backgroundColor: DColors.cream,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Elegí tu contraseña nueva', style: DText.display(19)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          _PasswordField(controller: a, label: 'Contraseña nueva'),
          const SizedBox(height: 12),
          _PasswordField(controller: b, label: 'Repetila'),
          if (error != null) ...[
            const SizedBox(height: 8),
            Text(error!, style: DText.body(13, color: DColors.error)),
          ],
        ]),
        actions: [
          TextButton(
            onPressed: busy
                ? null
                : () {
                    DeytraRecovery.pending.value = false;
                    Navigator.of(ctx).pop();
                  },
            child: Text('Ahora no',
                style: DText.body(14, weight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: busy
                ? null
                : () async {
                    if (a.text.length < 8) {
                      setD(() => error = 'Usá al menos 8 caracteres.');
                      return;
                    }
                    if (a.text != b.text) {
                      setD(() => error = 'Las dos contraseñas no coinciden.');
                      return;
                    }
                    setD(() {
                      busy = true;
                      error = null;
                    });
                    try {
                      await SupaFlow.client.auth
                          .updateUser(UserAttributes(password: a.text));
                      DeytraRecovery.pending.value = false;
                      if (ctx.mounted) Navigator.of(ctx).pop();
                      if (context.mounted) {
                        showDMessage(context, 'Listo, tu contraseña quedó cambiada.');
                      }
                    } catch (_) {
                      setD(() {
                        busy = false;
                        error =
                            'No pudimos cambiarla. Pedí un link nuevo e intentá otra vez.';
                      });
                    }
                  },
            child: busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: DColors.burnt))
                : Text('Guardar',
                    style: DText.body(14,
                        weight: FontWeight.w700, color: DColors.action)),
          ),
        ],
      ),
    ),
  );
}

class _PasswordField extends StatefulWidget {
  const _PasswordField({required this.controller, required this.label});
  final TextEditingController controller;
  final String label;
  @override
  State<_PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<_PasswordField> {
  bool _hidden = true;
  @override
  Widget build(BuildContext context) => TextField(
        controller: widget.controller,
        obscureText: _hidden,
        style: DText.body(16),
        cursorColor: DColors.burnt,
        decoration: InputDecoration(
          labelText: widget.label,
          labelStyle: DText.body(14, color: DColors.muted),
          filled: true,
          fillColor: Colors.white,
          suffixIcon: IconButton(
            tooltip: _hidden ? 'Mostrar' : 'Ocultar',
            onPressed: () => setState(() => _hidden = !_hidden),
            icon: Icon(_hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                color: DColors.muted),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: DColors.line),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: DColors.orange, width: 1.5),
          ),
        ),
      );
}
