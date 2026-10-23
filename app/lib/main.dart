import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'demo/demo_modus.dart';
import 'demo/demo_overrides.dart';

void main() {
  runApp(
    ProviderScope(
      overrides: [if (isDemoModus) ...demoOverrides()],
      child: const HeitjeHulpApp(),
    ),
  );
}
