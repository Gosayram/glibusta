import 'package:flutter/material.dart';

class AppRadius {
  AppRadius._();

  // Border radius scale
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 24.0;
  static const double xxl = 32.0;
  static const double full = 999.0;

  // Pre-defined BorderRadius objects
  static const BorderRadius borderRadiusXs = BorderRadius.all(Radius.circular(xs));
  static const BorderRadius borderRadiusSm = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius borderRadiusMd = BorderRadius.all(Radius.circular(md));
  static const BorderRadius borderRadiusLg = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius borderRadiusXl = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius borderRadiusXxl = BorderRadius.all(Radius.circular(xxl));
  static const BorderRadius borderRadiusFull = BorderRadius.all(Radius.circular(full));

  // Common component radii
  static const BorderRadius cardRadius = borderRadiusMd;
  static const BorderRadius buttonRadius = borderRadiusSm;
  static const BorderRadius dialogRadius = borderRadiusLg;
  static const BorderRadius inputRadius = borderRadiusSm;
  static const BorderRadius chipRadius = borderRadiusXs;
  static const BorderRadius bottomSheetRadius = borderRadiusXl;
}
