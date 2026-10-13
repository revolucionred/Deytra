// Sistema visual compartido de Deytra.
// Tokens tomados del brand kit (07_Implementacion/deytra-tokens.json).
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class DColors {
  DColors._();
  static const orange = Color(0xFFFF8A3D);
  static const burnt = Color(0xFFD35400);
  static const action = Color(0xFFA84000);
  static const charcoal = Color(0xFF1F1F1F);
  static const ink = Color(0xFF0D1117);
  static const cream = Color(0xFFF8F6F2);
  static const stone = Color(0xFFD9D6D1);
  static const muted = Color(0xFF62615E);
  static const peach = Color(0xFFFFEFE4);
  static const line = Color(0xFFE7E3DD);
  static const success = Color(0xFF24734F);
  static const error = Color(0xFFB83232);
}

class DText {
  DText._();
  static TextStyle display(double size,
          {Color color = DColors.ink, FontWeight weight = FontWeight.w700}) =>
      GoogleFonts.plusJakartaSans(
          fontSize: size, fontWeight: weight, color: color, height: 1.2);
  static TextStyle body(double size,
          {Color color = DColors.ink,
          FontWeight weight = FontWeight.w400,
          double height = 1.45}) =>
      GoogleFonts.inter(
          fontSize: size, fontWeight: weight, color: color, height: height);
  static TextStyle label({Color color = DColors.muted}) => GoogleFonts.inter(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      color: color,
      letterSpacing: 0.8);
}

/// Ícono propio de la marca (PNG de trazo oscuro, se puede teñir).
class DIcon extends StatelessWidget {
  const DIcon(this.name, {super.key, this.size = 22, this.color});
  final String name;
  final double size;
  final Color? color;
  @override
  Widget build(BuildContext context) => Image.asset(
        'assets/images/ic-$name.png',
        width: size,
        height: size,
        color: color,
        fit: BoxFit.contain,
      );
}

/// Encabezado claro común a las pantallas internas.
class DHeader extends StatelessWidget implements PreferredSizeWidget {
  const DHeader({super.key, required this.title, this.actions = const []});
  final String title;
  final List<Widget> actions;
  @override
  Size get preferredSize => const Size.fromHeight(64);
  @override
  Widget build(BuildContext context) => AppBar(
        backgroundColor: DColors.cream,
        surfaceTintColor: DColors.cream,
        elevation: 0,
        toolbarHeight: 64,
        leading: Navigator.of(context).canPop()
            ? IconButton(
                tooltip: 'Volver',
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.arrow_back_rounded,
                    color: DColors.ink),
              )
            : null,
        title: Text(title, style: DText.display(20)),
        actions: actions,
      );
}

class DButton extends StatelessWidget {
  const DButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
    this.secondary = false,
    this.danger = false,
    this.expand = true,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  final bool secondary;
  final bool danger;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final bg = danger
        ? Colors.white
        : secondary
            ? Colors.white
            : DColors.orange;
    final fg = danger
        ? DColors.error
        : secondary
            ? DColors.ink
            : DColors.ink;
    final child = busy
        ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: fg))
        : Text(label, style: DText.display(15, color: fg));
    final button = TextButton(
      onPressed: busy ? null : onPressed,
      style: TextButton.styleFrom(
        backgroundColor: bg,
        disabledBackgroundColor: bg.withOpacity(0.6),
        minimumSize: const Size(0, 52),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: secondary || danger
              ? BorderSide(color: danger ? DColors.error : DColors.line)
              : BorderSide.none,
        ),
      ),
      child: child,
    );
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

class DField extends StatelessWidget {
  const DField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.maxLines = 1,
    this.maxLength,
    this.keyboardType,
    this.helper,
  });
  final TextEditingController controller;
  final String label;
  final String? hint;
  final String? helper;
  final int maxLines;
  final int? maxLength;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: DText.body(14, weight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            maxLines: maxLines,
            minLines: 1,
            maxLength: maxLength,
            keyboardType: keyboardType,
            style: DText.body(16),
            cursorColor: DColors.burnt,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: DText.body(15, color: DColors.muted),
              helperText: helper,
              helperMaxLines: 3,
              helperStyle: DText.body(12, color: DColors.muted),
              counterText: '',
              filled: true,
              fillColor: Colors.white,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: DColors.line),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: DColors.orange, width: 1.5),
              ),
            ),
          ),
        ],
      );
}

class DCard extends StatelessWidget {
  const DCard({super.key, required this.child, this.padding = 18, this.onTap});
  final Widget child;
  final double padding;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: DColors.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: EdgeInsets.all(padding), child: child),
        ),
      );
}

class DChip extends StatelessWidget {
  const DChip(
      {super.key, required this.label, this.selected = false, this.onTap});
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        selected: selected,
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: selected ? DColors.charcoal : Colors.white,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                  color: selected ? DColors.charcoal : DColors.line),
            ),
            child: Text(label,
                style: DText.body(14,
                    weight: FontWeight.w500,
                    color: selected ? Colors.white : DColors.ink)),
          ),
        ),
      );
}

/// Estado vacío o de error con el símbolo de la marca, sin ilustraciones genéricas.
class DEmpty extends StatelessWidget {
  const DEmpty(
      {super.key,
      required this.title,
      required this.detail,
      this.action,
      this.icon = 'explore'});
  final String title;
  final String detail;
  final Widget? action;
  final String icon;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Column(children: [
          Container(
            width: 56,
            height: 56,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: DColors.peach, borderRadius: BorderRadius.circular(18)),
            child: DIcon(icon, color: DColors.burnt),
          ),
          const SizedBox(height: 16),
          Text(title, textAlign: TextAlign.center, style: DText.display(18)),
          const SizedBox(height: 6),
          Text(detail,
              textAlign: TextAlign.center,
              style: DText.body(14, color: DColors.muted)),
          if (action != null) ...[const SizedBox(height: 20), action!],
        ]),
      );
}

void showDMessage(BuildContext context, String text, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: error ? DColors.error : DColors.charcoal,
      content: Text(text, style: DText.body(14, color: Colors.white)),
    ));
}

Future<bool> confirmD(BuildContext context,
    {required String title,
    required String detail,
    required String confirm,
    bool danger = false}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: DColors.cream,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(title, style: DText.display(19)),
      content: Text(detail, style: DText.body(14, color: DColors.muted)),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancelar', style: DText.body(14, weight: FontWeight.w600))),
        TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(confirm,
                style: DText.body(14,
                    weight: FontWeight.w700,
                    color: danger ? DColors.error : DColors.action))),
      ],
    ),
  );
  return ok ?? false;
}

String modalityLabel(String? m) {
  switch (m) {
    case 'presencial':
      return 'Presencial';
    case 'remoto':
      return 'A distancia';
    case 'hibrido':
      return 'Presencial o a distancia';
    default:
      return 'A coordinar';
  }
}
