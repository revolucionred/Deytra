import 'dart:async';
import '/auth/supabase_auth/auth_util.dart';
import '/backend/supabase/supabase.dart';
import '/flutter_flow/ff_builtin_enums.dart';
import '/flutter_flow/flutter_flow_animations.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:math';
import 'dart:ui';
import '/custom_code/actions/index.dart' as actions;
import '/custom_code/widgets/index.dart' as custom_widgets;
import '/flutter_flow/custom_functions.dart' as functions;
import '/index.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'home_page_model.dart';
import '/deytra/deytra_ui.dart';
import '/deytra/offer_page.dart';
import '/deytra/connections_page.dart';
import '/deytra/account_page.dart';
import '/deytra/deytra_data.dart';
import '/deytra/notifications_page.dart';
import '/deytra/password_reset.dart';
export 'home_page_model.dart';

class HomePageWidget extends StatefulWidget {
  const HomePageWidget({super.key});

  static String routeName = 'HomePage';
  static String routePath = '/homePage';

  @override
  State<HomePageWidget> createState() => _HomePageWidgetState();
}

class _HomePageWidgetState extends State<HomePageWidget>
    with TickerProviderStateMixin {
  late HomePageModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  final animationsMap = <String, AnimationInfo>{};

  // Avisos: solicitudes pendientes y mensajes sin leer.
  int _badge = 0;
  int _news = 0;
  Timer? _badgeTimer;

  bool _recovering = false;
  Future<void> _maybeRecover() async {
    if (!mounted || _recovering || !DeytraRecovery.pending.value) return;
    _recovering = true;
    await showNewPassword(context);
    _recovering = false;
  }

  Future<void> _loadBadges() async {
    final b = await DeytraData.badges();
    if (!mounted) return;
    if (b.requests + b.unread != _badge || b.notifications != _news) {
      setState(() {
        _badge = b.requests + b.unread;
        _news = b.notifications;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => HomePageModel());
    _loadBadges();
    DeytraRecovery.pending.addListener(_maybeRecover);
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeRecover());
    _badgeTimer =
        Timer.periodic(const Duration(seconds: 45), (_) => _loadBadges());

    // On page load action.
    SchedulerBinding.instance.addPostFrameCallback((_) async {
      _model.currentUserRow = await UsersTable().queryRows(
        queryFn: (q) => q.eqOrNull(
          'id',
          currentUserUid,
        ),
      );
      if (!_model.currentUserRow!.firstOrNull!.onboardingCompleted!) {
        context.goNamed(OnboardingPageWidget.routeName);
      }
    });

    _model.textController ??= TextEditingController();
    _model.textFieldFocusNode ??= FocusNode();

    animationsMap.addAll({
      'textOnPageLoadAnimation1': AnimationInfo(
        trigger: AnimationTrigger.onPageLoad,
        effectsBuilder: () => [
          FadeEffect(
            curve: Curves.easeInOut,
            delay: functions.deytraMotionValue(940.0, 0.0).ms,
            duration: functions.deytraMotionValue(340.0, 0.0).ms,
            begin: functions.deytraMotionValue(0.0, 1.0),
            end: 1.0,
          ),
        ],
      ),
      'containerOnPageLoadAnimation1': AnimationInfo(
        trigger: AnimationTrigger.onPageLoad,
        effectsBuilder: () => [
          ScaleEffect(
            curve: Curves.easeInOut,
            delay: functions.deytraMotionValue(260.0, 0.0).ms,
            duration: functions.deytraMotionValue(720.0, 0.0).ms,
            begin: Offset(functions.deytraMotionValue(2.1, 1.0),
                functions.deytraMotionValue(2.1, 1.0)),
            end: Offset(1.0, 1.0),
          ),
          MoveEffect(
            curve: Curves.easeInOut,
            delay: functions.deytraMotionValue(260.0, 0.0).ms,
            duration: functions.deytraMotionValue(720.0, 0.0).ms,
            begin: Offset(
                functions.deytraMotionValue(
                    -(MediaQuery.sizeOf(context).width - 144.0) / 2.0, 0.0),
                functions.deytraMotionValue(96.0, 0.0)),
            end: Offset(0.0, 0.0),
          ),
        ],
      ),
      'textOnPageLoadAnimation2': AnimationInfo(
        trigger: AnimationTrigger.onPageLoad,
        effectsBuilder: () => [
          FadeEffect(
            curve: Curves.easeInOut,
            delay: functions.deytraMotionValue(1060.0, 0.0).ms,
            duration: functions.deytraMotionValue(340.0, 0.0).ms,
            begin: functions.deytraMotionValue(0.0, 1.0),
            end: 1.0,
          ),
        ],
      ),
      'containerOnPageLoadAnimation2': AnimationInfo(
        trigger: AnimationTrigger.onPageLoad,
        effectsBuilder: () => [
          FadeEffect(
            curve: Curves.easeInOut,
            delay: functions.deytraMotionValue(1160.0, 0.0).ms,
            duration: functions.deytraMotionValue(340.0, 0.0).ms,
            begin: functions.deytraMotionValue(0.0, 1.0),
            end: 1.0,
          ),
        ],
      ),
      'textOnPageLoadAnimation3': AnimationInfo(
        trigger: AnimationTrigger.onPageLoad,
        effectsBuilder: () => [
          FadeEffect(
            curve: Curves.easeInOut,
            delay: functions.deytraMotionValue(1360.0, 0.0).ms,
            duration: functions.deytraMotionValue(340.0, 0.0).ms,
            begin: functions.deytraMotionValue(0.0, 1.0),
            end: 1.0,
          ),
        ],
      ),
      'wrapOnPageLoadAnimation': AnimationInfo(
        trigger: AnimationTrigger.onPageLoad,
        effectsBuilder: () => [
          FadeEffect(
            curve: Curves.easeInOut,
            delay: functions.deytraMotionValue(1430.0, 0.0).ms,
            duration: functions.deytraMotionValue(340.0, 0.0).ms,
            begin: functions.deytraMotionValue(0.0, 1.0),
            end: 1.0,
          ),
        ],
      ),
      'imageOnPageLoadAnimation': AnimationInfo(
        trigger: AnimationTrigger.onPageLoad,
        effectsBuilder: () => [
          FadeEffect(
            curve: Curves.easeInOut,
            delay: functions.deytraMotionValue(1560.0, 0.0).ms,
            duration: functions.deytraMotionValue(500.0, 0.0).ms,
            begin: functions.deytraMotionValue(0.0, 1.0),
            end: 1.0,
          ),
        ],
      ),
    });
  }

  @override
  void dispose() {
    _badgeTimer?.cancel();
    DeytraRecovery.pending.removeListener(_maybeRecover);
    _model.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<UsersRow>>(
      future: UsersTable().querySingleRow(
        queryFn: (q) => q.eqOrNull(
          'id',
          currentUserUid,
        ),
      ),
      builder: (context, snapshot) {
        // Customize what your widget looks like when it's loading.
        if (!snapshot.hasData) {
          return Scaffold(
            backgroundColor: Color(0xFF1F1F1F),
            body: Center(
              child: SizedBox(
                width: 50.0,
                height: 50.0,
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    FlutterFlowTheme.of(context).primary,
                  ),
                ),
              ),
            ),
          );
        }
        List<UsersRow> homePageUsersRowList = snapshot.data!;

        final homePageUsersRow =
            homePageUsersRowList.isNotEmpty ? homePageUsersRowList.first : null;

        return GestureDetector(
          onTap: () {
            FocusScope.of(context).unfocus();
            FocusManager.instance.primaryFocus?.unfocus();
          },
          child: Scaffold(
            key: scaffoldKey,
            backgroundColor: Color(0xFF1F1F1F),
            appBar: PreferredSize(
              preferredSize: Size.fromHeight(64.0),
              child: AppBar(
                backgroundColor: Color(0xFF1F1F1F),
                automaticallyImplyLeading: false,
                title: ClipRRect(
                  borderRadius: BorderRadius.circular(0.0),
                  child: Image.asset(
                    'assets/images/logo-white.png',
                    width: 112.0,
                    height: 39.0,
                    fit: BoxFit.contain,
                  ),
                ),
                actions: [
                  _headerAction(context, 'opportunity', 'Ofrecer algo',
                      const OfferPageWidget()),
                  _headerAction(context, '', 'Avisos',
                      const NotificationsPageWidget(),
                      badge: _news,
                      material: Icons.notifications_none_rounded),
                  _headerAction(context, 'connect', 'Conexiones',
                      const ConnectionsPageWidget(),
                      badge: _badge),
                  _headerAction(context, 'people', 'Tu cuenta',
                      const AccountPageWidget()),
                  const SizedBox(width: 8),
                ],
                centerTitle: false,
                elevation: 0.0,
              ),
            ),
            body: SafeArea(
              top: true,
              child: Padding(
                padding: EdgeInsetsDirectional.fromSTEB(24.0, 24.0, 24.0, 24.0),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.max,
                    crossAxisAlignment:
                        (FFCrossAxisAlignment.stretch).flutterValue,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Container(
                        width: 100.0,
                        decoration: BoxDecoration(
                          color: Color(0xFF1F1F1F),
                          borderRadius: BorderRadius.circular(24.0),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment:
                              (FFCrossAxisAlignment.stretch).flutterValue,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.max,
                              children: [
                                Expanded(
                                  child: Text(
                                    '¿Qué necesitás\nhoy?',
                                    style: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .override(
                                          font: GoogleFonts.plusJakartaSans(
                                            fontWeight: FontWeight.normal,
                                            fontStyle:
                                                FlutterFlowTheme.of(context)
                                                    .bodyMedium
                                                    .fontStyle,
                                          ),
                                          color: Colors.white,
                                          fontSize: 34.0,
                                          letterSpacing: 0.0,
                                          fontWeight: FontWeight.normal,
                                          fontStyle:
                                              FlutterFlowTheme.of(context)
                                                  .bodyMedium
                                                  .fontStyle,
                                          lineHeight: 1.2,
                                        ),
                                  ).animateOnPageLoad(animationsMap[
                                      'textOnPageLoadAnimation1']!),
                                ),
                                Container(
                                  width: 96.0,
                                  height: 116.0,
                                  child: custom_widgets.DeytraCompanionAnimated(
                                    width: 96.0,
                                    height: 116.0,
                                    imagePath:
                                        'https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/deytra-aefqye/assets/a334fr0r27ug/assistant.png',
                                    active: true,
                                  ),
                                ).animateOnPageLoad(animationsMap[
                                    'containerOnPageLoadAnimation1']!),
                              ],
                            ),
                            Text(
                              'Contalo con tus palabras. Te mostramos quién puede ayudarte, cerca o a distancia.',
                              style: FlutterFlowTheme.of(context)
                                  .bodyMedium
                                  .override(
                                    font: GoogleFonts.plusJakartaSans(
                                      fontWeight: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .fontWeight,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .fontStyle,
                                    ),
                                    color: Color(0xFFD8D2CA),
                                    fontSize: 14.0,
                                    letterSpacing: 0.0,
                                    fontWeight: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .fontWeight,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .fontStyle,
                                    lineHeight: 1.45,
                                  ),
                            ).animateOnPageLoad(
                                animationsMap['textOnPageLoadAnimation2']!),
                          ].divide(SizedBox(height: 12.0)),
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(28.0),
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(4.0),
                          child: Row(
                            mainAxisSize: MainAxisSize.max,
                            children: [
                              Expanded(
                                child: Container(
                                  width: 200.0,
                                  child: TextFormField(
                                    controller: _model.textController,
                                    focusNode: _model.textFieldFocusNode,
                                    autofocus: false,
                                    enabled: true,
                                    obscureText: false,
                                    decoration: InputDecoration(
                                      isDense: true,
                                      labelStyle: FlutterFlowTheme.of(context)
                                          .labelMedium
                                          .override(
                                            font: GoogleFonts.inter(
                                              fontWeight:
                                                  FlutterFlowTheme.of(context)
                                                      .labelMedium
                                                      .fontWeight,
                                              fontStyle:
                                                  FlutterFlowTheme.of(context)
                                                      .labelMedium
                                                      .fontStyle,
                                            ),
                                            letterSpacing: 0.0,
                                            fontWeight:
                                                FlutterFlowTheme.of(context)
                                                    .labelMedium
                                                    .fontWeight,
                                            fontStyle:
                                                FlutterFlowTheme.of(context)
                                                    .labelMedium
                                                    .fontStyle,
                                          ),
                                      hintText: '¿Qué buscás?',
                                      hintStyle: FlutterFlowTheme.of(context)
                                          .labelMedium
                                          .override(
                                            font: GoogleFonts.plusJakartaSans(
                                              fontWeight:
                                                  FlutterFlowTheme.of(context)
                                                      .labelMedium
                                                      .fontWeight,
                                              fontStyle:
                                                  FlutterFlowTheme.of(context)
                                                      .labelMedium
                                                      .fontStyle,
                                            ),
                                            letterSpacing: 0.0,
                                            fontWeight:
                                                FlutterFlowTheme.of(context)
                                                    .labelMedium
                                                    .fontWeight,
                                            fontStyle:
                                                FlutterFlowTheme.of(context)
                                                    .labelMedium
                                                    .fontStyle,
                                          ),
                                      enabledBorder: OutlineInputBorder(
                                        borderSide: BorderSide(
                                          color: Colors.white,
                                          width: 1.0,
                                        ),
                                        borderRadius:
                                            BorderRadius.circular(24.0),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderSide: BorderSide(
                                          color: Color(0xFFFF8A3D),
                                          width: 1.0,
                                        ),
                                        borderRadius:
                                            BorderRadius.circular(24.0),
                                      ),
                                      errorBorder: OutlineInputBorder(
                                        borderSide: BorderSide(
                                          color: FlutterFlowTheme.of(context)
                                              .error,
                                          width: 1.0,
                                        ),
                                        borderRadius:
                                            BorderRadius.circular(24.0),
                                      ),
                                      focusedErrorBorder: OutlineInputBorder(
                                        borderSide: BorderSide(
                                          color: FlutterFlowTheme.of(context)
                                              .error,
                                          width: 1.0,
                                        ),
                                        borderRadius:
                                            BorderRadius.circular(24.0),
                                      ),
                                      filled: true,
                                      fillColor: Colors.white,
                                      contentPadding:
                                          EdgeInsetsDirectional.fromSTEB(
                                              16.0, 16.0, 16.0, 16.0),
                                    ),
                                    style: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .override(
                                          color: const Color(0xFF1F1F1F),
                                          font: GoogleFonts.plusJakartaSans(
                                            fontWeight:
                                                FlutterFlowTheme.of(context)
                                                    .bodyMedium
                                                    .fontWeight,
                                            fontStyle:
                                                FlutterFlowTheme.of(context)
                                                    .bodyMedium
                                                    .fontStyle,
                                          ),
                                          fontSize: 16.0,
                                          letterSpacing: 0.0,
                                          fontWeight:
                                              FlutterFlowTheme.of(context)
                                                  .bodyMedium
                                                  .fontWeight,
                                          fontStyle:
                                              FlutterFlowTheme.of(context)
                                                  .bodyMedium
                                                  .fontStyle,
                                          lineHeight: 1.45,
                                        ),
                                    maxLines: 3,
                                    minLines: 1,
                                    maxLength: 2000,
                                    buildCounter: (context,
                                            {required currentLength,
                                            required isFocused,
                                            maxLength}) =>
                                        null,
                                    cursorColor: FlutterFlowTheme.of(context)
                                        .primaryText,
                                    enableInteractiveSelection: true,
                                    validator: _model.textControllerValidator
                                        .asValidator(context),
                                  ),
                                ),
                              ),
                              FFButtonWidget(
                                onPressed: () async {
                                  await actions.openDeytraSearch(
                                    context,
                                    _model.textController.text,
                                    '',
                                  );
                                },
                                text: 'Buscar',
                                options: FFButtonOptions(
                                  height: 48.0,
                                  padding: EdgeInsetsDirectional.fromSTEB(
                                      16.0, 0.0, 16.0, 0.0),
                                  iconPadding: EdgeInsetsDirectional.fromSTEB(
                                      0.0, 0.0, 0.0, 0.0),
                                  color: Color(0xFFFF8A3D),
                                  textStyle: FlutterFlowTheme.of(context)
                                      .titleSmall
                                      .override(
                                        font: GoogleFonts.plusJakartaSans(
                                          fontWeight:
                                              FlutterFlowTheme.of(context)
                                                  .titleSmall
                                                  .fontWeight,
                                          fontStyle:
                                              FlutterFlowTheme.of(context)
                                                  .titleSmall
                                                  .fontStyle,
                                        ),
                                        color: Color(0xFF1F1F1F),
                                        fontSize: 14.0,
                                        letterSpacing: 0.0,
                                        fontWeight: FlutterFlowTheme.of(context)
                                            .titleSmall
                                            .fontWeight,
                                        fontStyle: FlutterFlowTheme.of(context)
                                            .titleSmall
                                            .fontStyle,
                                      ),
                                  elevation: 0.0,
                                  borderRadius: BorderRadius.circular(24.0),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ).animateOnPageLoad(
                          animationsMap['containerOnPageLoadAnimation2']!),
                      Text(
                        'Probá con una idea',
                        style: FlutterFlowTheme.of(context).bodyMedium.override(
                              font: GoogleFonts.plusJakartaSans(
                                fontWeight: FlutterFlowTheme.of(context)
                                    .bodyMedium
                                    .fontWeight,
                                fontStyle: FlutterFlowTheme.of(context)
                                    .bodyMedium
                                    .fontStyle,
                              ),
                              color: Color(0xFFD9D6D1),
                              letterSpacing: 0.0,
                              fontWeight: FlutterFlowTheme.of(context)
                                  .bodyMedium
                                  .fontWeight,
                              fontStyle: FlutterFlowTheme.of(context)
                                  .bodyMedium
                                  .fontStyle,
                            ),
                      ).animateOnPageLoad(
                          animationsMap['textOnPageLoadAnimation3']!),
                      Wrap(
                        spacing: 8.0,
                        runSpacing: 8.0,
                        children: [
                          for (final idea in _ideas)
                            _ideaChip(context, idea.$1, idea.$2),
                        ],
                      ).animateOnPageLoad(
                          animationsMap['wrapOnPageLoadAnimation']!),
                      _offerCard(context).animateOnPageLoad(
                          animationsMap['imageOnPageLoadAnimation']!),
                    ].divide(SizedBox(height: 16.0)),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  static const _ideas = <(String, String)>[
    ('Decorar el patio', 'Quiero decorar el patio de mi casa'),
    ('Comer más sano', 'Quiero empezar a comer más saludable'),
    ('Viandas', 'Busco alguien que cocine viandas para la semana'),
    ('Comunicar mi emprendimiento', 'Necesito ayuda con la comunicación de mi emprendimiento'),
    ('Clases de guitarra', 'Quiero aprender a tocar la guitarra'),
  ];

  Widget _headerAction(
          BuildContext context, String icon, String label, Widget page,
          {int badge = 0, IconData? material}) =>
      IconButton(
        tooltip: badge > 0 ? '$label ($badge nuevas)' : label,
        onPressed: () async {
          await Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => page));
          _loadBadges();
        },
        icon: Stack(clipBehavior: Clip.none, children: [
          material != null
              ? Icon(material, size: 26, color: Colors.white)
              : DIcon(icon, size: 24, color: Colors.white),
          if (badge > 0)
            Positioned(
              right: -7,
              top: -5,
              child: Container(
                constraints: const BoxConstraints(minWidth: 18),
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: DColors.orange,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: DColors.ink, width: 1.5),
                ),
                child: Text(badge > 9 ? '9+' : '$badge',
                    textAlign: TextAlign.center,
                    style: DText.body(10,
                        weight: FontWeight.w800, color: DColors.ink, height: 1.2)),
              ),
            ),
        ]),
      );

  Widget _ideaChip(BuildContext context, String label, String text) =>
      Material(
        color: const Color(0x14FFFFFF),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
          side: const BorderSide(color: Color(0x2EFFFFFF)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: () => safeSetState(() {
            _model.textController?.text = text;
            _model.textController?.selection =
                TextSelection.collapsed(offset: text.length);
          }),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            child: Text(label,
                style: DText.body(14,
                    color: Colors.white, weight: FontWeight.w500)),
          ),
        ),
      );

  Widget _offerCard(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0x0FFFFFFF),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0x24FFFFFF)),
          ),
          child: Stack(children: [
            Positioned(
              left: -40,
              right: -40,
              bottom: -18,
              child: Opacity(
                opacity: 0.55,
                child: Image.asset('assets/images/routes.png',
                    height: 110, fit: BoxFit.cover),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 72),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('¿Sabés hacer algo que a otra persona le sirve?',
                      style: DText.display(19, color: Colors.white)),
                  const SizedBox(height: 6),
                  Text(
                      'Cortar el pasto, cocinar, enseñar, diseñar. No hace falta tener un negocio.',
                      style: DText.body(14, color: const Color(0xFFD8D2CA))),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const OfferPageWidget())),
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.white,
                      minimumSize: const Size(0, 44),
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999)),
                    ),
                    child: Text('Ofrecer lo que hago',
                        style: DText.display(14, color: DColors.charcoal)),
                  ),
                ],
              ),
            ),
          ]),
        ),
      );
}
