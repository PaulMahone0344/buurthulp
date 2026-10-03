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
/// app). De logregel in hh_klus_status schrijft de hook zelf bij het
/// aanmaken (M6, backend OPEN-PUNT 16); de app doet dat niet meer.
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
      geplaatstDoorId: gebruikerId,
      bron: NieuweKlus.bronApp,
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
        return Result.ok(GeplaatsteHulpvraag(klusId: waarde));
    }
  }
}

final hulpvraagPlaatserProvider = Provider<HulpvraagPlaatser>(
  HulpvraagPlaatser.new,
);
