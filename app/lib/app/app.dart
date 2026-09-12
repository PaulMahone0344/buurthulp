import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/dichtheid_scope.dart';
import '../l10n/teksten_nl.dart';
import '../theme.dart';
import 'dichtheid_controller.dart';
import 'router.dart';

/// Bedraadt de ProviderScope-staat (sessie, dichtheid, router) tot een
/// MaterialApp. Het thema komt uit theme.dart en wisselt mee met de
/// dichtheid, die de rol volgt; de [HhDichtheidScope] eronder laat elke
/// widget weten welke maat geldt.
class HeitjeHulpApp extends ConsumerWidget {
  const HeitjeHulpApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final dichtheid = ref.watch(dichtheidProvider);

    return MaterialApp.router(
      title: TekstenNl.appNaam,
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      theme: hhThema(dichtheid),
      builder: (context, child) =>
          HhDichtheidScope(dichtheid: dichtheid, child: child!),
    );
  }
}
