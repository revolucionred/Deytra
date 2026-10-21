// Placas de bienvenida: se muestran una sola vez por dispositivo, antes de entrar
// o registrarse, y explican en tres pasos cómo se usa Deytra.
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'deytra_ui.dart';

const _kIntroSeen = 'deytra_intro_seen_v1';

/// Muestra las placas si este dispositivo todavía no las vio.
Future<void> showIntroIfNeeded(BuildContext context) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_kIntroSeen) == true) return;
    if (!context.mounted) return;
    await Navigator.of(context).push(PageRouteBuilder(
      opaque: true,
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (_, __, ___) => const IntroSlidesPage(),
      transitionsBuilder: (_, a, __, child) =>
          FadeTransition(opacity: a, child: child),
    ));
    await prefs.setBool(_kIntroSeen, true);
  } catch (_) {
    // Si el almacenamiento no está disponible, se sigue sin placas.
  }
}

class IntroSlidesPage extends StatefulWidget {
  const IntroSlidesPage({super.key});
  @override
  State<IntroSlidesPage> createState() => _IntroSlidesPageState();
}

class _IntroSlidesPageState extends State<IntroSlidesPage> {
  final _pages = PageController();
  int _index = 0;

  static const _slides = [
    (
      kicker: 'PASO 1',
      title: 'Contá lo que necesitás, con tus palabras',
      body:
          'Escribí como le hablarías a alguien: "quiero decorar el patio", "busco viandas sanas" o "necesito un colchón". Deytra entiende y te muestra quién puede ayudarte, cerca tuyo o a distancia.',
      example: 'Quiero decorar el patio de mi casa',
    ),
    (
      kicker: 'PASO 2',
      title: 'Conectá y hablá por el chat',
      body:
          'Pedí contacto a quien te interese. Cuando acepta, hablan por el chat de Deytra sin dar tu número. Si todavía nadie lo ofrece, tocá "Avisame" y te avisamos cuando aparezca.',
      example: 'Juan aceptó tu solicitud',
    ),
    (
      kicker: 'PASO 3',
      title: 'Ofrecé lo que sabés hacer',
      body:
          'Cocinar, enseñar, arreglar, diseñar, cuidar. Publicalo gratis y aparecé cuando alguien de tu zona lo necesite. Con la misma cuenta podés buscar y ofrecer.',
      example: 'Clases de guitarra · Carcarañá',
    ),
  ];

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _next() {
    if (_index >= _slides.length - 1) {
      Navigator.of(context).maybePop();
    } else {
      _pages.nextPage(
          duration: const Duration(milliseconds: 280), curve: Curves.easeOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    final last = _index == _slides.length - 1;
    return Scaffold(
      backgroundColor: DColors.ink,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 12, 0),
            child: Row(children: [
              Image.asset('assets/images/symbol-white.png',
                  width: 28, height: 28),
              const SizedBox(width: 10),
              Text('Deytra', style: DText.display(18, color: Colors.white)),
              const Spacer(),
              if (!last)
                TextButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: Text('Saltar',
                      style: DText.body(14,
                          weight: FontWeight.w600,
                          color: Colors.white.withOpacity(0.7))),
                ),
            ]),
          ),
          Expanded(
            child: PageView.builder(
              controller: _pages,
              itemCount: _slides.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (_, i) {
                final s = _slides[i];
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(28, 32, 28, 16),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _example(s.example, i),
                        const SizedBox(height: 40),
                        Text(s.kicker,
                            style: DText.label(color: DColors.orange)),
                        const SizedBox(height: 10),
                        Text(s.title,
                            style: DText.display(28, color: Colors.white)),
                        const SizedBox(height: 14),
                        Text(s.body,
                            style: DText.body(16,
                                color: Colors.white.withOpacity(0.78))),
                      ]),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 8, 28, 24),
            child: Row(children: [
              for (var i = 0; i < _slides.length; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(right: 6),
                  width: i == _index ? 22 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: i == _index
                        ? DColors.orange
                        : Colors.white.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              const Spacer(),
              SizedBox(
                width: 150,
                child: DButton(
                    label: last ? 'Empezar' : 'Siguiente', onPressed: _next),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  /// Una muestra concreta de lo que se ve en la app en cada paso.
  Widget _example(String text, int i) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.12)),
        ),
        child: Row(children: [
          Container(
            width: 40,
            height: 40,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: DColors.orange, borderRadius: BorderRadius.circular(12)),
            child: DIcon(
                const ['search', 'connect', 'opportunity'][i],
                color: DColors.ink),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(text,
                style: DText.body(15,
                    weight: FontWeight.w600, color: Colors.white)),
          ),
        ]),
      );
}
