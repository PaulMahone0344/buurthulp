import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/navigatie.dart';
import '../../../app/paden.dart';
import '../../../core/result.dart';
import '../../../design/components/hh_knop.dart';
import '../../../design/components/hh_meld_balk.dart';
import '../../../design/components/hh_scherm.dart';
import '../../../design/dichtheid_scope.dart';
import '../../../l10n/teksten_hulpvrager_nl.dart';
import '../../../theme.dart';
import '../../familie/provider/hulpvraag_namens.dart';
import '../../toegang/domein/werkgebied.dart';
import '../../toegang/model/hh_rol.dart';
import '../../toegang/provider/sessie_providers.dart';
import '../domein/wanneer.dart';
import '../model/nieuwe_klus.dart';
import '../paden_hulpvrager.dart';
import '../provider/concept_controller.dart';
import '../provider/hulpvraag_plaatser.dart';
import '../provider/hulpvrager_providers.dart';
import '../widget/hulpvraag_samenvatting.dart';
import '../widget/hulpvraag_waar_sectie.dart';
import '../widget/hulpvraag_wanneer_sectie.dart';
import '../widget/hulpvraag_wat_sectie.dart';
import 'stroom_verlaten_dialoog.dart';

/// Hulp vragen op één pagina (3 okt, indeling naar BuurtHeld; was O2-O5
/// in vier stappen): wat, wanneer, waar, de samenvatting en één grote
/// knop. Ontbreekt er iets, dan zegt een meldbalk wat. Plaatst de klus
/// (status open) en gaat naar O6. Terug vraagt "Weet u het zeker?" zodra
/// er al iets is ingevuld.
class HulpVragenScreen extends ConsumerStatefulWidget {
  const HulpVragenScreen({super.key});

  @override
  ConsumerState<HulpVragenScreen> createState() => _HulpVragenScreenState();
}

class _HulpVragenScreenState extends ConsumerState<HulpVragenScreen> {
  bool _isBezig = false;
  bool _toonFouten = false;
  String? _melding;

  Future<void> _verlaten() async {
    if (_isBezig) return;
    final concept = ref.read(conceptProvider);
    if (!concept.isLeeg && !await vraagStroomVerlaten(context)) return;
    ref.read(conceptProvider.notifier).wis();
    if (!mounted) return;
    terugOf(context, HhPaden.hulpvrager);
  }

  /// Wat er nog ontbreekt, in de volgorde van de pagina; null = compleet.
  String? _watOntbreekt() {
    final concept = ref.read(conceptProvider);
    if (!concept.heeftWat) return TekstenHulpvragerNl.paginaKiesWat;
    if (!concept.heeftWanneer) return TekstenHulpvragerNl.paginaKiesWanneer;
    if (isVoorbij(concept.dag!, concept.dagdeel!, ref.read(klokProvider)())) {
      return TekstenHulpvragerNl.wanneerVoorbij;
    }
    if (!concept.heeftWaar) return TekstenHulpvragerNl.paginaVulWaarIn;
    return null;
  }

  Future<void> _plaats() async {
    final gebruiker = ref.read(huidigeGebruikerProvider);
    // B2: een bewoner buiten het werkgebied plaatst geen klus.
    final buiten = gebruiker == null || gebruiker.rol != HhRol.hulpvrager
        ? null
        : werkgebiedMelding(gebruiker.wijkId, gebruiker.werkgebiedStatus);
    if (buiten != null) {
      setState(() => _melding = buiten);
      return;
    }
    final ontbreekt = _watOntbreekt();
    if (ontbreekt != null || gebruiker == null) {
      setState(() {
        _toonFouten = true;
        _melding = ontbreekt ?? TekstenHulpvragerNl.bevestigenOnvolledig;
      });
      return;
    }
    setState(() {
      _isBezig = true;
      _melding = null;
    });
    final result = await ref
        .read(hulpvraagPlaatserProvider)
        .plaats(concept: ref.read(conceptProvider), gebruikerId: gebruiker.id);
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
        // go, geen push: terug vanaf O6 bestaat niet.
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
    final dichtheid = HhDichtheidScope.van(context);
    final tussen = HhRuimte.voor(HhRuimte.l, dichtheid);
    final blok = HhRuimte.voor(HhRuimte.xl, dichtheid);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (heeftGepopt, _) {
        if (!heeftGepopt) _verlaten();
      },
      child: HhScherm(
        titel: TekstenHulpvragerNl.paginaTitel,
        onTerug: _verlaten,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _Kop(TekstenHulpvragerNl.watTitel),
            SizedBox(height: tussen),
            const HulpvraagWatSectie(),
            SizedBox(height: blok),
            const _Kop(TekstenHulpvragerNl.wanneerTitel),
            SizedBox(height: tussen),
            const HulpvraagWanneerSectie(),
            SizedBox(height: blok),
            const _Kop(TekstenHulpvragerNl.waarTitel),
            SizedBox(height: tussen),
            HulpvraagWaarSectie(toonFouten: _toonFouten),
            SizedBox(height: blok),
            const HulpvraagSamenvatting(),
            if (_melding != null) ...[
              SizedBox(height: tussen),
              HhMeldBalk(soort: HhMeldSoort.waarschuwing, tekst: _melding!),
            ],
            SizedBox(height: tussen),
            HhKnop(
              label: TekstenHulpvragerNl.bevestigenAkkoord,
              semantiekLabel: TekstenHulpvragerNl.bevestigenAkkoordSemantiek,
              icoon: Icons.check,
              isBezig: _isBezig,
              onPressed: _plaats,
            ),
          ],
        ),
      ),
    );
  }
}

/// Kop van een deel van de pagina: vet en primair groen, zoals BuurtHeld.
class _Kop extends StatelessWidget {
  const _Kop(this.tekst);

  final String tekst;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Text(
        tekst,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          color: HhKleuren.primair,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
