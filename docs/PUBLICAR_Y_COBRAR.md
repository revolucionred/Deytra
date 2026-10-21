# Deytra: publicación y cobros

Versión del 21 de octubre de 2026.

## 1. Dónde estamos

La app funciona completa en la web y se puede instalar en el iPhone desde Safari (Compartir, Agregar a pantalla de inicio):
https://revolucionred.github.io/Deytra/

Página pública de privacidad y términos, que piden las tiendas:
https://revolucionred.github.io/Deytra/privacidad.html

Identificador definitivo de la app en las tiendas: `com.revolucionred.deytra`. No se puede cambiar después de la primera publicación.

**Lo que se puede hacer ya:** lanzar la versión web con tus primeros oferentes y usuarios. No depende de ninguna tienda.

**Lo que no depende de mí:** las tiendas tienen trámites con tiempos propios. No es posible estar en App Store y Google Play mañana; lo realista es entre 1 y 3 semanas.

## 2. Google Play (Android)

1. **Crear la cuenta de desarrolladora.** Se hace en play.google.com/console. El pago es único (USD 25) y Google verifica tu identidad, lo que puede tardar unos días.
2. **Elegir el tipo de cuenta.**
   - **Personal:** es más rápida de abrir. Google exige que, antes de publicar para todos, la app pase una prueba cerrada con al menos 12 personas durante 14 días seguidos. Esa prueba puede ser tu piloto con clientes y conocidos de la zona.
   - **De organización** (por ejemplo, Revolución Red): no tiene esa regla de prueba, pero pide un número D-U-N-S de la empresa, y el trámite tarda más.
3. **Cargar la clave de subida en GitHub.** Te mandé el archivo `deytra-claves-google-play.txt` con 3 valores. En github.com/revolucionred/Deytra entrá a Settings, después a Secrets and variables, después a Actions, y tocá New repository secret. Creá los 3 con el nombre y el valor exactos del archivo. Desde ese momento, cada versión genera también el paquete para Google Play, que se descarga desde la pestaña Actions. Guardá ese archivo en un lugar seguro y no lo compartas.
4. **Completar la ficha** con los textos de la sección 4, el cuestionario de clasificación de contenido y el de seguridad de datos (sección 5).

## 3. App Store (iPhone)

1. **Inscribirte en el Apple Developer Program.** Se hace en developer.apple.com/programs. Cuesta USD 99 por año y la aprobación puede tardar desde un día hasta una semana. Podés inscribirte como persona o como empresa; como empresa también se pide D-U-N-S.
2. **Cuando estés aprobada, avisame.** Configuro la compilación para iPhone con los certificados de tu cuenta. Para eso vas a tener que crear una clave de App Store Connect y cargarla en GitHub; te guío paso a paso.
3. **Revisión de Apple.** Suele tardar entre 1 y 3 días. Apple ya pide varias cosas que Deytra tiene:
   - Eliminar la cuenta desde la app.
   - Denunciar y bloquear a otras personas.
   - Términos aceptados al entrar.
   - Política de privacidad pública.
   - Ningún cobro dentro de la app sin las compras integradas de Apple.

## 4. Textos para las fichas (listos para copiar)

**Nombre:** Deytra

**Subtítulo (App Store, máx. 30):** Contá lo que necesitás

**Descripción corta (Google Play, máx. 80):** Contá lo que necesitás con tus palabras y encontrá quién te ayuda cerca.

**Descripción completa:**

Deytra conecta a quien necesita algo con quien sabe resolverlo, empezando por tu zona.

Escribí lo que necesitás como se lo dirías a alguien: "quiero decorar el patio", "busco viandas saludables", "necesito un colchón", "quiero aprender guitarra". Deytra lo entiende y te muestra personas, emprendimientos y negocios que pueden ayudarte, ordenados por pertinencia y cercanía. Si buscás un producto que se envía a todo el país, también te lo muestra.

Cómo funciona:
• Contá lo que necesitás con tus palabras.
• Mirá quién lo ofrece cerca tuyo o a distancia.
• Pedí contacto y, cuando acepta, hablen por el chat de Deytra sin dar tu número.
• Si todavía nadie lo ofrece, tocá "Avisame" y te avisamos cuando aparezca.

¿Sabés hacer algo que a otra persona le sirve? Cocinar, enseñar, arreglar, diseñar, cuidar. Publicalo gratis y aparecé cuando alguien de tu zona lo necesite. Con la misma cuenta podés buscar y ofrecer.

Tu información se cuida: tu WhatsApp e Instagram solo los ve quien aceptaste, podés bloquear o denunciar a cualquier perfil y eliminar tu cuenta cuando quieras.

**Palabras clave (App Store, máx. 100 caracteres):** servicios,oficios,emprendedores,profesionales,changas,clases,viandas,jardinero,cerca,comunidad

**Categoría:** Estilo de vida. Como secundaria: Productividad o Redes sociales.

**URL de privacidad:** https://revolucionred.github.io/Deytra/privacidad.html

**URL de soporte y correo de contacto:** definilos vos. Puede ser un correo de Revolución Red o uno nuevo para Deytra. Ese mismo dato conviene completarlo en la pantalla de Privacidad de la app; avisame cuál es y lo cargo.

**Capturas:** las saco del iPhone cuando la pruebes. Hacen falta 3 a 5: inicio, resultados, chat, ofrecer y avisos.

## 5. Seguridad de datos (respuestas para Google Play y Apple)

- **Datos que se recopilan:** correo, nombre, ciudad, contenido que publica la persona (ofertas, búsquedas, mensajes del chat) y, de forma opcional, WhatsApp e Instagram.
- **Para qué:** el funcionamiento de la app y la seguridad de la comunidad. No se usan para publicidad de terceros ni se venden.
- **Se comparten con terceros:** el texto de la búsqueda y la ciudad se procesan con el proveedor de inteligencia artificial para entender el pedido. No se envían nombre, correo ni mensajes.
- **Cifrado en tránsito:** sí.
- **La persona puede pedir que se borren sus datos:** sí, desde Cuenta, con Eliminar mi cuenta.
- **Ubicación precisa:** no. Solo la ciudad que la persona escribe.

## 6. Cobros: cómo te propongo manejarlo

No soy abogado ni contador. Esto es para que decidas con información, y conviene que tu contador revise el esquema de facturación.

### Lo que dicen las reglas de las tiendas

- **Apple:** todo lo que desbloquee funciones dentro de la app (una membresía Pro, destacar una publicación) tiene que cobrarse con las compras integradas de Apple, que se quedan con un porcentaje. En cambio, los servicios que se consumen fuera de la app (el jardinero que va a tu casa) y los servicios en tiempo real entre dos personas no pueden ni tienen que cobrarse con Apple: se cobran por otros medios, como Mercado Pago.
- **Google Play:** las suscripciones digitales también pasan por la facturación de Google. Google está habilitando cobros externos con comisiones más bajas, pero por ahora en Estados Unidos, Reino Unido y Europa. Para la mayoría de los demás países está anunciado para septiembre de 2027.
- **En la web** podés cobrar con Mercado Pago sin pagarle comisión a ninguna tienda.

### Mi recomendación

**Etapa 1: lanzamiento (ya).** Deytra es gratis para todos y no cobra comisión.
- **Por qué no cobrar comisión ahora.** Deytra todavía no interviene en el pago entre las personas, así que no hay forma de saber si el trabajo se hizo ni por cuánto. Una comisión empujaría a que la gente cierre todo por WhatsApp. Además, cobrar comisión implica procesar pagos de terceros: cuenta de marketplace en Mercado Pago, facturación, reclamos y devoluciones. Es una carga grande para el arranque.
- **Ingresos posibles desde el día uno, sin tocar las tiendas:**
  1. **Rondas pagadas por el organizador.** Se venden como servicio a empresas y organizadores de eventos, con link de Mercado Pago y factura. En la app, la ronda simplemente aparece activa.
  2. **Espacios patrocinados para negocios**, siempre marcados como "Publicidad", por rubro y zona. Se venden por fuera de la app, como cualquier pauta publicitaria. Nunca se presentan como "la mejor opción".

**Etapa 2: cuando haya oferentes que reciben consultas todas las semanas.** Lanzar **Deytra Pro** para quien ofrece. Puede incluir estadísticas de consultas, aviso prioritario de búsquedas de su rubro y zona, más publicaciones, fotos y catálogo, y ayuda de IA para responder y mejorar su perfil.
- **Dentro de la app:** se cobra con las compras integradas de Apple y Google.
- **En la web:** se cobra con Mercado Pago.
- **El plan no cambia el orden de los resultados por pertinencia.** Lo que se compra son herramientas, no posición.

**Etapa 3: comisión.** Recién tiene sentido cuando la app permita reservar y pagar adentro, por ejemplo una seña. Ese cobro sí puede ir por Mercado Pago, aun en iPhone, porque es un servicio que se consume fuera de la app.

### Lo que tenés que decidir vos

1. **Precios.** Los de las Rondas y los espacios patrocinados para arrancar, y más adelante el de Pro. No los invento: depende de lo que te digan los primeros organizadores y negocios.
2. **Quién factura.** Revolución Red o una entidad nueva para Deytra, y en qué categoría de monotributo o régimen.
3. **Cuenta de Mercado Pago** para Deytra, con credenciales de producción, cuando decidas activar cobros en la web.

### Lo que dejo preparado cuando lo decidas

- Planes y estado de suscripción guardados en la base, separados del orden de resultados.
- Botón de pago con Mercado Pago en la versión web.
- Compras integradas de Apple y Google para la app instalada.
- Marca "Publicidad" en los espacios patrocinados y su panel de carga.
