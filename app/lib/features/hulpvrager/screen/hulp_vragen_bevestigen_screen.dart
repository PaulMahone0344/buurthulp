import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/navigatie.dart';
import '../../../core/result.dart';
import '../../../design/components/hh_kaart.dart';
import '../../../design/components/hh_knop.dart';
import '../../../design/components/hh_meld_balk.dart';
import '../../../design/components/hh_scherm.dart';
import '../../../design/components/hh_stapbalk.dart';
import '../../../design/dichtheid_scope.dart';
import '../../../l10n/teksten_hulpvrager_nl.dart';
import '../../../theme.dart';
import '../../toegang/provider/sessie_providers.dart';
import '../domein/adres.dart';
import '../domein/bedragen.dart';
import '../domein/duur.dart';
import '../domein/wanneer.dart';
import '../model/nieuwe_klus.dart';
import '../paden_hulpvrager.dart';
import '../../familie/provider/hulpvraag_namens.dart';
import '../provider/concept_controller.dart';
import '../provider/hulpvraag_plaatser.dart';
import '../provider/hulpvrager_providers.dart';

/// O5, stap 4 van 4: bevestigen. Wat, wanneer, waar, hoe lang ongeveer en
/// wat het kost, dan een grote akkoordknop. Plaatst de klus (status open)
/// en gaat naar O6; de stroom wordt daarna niet meer bereikbaar via terug.
class HulpVragenBevestigenScreen extends ConsumerStatefulWidget {
  const HulpVragenBevestigenScreen({super.key});

  @override
  ConsumerState<HulpVragenBevestigenScreen> createState() =>
      _HulpVragenBevestigenScreenState();
}

class _HulpVragenBevestigenScreenState
    extends ConsumerState<HulpVragenBevestigenScreen> {
  bool _isBezig = false;
  String? _melding;

  Future<void> _plaats() async {
    final gebruiker = ref.read(huidigeGebruikerProvider);
    final concept = ref.read(conceptProvider);
    if (gebruiker == null || !concept.isCompleet) {
      setState(() => _melding = TekstenHulpvragerNl.bevestigenOnvolledig);
      return;
    }
    setState(() {
      _isBezig = true;
      _melding = null;
    });
    final result = await ref
        .read(hulpvraagPlaatserProvider)
        .plaats(concept: concept, gebruikerId: gebruiker.id);
    if (!mounted) return;
    switch (result) {
      case Ok<GeplaatsteHulpvraag>():
        ref.read(conceptProvider.notifier).wis();
        // M9 (F2): namens een oudere terug naar F3 van die oudere.
        final namens = ref.read(actieveNamensProvider);
        if (namens != null) {
          ref.read(hulpvraagNamensProvider.notifier).wis();
          context.go(namens.naPlaatsen);
          return;
        }
        // go, geen push: de stapel van de stroom verdwijnt, terug vanaf O6
        // bestaat niet.
        context.go(HhPadenHulpvrager.hulpVragenVerstuurd);
      case Err<GeplaatsteHulpvraag>(:final fout):
        setState(() {
          _isBezig = false;
          _melding = fout.melding;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final concept = ref.watch(conceptProvider);
    final nu = ref.watch(klokProvider)();
    final dichtheid = HhDichtheidScope.van(context);
    final tussen = HhRuimte.voor(HhRuimte.l, dichtheid);
    final klustype = concept.klustype;
    final dag = concept.dag;
    final dagdeel = concept.dagdeel;

    return HhScherm(
      titel: TekstenHulpvragerNl.bevestigenTitel,
      onTerug: _isBezig
          ? () {}
          : () => terugOf(context, HhPadenHulpvrager.hulpVragenWaar),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const HhStapbalk(
            stap: 4,
            totaal: TekstenHulpvragerNl.stappenTotaal,
            titel: TekstenHulpvragerNl.stapBevestigen,
          ),
          SizedBox(height: tussen),
          HhKaart(
            kop: TekstenHulpvragerNl.bevestigenKaart,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Regel(
                  kop: TekstenHulpvragerNl.overzichtWat,
                  waarde: klustype?.naam ?? '',
                ),
                _Regel(
                  kop: TekstenHulpvragerNl.overzichtWanneer,
                  waarde: dag != null && dagdeel != null
                      ? wanneerTekst(dag, dagdeel, nu)
                      : '',
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
                  waarde: duurTekst(klustype?.richtduurMinuten ?? 0),
                ),
                _Regel(
                  kop: TekstenHulpvragerNl.overzichtKosten,
                  waarde: klustype == null
                      ? ''
                      : euroTekst(berekenBedragen(klustype).bedragBruto),
                ),
                if (concept.toelichting.trim().isNotEmpty)
                  _Regel(
                    kop: TekstenHulpvragerNl.overzichtToelichting,
                    waarde: concept.toelichting.trim(),
                    isLaatste: true,
                  ),
              ],
            ),
          ),
          if (_melding != null) ...[
            SizedBox(height: tussen),
            HhMeldBalk(soort: HhMeldSoort.fout, tekst: _melding!),
          ],
          SizedBox(height: HhRuimte.voor(HhRuimte.xl, dichtheid)),
          HhKnop(
            label: TekstenHulpvragerNl.bevestigenAkkoord,
            semantiekLabel: TekstenHulpvragerNl.bevestigenAkkoordSemantiek,
            icoon: Icons.check,
            isBezig: _isBezig,
            onPressed: concept.isCompleet ? _plaats : null,
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
