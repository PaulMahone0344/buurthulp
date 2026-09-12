import 'package:flutter/material.dart';
import 'package:heitjehulp_app/design/dichtheid_scope.dart';
import 'package:heitjehulp_app/theme.dart';

/// Zet een widget in een MaterialApp met het HeitjeHulp-thema, de
/// gevraagde dichtheid en de gevraagde tekstschaal (1.0 = systeem
/// standaard, 2.0 = 200 procent).
Widget hhWikkel(
  Widget child, {
  HhDichtheid dichtheid = HhDichtheid.normaal,
  double tekstschaal = 1.0,
}) {
  return MaterialApp(
    theme: hhThema(dichtheid),
    builder: (context, kind) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(tekstschaal)),
      child: HhDichtheidScope(dichtheid: dichtheid, child: kind!),
    ),
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );
}

/// Tekstschaal die de app minstens moet aankunnen zonder af te kappen.
const hhMaxTekstschaal = 2.0;
