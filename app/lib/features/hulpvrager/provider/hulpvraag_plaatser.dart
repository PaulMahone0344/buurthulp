import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/hh_fout.dart';
import '../../../core/result.dart';
import '../../familie/provider/hulpvraag_namens.dart';
import '../domein/adres.dart';
import '../domein/bedragen.dart';
import '../domein/wanneer.dart';
import '../model/hulpvraag_concept.dart';
import '../model/nieuwe_klus.dart';
import 'hulpvrager_providers.dart';

/// Zet een compleet concept om in een hh_klussen-rij (status open, bron
/// app) met de foto als bestand. De logregel, de leeftijdsgrens, de
/// markering en de keuring doet de server (hooks M6 en B4); de klus is
/// eerst "wordt nagekeken".
class HulpvraagPlaatser {
  const HulpvraagPlaatser(this._ref);

  final Ref _ref;

  Future<Result<GeplaatsteHulpvraag>> plaats({
    required HulpvraagConcept concept,
    required String gebruikerId,
  }) async {
    final klustype = concept.klustype;
    final dag = concept.dag;
    final vanaf = concept.vanafMinuten;
    final foto = concept.foto;
    if (klustype == null ||
        dag == null ||
        vanaf == null ||
        foto == null ||
        !concept.isCompleet) {
      return Result.err(const HhFout(HhFoutSoort.ongeldigeInvoer));
    }
    final eind = concept.eindMinuten;
    // M9 (F2): een familielid plaatst namens de gekozen oudere.
    final namens = _ref.read(actieveNamensProvider);
    final klus = NieuweKlus(
      hulpvragerId: namens?.oudereId ?? gebruikerId,
      geplaatstDoorId: gebruikerId,
      bron: namens == null ? NieuweKlus.bronApp : NieuweKlus.bronFamilie,
      klustypeId: klustype.id,
      omschrijving: concept.omschrijving.trim(),
      adres: stelAdresSamen(
        adres: concept.adres ?? '',
        postcode: concept.postcode ?? '',
        plaats: concept.plaats ?? '',
      ),
      wanneerVan: momentOp(dag, vanaf),
      wanneerTot: eind == null ? null : momentOp(dag, eind),
      bedragen: berekenBedragen(klustype),
      foto: foto,
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
