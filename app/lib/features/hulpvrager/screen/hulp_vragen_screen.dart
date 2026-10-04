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
import '../../../l10n/teksten_klus_nl.dart';
import '../../../theme.dart';
import '../../toegang/domein/werkgebied.dart';
import '../../toegang/model/hh_rol.dart';
import '../../toegang/provider/sessie_providers.dart';
import '../domein/wanneer.dart';
import '../model/nieuwe_klus.dart';
import '../paden_hulpvrager.dart';
import '../provider/concept_controller.dart';
import '../provider/hulpvraag_plaatser.dart';
import '../provider/hulpvrager_providers.dart';
import '../widget/hulpvraag_waar_sectie.dart';
import '../widget/hulpvraag_wanneer_sectie.dart';
import '../../reacties/widget/helpers_kunnen_nu_regel.dart';
import '../widget/hulpvraag_wat_sectie.dart';
import '../widget/klus_foto_sectie.dart';
import '../widget/klus_herhalen_sectie.dart';
import '../widget/klus_nee_lijst_kaart.dart';
import '../widget/klus_omschrijving_sectie.dart';
import '../widget/klus_prijs_blok.dart';
import 'stroom_verlaten_dialoog.dart';

/// "Klus plaatsen" op één pagina (B4, mockup KlusPlaatsen): categorie,
/// vertel wat je wilt, foto (verplicht), wanneer met tijdwiel, herhalen
/// (Plus, nog op slot), waar (uit Mijn gegevens), de nee-lijst met het
/// verplichte vinkje, de prijs (voorbeeld) en één grote knop. Ontbreekt er
/// iets, dan zegt een meldbalk wat. Plaatst de klus (status open; de
/// meldkamer keurt hem eerst) en gaat naar O6. Terug vraagt "Weet je het
/// zeker?" zodra er al iets is ingevuld.
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
    final dag = concept.dag;
    final vanaf = concept.vanafMinuten;
    if (!concept.heeftWat) return TekstenKlusNl.ontbreektWat;
    if (!concept.heeftOmschrijving) return TekstenKlusNl.ontbreektOmschrijving;
    if (!concept.heeftFoto) return TekstenKlusNl.ontbreektFoto;
    if (dag == null || vanaf == null) return TekstenKlusNl.ontbreektWanneer;
    if (isVoorbij(dag, vanaf, ref.read(klokProvider)())) {
      return TekstenKlusNl.ontbreektTijdVoorbij;
    }
    if (!concept.heeftGeldigeEindtijd) return TekstenKlusNl.ontbreektTot;
    if (!concept.heeftWaar) return TekstenKlusNl.ontbreektWaar;
    if (!concept.isNeeLijstAkkoord) return TekstenKlusNl.ontbreektNeeLijst;
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
        titel: TekstenKlusNl.paginaTitel,
        onTerug: _verlaten,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _Kop(TekstenKlusNl.watTitel),
            SizedBox(height: tussen),
            const HulpvraagWatSectie(),
            SizedBox(height: blok),
            KlusOmschrijvingSectie(toonFout: _toonFouten),
            SizedBox(height: blok),
            const _Kop(
              TekstenKlusNl.fotoTitel,
              label: TekstenKlusNl.fotoVerplicht,
            ),
            SizedBox(height: tussen),
            KlusFotoSectie(toonFout: _toonFouten),
            SizedBox(height: blok),
            const _Kop(TekstenKlusNl.wanneerTitel),
            SizedBox(height: tussen),
            const HulpvraagWanneerSectie(),
            // B5 (punt 12): "4 helpers kunnen nu helpen" (alleen een aantal).
            const _HelpersNu(),
            SizedBox(height: blok),
            const _Kop(TekstenKlusNl.herhalenTitel),
            SizedBox(height: tussen),
            const KlusHerhalenSectie(),
            SizedBox(height: blok),
            const _Kop(TekstenKlusNl.waarTitel),
            SizedBox(height: tussen),
            HulpvraagWaarSectie(toonFouten: _toonFouten),
            SizedBox(height: blok),
            KlusNeeLijstKaart(toonFout: _toonFouten),
            SizedBox(height: blok),
            const KlusPrijsBlok(),
            if (_melding != null) ...[
              SizedBox(height: tussen),
              HhMeldBalk(soort: HhMeldSoort.waarschuwing, tekst: _melding!),
            ],
            SizedBox(height: tussen),
            HhKnop(
              label: TekstenKlusNl.plaatsen,
              semantiekLabel: TekstenKlusNl.plaatsenSemantiek,
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

/// Kop van een deel van de pagina: vet en primair groen (mockup). Met
/// [label] een grijs pilletje erachter, zoals "verplicht" bij de foto.
class _Kop extends StatelessWidget {
  const _Kop(this.tekst, {this.label});

  final String tekst;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final stijl = Theme.of(context).textTheme;
    final extra = label;
    return Semantics(
      header: true,
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: HhRuimte.s,
        children: [
          Text(
            tekst,
            style: stijl.titleLarge?.copyWith(
              color: HhKleuren.primair,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (extra != null)
            DecoratedBox(
              decoration: BoxDecoration(
                color: HhKleuren.oppervlak,
                borderRadius: BorderRadius.circular(HhRadius.groot),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: HhRuimte.s,
                  vertical: 2,
                ),
                child: Text(
                  extra,
                  style: stijl.bodySmall?.copyWith(
                    color: HhKleuren.tekstGedempt,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// B5: hoeveel helpers nu kunnen, voor de gekozen categorie en tijd.
class _HelpersNu extends ConsumerWidget {
  const _HelpersNu();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final concept = ref.watch(conceptProvider);
    final type = concept.klustype;
    if (type == null) return const SizedBox.shrink();
    final dag = concept.dag;
    final vanaf = concept.vanafMinuten;
    final van = dag != null && vanaf != null ? momentOp(dag, vanaf) : null;
    final totMin = concept.totMinuten;
    final tot = dag != null && concept.heeftEindtijd && totMin != null
        ? momentOp(dag, totMin)
        : null;
    return Padding(
      padding: EdgeInsets.only(
        top: HhRuimte.voor(HhRuimte.m, HhDichtheidScope.van(context)),
      ),
      child: HelpersKunnenNuRegel(klustypeId: type.id, van: van, tot: tot),
    );
  }
}
