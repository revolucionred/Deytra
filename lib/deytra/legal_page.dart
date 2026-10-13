// Política de privacidad y términos de uso de Deytra.
// BORRADOR para la etapa de prueba: debe revisarlo una persona con formación legal
// antes de publicar la app en tiendas. Completar los datos del responsable abajo.
import 'package:flutter/material.dart';
import 'deytra_ui.dart';

/// Datos del responsable de la base de datos (completar antes de publicar en tiendas).
const kDeytraResponsable = 'Deytra';
const kDeytraContacto = 'la sección Cuenta de la app';
const kLegalVersion = 'Versión de prueba, octubre de 2026';

enum LegalDoc { privacy, terms }

class LegalPageWidget extends StatelessWidget {
  const LegalPageWidget({super.key, required this.doc});
  final LegalDoc doc;

  @override
  Widget build(BuildContext context) {
    final privacy = doc == LegalDoc.privacy;
    final sections = privacy ? _privacy : _terms;
    return Scaffold(
      backgroundColor: DColors.cream,
      appBar: DHeader(
          title: privacy ? 'Privacidad' : 'Términos y condiciones'),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
          children: [
            Text(kLegalVersion.toUpperCase(), style: DText.label()),
            const SizedBox(height: 16),
            for (final (title, body) in sections) ...[
              Text(title, style: DText.display(17)),
              const SizedBox(height: 6),
              Text(body, style: DText.body(15, color: DColors.charcoal)),
              const SizedBox(height: 20),
            ],
          ],
        ),
      ),
    );
  }
}

const List<(String, String)> _privacy = [
  (
    'Quién es responsable',
    '$kDeytraResponsable es responsable de los datos que cargás en la app. Podés escribirnos desde $kDeytraContacto.'
  ),
  (
    'Qué datos guardamos',
    'Tu correo y contraseña (la contraseña se guarda cifrada y nadie de Deytra puede verla), tu nombre, ciudad y descripción, lo que publicás que ofrecés, lo que buscás, tus conexiones y los mensajes del chat. De forma opcional, tu Instagram y tu WhatsApp.'
  ),
  (
    'Para qué los usamos',
    'Para mostrarte opciones que resuelvan lo que necesitás, cerca o a distancia; para que otras personas encuentren lo que ofrecés; para que puedan contactarse y para mantener la seguridad de la comunidad. No vendemos tus datos.'
  ),
  (
    'Qué ven las demás personas',
    'Tu nombre, ciudad y lo que ofrecés aparecen en los resultados de búsqueda. Tu Instagram y tu WhatsApp solo los ve quien aceptaste como conexión. Los mensajes del chat solo los ven las dos personas de la conversación.'
  ),
  (
    'Inteligencia artificial',
    'Para entender lo que buscás y sugerirte opciones de internet, el texto de tu búsqueda se procesa con un proveedor de inteligencia artificial. Le enviamos solo el texto de la búsqueda y la ciudad, nunca tu nombre, tu correo ni tus mensajes.'
  ),
  (
    'Sugerencias de internet',
    'Cuando todavía no hay opciones en Deytra, te mostramos negocios o cuentas públicas encontradas en internet, marcadas como sugerencia externa. Deytra no tiene relación con ellos ni garantiza sus servicios.'
  ),
  (
    'Tus derechos',
    'Podés ver y corregir tus datos desde Cuenta en cualquier momento, y eliminar tu cuenta con todo lo que publicaste. También podés pedir acceso, rectificación o supresión escribiéndonos. La Agencia de Acceso a la Información Pública, órgano de control de la Ley 25.326, atiende denuncias y reclamos sobre el incumplimiento de las normas de protección de datos personales.'
  ),
  (
    'Dónde se guardan',
    'Los datos se guardan en servidores de nuestro proveedor de base de datos con medidas de seguridad estándar. Pueden estar ubicados fuera de Argentina.'
  ),
  (
    'Cambios',
    'Si cambiamos esta política, te lo vamos a avisar en la app antes de que el cambio se aplique.'
  ),
];

const List<(String, String)> _terms = [
  (
    'Qué es Deytra',
    'Deytra es una plataforma que conecta a personas que necesitan algo con personas y negocios que pueden resolverlo. Deytra no presta los servicios ni vende los productos publicados, y no es parte de los acuerdos entre usuarios.'
  ),
  (
    'Tu cuenta',
    'Tenés que tener al menos 18 años y dar datos reales. Sos responsable de lo que publicás y de cuidar el acceso a tu cuenta.'
  ),
  (
    'Lo que publicás',
    'Publicá solo lo que realmente ofrecés, con información veraz. No se permite publicar contenido ilegal, engañoso, ofensivo o que viole derechos de otras personas. Podemos pausar o quitar publicaciones que no cumplan estas reglas.'
  ),
  (
    'Contacto entre personas',
    'El chat y los medios de contacto existen para coordinar lo que se ofrece o se busca. No uses Deytra para enviar spam, acosar ni pedir datos sensibles. Si algo no te parece bien, podés reportar o bloquear desde la conexión.'
  ),
  (
    'Precios y pagos',
    'Hoy usar Deytra es gratis. Los precios que figuran en las publicaciones los define cada persona y se acuerdan directamente entre las partes. Si en el futuro hay funciones pagas, se van a informar con claridad antes de cobrar cualquier cosa.'
  ),
  (
    'Publicidad',
    'Si Deytra muestra anuncios, van a estar identificados como publicidad y no van a cambiar el orden de los resultados por pertinencia.'
  ),
  (
    'Responsabilidad',
    'Deytra trabaja para que la comunidad sea segura, pero no puede verificar a cada persona ni garantizar el resultado de un trabajo o una compra. Antes de pagar o encontrarte con alguien, tomá las precauciones habituales.'
  ),
  (
    'Baja',
    'Podés dejar de usar Deytra y eliminar tu cuenta cuando quieras desde Cuenta. Podemos suspender cuentas que incumplan estos términos.'
  ),
  (
    'Ley aplicable',
    'Estos términos se rigen por las leyes de la República Argentina.'
  ),
];
