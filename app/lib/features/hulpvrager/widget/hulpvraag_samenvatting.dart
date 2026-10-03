import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design/components/hh_kaart.dart';
import '../../../design/dichtheid_scope.dart';
import '../../../l10n/teksten_hulpvrager_nl.dart';
import '../../../theme.dart';
import '../domein/adres.dart';
import '../domein/bedragen.dart';
import '../domein/duur.dart';
import '../domein/wanneer.dart';
import '../provider/concept_controller.dart';
import '../provider/hulpvrager_providers.dart';

/// Kaart onderaan de hulpvraag-pagina (was O5): wat, wanneer, waar, hoe
/// lang ongeveer en wat het kost. Alleen te zien als alles is ingevuld.
class HulpvraagSamenvatting extends ConsumerWidget {
  const HulpvraagSamenvatting({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final concept = ref.watch(conceptProvider);
    final nu = ref.watch(klokProvider)();
    final klustype = concept.klustype;
    final dag = concept.dag;
    final dagdeel = concept.dagdeel;
    if (!concept.isCompleet ||
        klustype == null ||
        dag == null ||
        dagdeel == null) {
      return const SizedBox.shrink();
    }

    return HhKaart(
      kop: TekstenHulpvragerNl.bevestigenKaart,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Regel(kop: TekstenHulpvragerNl.overzichtWat, waarde: klustype.naam),
          _Regel(
            kop: TekstenHulpvragerNl.overzichtWanneer,
            waarde: wanneerTekst(dag, dagdeel, nu),
          ),
          _Regel(
            kop: TekstenHulpvragerNl.overzichtWaar,
            waarde: stelAdresSamen(
              adres: concept.adres ?? '',
              postcode: concept.postcode ?? '',
              plaats: concept.plaats ?? '',
            ),
          ),
          _Regel(
            kop: TekstenHulpvragerNl.overzichtDuur,
            waarde: duurTekst(klustype.richtduurMinuten),
          ),
          _Regel(
            kop: TekstenHulpvragerNl.overzichtKosten,
            waarde: euroTekst(berekenBedragen(klustype).bedragBruto),
            isLaatste: true,
          ),
        ],
      ),
    );
  }
}

/// Een regel van de samenvatting: kop klein erboven, waarde groot eronder.
/// Eén node voor de schermlezer ("Wat: boodschappen").
class _Regel extends StatelessWidget {
  const _Regel({
    required this.kop,
    required this.waarde,
    this.isLaatste = false,
  });

  final String kop;
  final String waarde;
  final bool isLaatste;

  @override
  Widget build(BuildContext context) {
    final dichtheid = HhDichtheidScope.van(context);
    final tekst = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.only(
        bottom: isLaatste ? 0 : HhRuimte.voor(HhRuimte.m, dichtheid),
      ),
      child: MergeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(kop, style: tekst.bodyMedium),
            Text(
              waarde,
              style: tekst.bodyLarge!.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
