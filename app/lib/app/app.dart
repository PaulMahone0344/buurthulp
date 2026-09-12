import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/dichtheid_scope.dart';
import '../theme.dart';
import 'dichtheid_controller.dart';
import 'router.dart';

/// Bedraadt de ProviderScope-staat (dichtheid, router) tot een
/// MaterialApp. Het thema komt uit theme.dart en wisselt mee met de
/// dichtheid; de [HhDichtheidScope] eronder laat elke widget weten welke
/// maat geldt.
class HeitjeHulpApp extends ConsumerWidget {
  const HeitjeHulpApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final dichtheid = ref.watch(dichtheidControllerProvider);

    return MaterialApp.router(
      title: 'HeitjeHulp',
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      theme: hhThema(dichtheid),
      builder: (context, child) =>
          HhDichtheidScope(dichtheid: dichtheid, child: child!),
    );
  }
}
