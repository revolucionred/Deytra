import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;
import '/flutter_flow/custom_functions.dart';
import '/flutter_flow/lat_lng.dart';
import '/flutter_flow/place.dart';
import '/flutter_flow/uploaded_file.dart';
import '/flutter_flow/ff_builtin_enums.dart';
import '/backend/supabase/supabase.dart';
import '/auth/supabase_auth/auth_util.dart';

double deytraMotionValue(
  double animatedValue,
  double settledValue,
) {
  final features =
      WidgetsBinding.instance.platformDispatcher.accessibilityFeatures;
  var reduced = features.disableAnimations || features.accessibleNavigation;
  // Newer Flutter versions expose iOS Reduce Motion separately. Dynamic access
  // preserves compatibility with FlutterFlow's pinned older engine versions.
  try {
    reduced = reduced || (features as dynamic).reduceMotion == true;
  } on NoSuchMethodError {
    // This engine has no separate getter; retain its available flag checks.
  }
  return reduced ? settledValue : animatedValue;
}
