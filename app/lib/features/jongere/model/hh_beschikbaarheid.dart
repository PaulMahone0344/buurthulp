import 'package:flutter/foundation.dart';

import '../../../l10n/teksten_jongere_nl.dart';

/// De zeven dagen, met de sleutel zoals hij in hh_profielen.beschikbaarheid
/// staat: {"ma":["middag"],...}.
enum HhDag {
  ma('ma'),
  di('di'),
  wo('wo'),
  do_('do'),
  vr('vr'),
  za('za'),
  zo('zo');

  const HhDag(this.code);

  final String code;

  String get naam => switch (this) {
    HhDag.ma => TekstenJongereNl.dagMa,
    HhDag.di => TekstenJongereNl.dagDi,
    HhDag.wo => TekstenJongereNl.dagWo,
    HhDag.do_ => TekstenJongereNl.dagDo,
    HhDag.vr => TekstenJongereNl.dagVr,
    HhDag.za => TekstenJongereNl.dagZa,
    HhDag.zo => TekstenJongereNl.dagZo,
  };
}

enum HhDagdeel {
  ochtend('ochtend'),
  middag('middag'),
  avond('avond');

  const HhDagdeel(this.code);

  final String code;

  static HhDagdeel? vanCode(String? code) {
    for (final dagdeel in values) {
      if (dagdeel.code == code) return dagdeel;
    }
    return null;
  }

  String get naam => switch (this) {
    HhDagdeel.ochtend => TekstenJongereNl.dagdeelOchtend,
    HhDagdeel.middag => TekstenJongereNl.dagdeelMiddag,
    HhDagdeel.avond => TekstenJongereNl.dagdeelAvond,
  };
}

/// Beschikbaarheid per dag, onveranderlijk. Heen en terug naar de json van
/// de server; onbekende dagen of dagdelen worden stil overgeslagen.
@immutable
class HhBeschikbaarheid {
  const HhBeschikbaarheid._(this._perDag);

  const HhBeschikbaarheid.leeg() : _perDag = const {};

  factory HhBeschikbaarheid.van(Map<HhDag, Set<HhDagdeel>> perDag) {
    return HhBeschikbaarheid._(
      Map.unmodifiable({
        for (final entry in perDag.entries)
          if (entry.value.isNotEmpty) entry.key: Set.unmodifiable(entry.value),
      }),
    );
  }

  /// Leest {"ma":["middag"],...}; alles wat geen map of lijst is telt
  /// als leeg.
  factory HhBeschikbaarheid.vanJson(Object? json) {
    if (json is! Map) return const HhBeschikbaarheid.leeg();
    final perDag = <HhDag, Set<HhDagdeel>>{};
    for (final dag in HhDag.values) {
      final lijst = json[dag.code];
      if (lijst is! List) continue;
      final dagdelen = <HhDagdeel>{};
      for (final code in lijst) {
        final dagdeel = HhDagdeel.vanCode(code is String ? code : null);
        if (dagdeel != null) dagdelen.add(dagdeel);
      }
      if (dagdelen.isNotEmpty) perDag[dag] = dagdelen;
    }
    return HhBeschikbaarheid.van(perDag);
  }

  final Map<HhDag, Set<HhDagdeel>> _perDag;

  Set<HhDagdeel> voor(HhDag dag) => _perDag[dag] ?? const {};

  bool get isLeeg => _perDag.isEmpty;

  /// Alle zeven dagen, dagdelen in vaste volgorde: zo is de json op de
  /// server altijd hetzelfde geordend.
  Map<String, List<String>> naarJson() => {
    for (final dag in HhDag.values)
      dag.code: [
        for (final dagdeel in HhDagdeel.values)
          if (voor(dag).contains(dagdeel)) dagdeel.code,
      ],
  };

  HhBeschikbaarheid met(HhDag dag, Set<HhDagdeel> dagdelen) =>
      HhBeschikbaarheid.van({..._perDag, dag: dagdelen});

  @override
  bool operator ==(Object other) =>
      other is HhBeschikbaarheid &&
      HhDag.values.every((dag) => setEquals(voor(dag), other.voor(dag)));

  @override
  int get hashCode => Object.hashAll([
    for (final dag in HhDag.values) Object.hashAllUnordered(voor(dag)),
  ]);
}
