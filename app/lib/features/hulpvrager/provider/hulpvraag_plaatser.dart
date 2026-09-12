import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/hh_fout.dart';
import '../../../core/result.dart';
import '../domein/adres.dart';
import '../domein/bedragen.dart';
import '../domein/wanneer.dart';
import '../model/hulpvraag_concept.dart';
import '../model/nieuwe_klus.dart';
import 'hulpvrager_providers.dart';

/// Zet een compleet concept om in een hh_klussen-rij (status open, bron
/// app) en schrijft daarna een logregel concept -> open. Mislukt de
/// logregel, dan is de klus er wel; dat wordt gemeld in het antwoord en
/// niet aan de oudere (backend OPEN-PUNT 16: een hook neemt dit in M6 over).
class HulpvraagPlaatser {
  const HulpvraagPlaatser(this._ref);

  final Ref _ref;

  Future<Result<GeplaatsteHulpvraag>> plaats({
    required HulpvraagConcept concept,
    required String gebruikerId,
  }) async {
    final klustype = concept.klustype;
    final dag = concept.dag;
    final dagdeel = concept.dagdeel;
    if (klustype == null ||
        dag == null ||
        dagdeel == null ||
        !concept.heeftWaar) {
      return Result.err(const HhFout(HhFoutSoort.ongeldigeInvoer));
    }
    final tijdvak = tijdvakVoor(dag, dagdeel);
    final klus = NieuweKlus(
      hulpvragerId: gebruikerId,
      klustypeId: klustype.id,
      omschrijving: concept.toelichting.trim(),
      adres: stelAdresSamen(
        adres: concept.adres ?? '',
        postcode: concept.postcode ?? '',
        plaats: concept.plaats ?? '',
      ),
      wanneerVan: tijdvak.van,
      wanneerTot: tijdvak.tot,
      bedragen: berekenBedragen(klustype),
    );

    final gateway = _ref.read(klusGatewayProvider);
    final aangemaakt = await gateway.klusAanmaken(klus);
    switch (aangemaakt) {
      case Err<String>(:final fout):
        await verwerkSessieFout(_ref, fout);
        return Result.err(fout);
      case Ok<String>(:final waarde):
        final log = await gateway.statusLoggen(
          klusId: waarde,
          doorId: gebruikerId,
          van: NieuweKlus.statusConcept,
          naar: NieuweKlus.statusOpen,
        );
        return Result.ok(
          GeplaatsteHulpvraag(
            klusId: waarde,
            isLogGeschreven: log is Ok<void>,
            logDetail: switch (log) {
              Err<void>(:final fout) => fout.toString(),
              _ => null,
            },
          ),
        );
    }
  }
}

final hulpvraagPlaatserProvider = Provider<HulpvraagPlaatser>(
  HulpvraagPlaatser.new,
);
