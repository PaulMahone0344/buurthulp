import 'package:flutter/widgets.dart';

import '../theme.dart';

/// Geeft de actieve dichtheid door aan elke widget eronder. Ontbreekt de
/// scope (bijvoorbeeld in een losse widgettest), dan geldt normaal.
///
/// De app zet deze scope een keer rond de MaterialApp; een scherm hoeft
/// er nooit zelf een neer te zetten. Een widget leest de dichtheid met
/// `HhDichtheidScope.van(context)` en haalt daarmee de juiste maat uit
/// theme.dart.
class HhDichtheidScope extends InheritedWidget {
  const HhDichtheidScope({
    required this.dichtheid,
    required super.child,
    super.key,
  });

  final HhDichtheid dichtheid;

  static HhDichtheid van(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<HhDichtheidScope>();
    return scope?.dichtheid ?? HhDichtheid.normaal;
  }

  @override
  bool updateShouldNotify(HhDichtheidScope oudeWidget) =>
      oudeWidget.dichtheid != dichtheid;
}
