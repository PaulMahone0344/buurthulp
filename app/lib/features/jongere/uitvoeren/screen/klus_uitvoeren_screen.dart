import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/navigatie.dart';
import '../../../../app/paden.dart';
import '../../../../core/pb/uitvoer_gateway.dart';
import '../../../../design/components/hh_kaart.dart';
import '../../../../design/components/hh_knop.dart';
import '../../../../design/components/hh_laad_staat.dart';
import '../../../../design/components/hh_lege_staat.dart';
import '../../../../design/components/hh_meld_balk.dart';
import '../../../../design/components/hh_scherm.dart';
import '../../../../design/dichtheid_scope.dart';
import '../../../../l10n/teksten_beoordelen_nl.dart';
import '../../../../l10n/teksten_klussen_nl.dart';
import '../../../../l10n/teksten_nl.dart';
import '../../../../l10n/teksten_uitvoeren_nl.dart';
import '../../../../theme.dart';
import '../../../hulpvrager/provider/hulpvrager_providers.dart'
    show klokProvider;
import '../../../toegang/provider/sessie_providers.dart';
import '../../klussen/domein/wanneer_tekst.dart';
import '../../klussen/paden_klussen.dart';
import '../../klussen/widget/klus_status_pil.dart';
import '../../provider/screening_providers.dart' show meldingVanFout;
import '../../reputatie/paden_reputatie.dart';
import '../../reputatie/provider/beoordeling_providers.dart';
import '../domein/klus_overgang.dart';
import '../provider/uitvoeren_providers.dart';
import '../widget/annuleer_dialoog.dart';
import '../widget/bel_actie.dart';
import '../widget/klus_stappen.dart';
import '../widget/persoon_regel.dart';

/// J15. Eén klus, één grote knop per stap: "Ik ga op weg" -> "Ik ben er" ->
/// "Klus is klaar". De server beslist; een 409 zet een meldbalk neer en
/// laadt het scherm opnieuw. De klus wordt live gevolgd (realtime), maar
/// "Vernieuwen" en pull-to-refresh blijven werken als dat wegvalt.
class KlusUitvoerenScreen extends ConsumerStatefulWidget {
  const KlusUitvoerenScreen({required this.klusId, super.key});

  final String klusId;

  @override
  ConsumerState<KlusUitvoerenScreen> createState() =>
      _KlusUitvoerenScreenState();
}

class _KlusUitvoerenScreenState extends ConsumerState<KlusUitvoerenScreen> {
  bool _isBezig = false;
  String? _melding;
  HhMeldSoort _meldSoort = HhMeldSoort.informatie;

  void _toon(String tekst, HhMeldSoort soort) {
    if (!mounted) return;
    setState(() {
      _melding = tekst;
      _meldSoort = soort;
    });
  }

  Future<void> _vernieuw() async {
    await ref.read(klusVolgerProvider(widget.klusId).notifier).vernieuw();
  }

  Future<void> _zetStap(HhKlusStatus naar) async {
    setState(() {
      _isBezig = true;
      _melding = null;
    });
    final uitkomst = await ref.read(zetStatusProvider)(widget.klusId, naar);
    if (!mounted) return;
    setState(() => _isBezig = false);
    switch (uitkomst) {
      case UitvoerGelukt(:final status):
        _toon(
          TekstenUitvoerenNl.j15Gezet(KlusStappen.naamVan(status)),
          HhMeldSoort.geslaagd,
        );
      case UitvoerGeweigerd(:final reden, :final melding):
        _toon(melding ?? _standaardMelding(reden), HhMeldSoort.fout);
      case UitvoerFout(:final fout):
        _toon(fout.melding, HhMeldSoort.fout);
    }
  }

  Future<void> _annuleer() async {
    final reden = await vraagAnnuleerReden(context);
    if (reden == null || !mounted) return;
    setState(() {
      _isBezig = true;
      _melding = null;
    });
    final uitkomst = await ref.read(annuleerProvider)(widget.klusId, reden);
    if (!mounted) return;
    setState(() => _isBezig = false);
    switch (uitkomst) {
      case UitvoerGelukt():
        _toon(TekstenUitvoerenNl.j15Geannuleerd, HhMeldSoort.informatie);
      case UitvoerGeweigerd(:final reden, :final melding):
        _toon(melding ?? _standaardMelding(reden), HhMeldSoort.fout);
      case UitvoerFout(:final fout):
        _toon(fout.melding, HhMeldSoort.fout);
    }
  }

  static String _standaardMelding(UitvoerReden reden) => switch (reden) {
    UitvoerReden.nietMeerMogelijk => TekstenUitvoerenNl.j15StapNietMeer,
    UitvoerReden.isBezig => TekstenUitvoerenNl.j15StapNietMeer,
    UitvoerReden.geenNummer => TekstenUitvoerenNl.belGeenNummer,
    UitvoerReden.geenToegang => TekstenUitvoerenNl.j15NietVanJou,
    UitvoerReden.nietGevonden => TekstenKlussenNl.j13NietGevonden,
    UitvoerReden.ongeldigeReden => TekstenUitvoerenNl.annuleerMislukt,
  };

  @override
  Widget build(BuildContext context) {
    final stand = ref.watch(klusVolgerProvider(widget.klusId));
    final gebruiker = ref.watch(huidigeGebruikerProvider);
    final nu = ref.watch(klokProvider)();

    return switch (stand) {
      AsyncData<KlusMetGeschiedenis>(:final value) => _Inhoud(
        stand: value,
        nu: nu,
        isMijn: value.klus.isToegewezenAan(gebruiker?.id ?? ''),
        isBezig: _isBezig,
        melding: _melding,
        meldSoort: _meldSoort,
        onStap: _zetStap,
        onAnnuleer: _annuleer,
        onVernieuw: _vernieuw,
        onBelMelding: _toon,
      ),
      AsyncError<KlusMetGeschiedenis>(:final error) => HhScherm(
        titel: TekstenUitvoerenNl.j15Titel,
        onTerug: () => terugOf(context, HhPaden.jongere),
        child: HhLegeStaat(
          icoon: Icons.cloud_off_outlined,
          titel: TekstenUitvoerenNl.j15LadenMislukt,
          uitleg: meldingVanFout(error),
          knopLabel: TekstenNl.opnieuwProberen,
          onKnop: _vernieuw,
        ),
      ),
      _ => HhScherm(
        titel: TekstenUitvoerenNl.j15Titel,
        onTerug: () => terugOf(context, HhPaden.jongere),
        child: const HhLaadStaat.skelet(regels: 4),
      ),
    };
  }
}

class _Inhoud extends ConsumerWidget {
  const _Inhoud({
    required this.stand,
    required this.nu,
    required this.isMijn,
    required this.isBezig,
    required this.melding,
    required this.meldSoort,
    required this.onStap,
    required this.onAnnuleer,
    required this.onVernieuw,
    required this.onBelMelding,
  });

  final KlusMetGeschiedenis stand;
  final DateTime nu;
  final bool isMijn;
  final bool isBezig;
  final String? melding;
  final HhMeldSoort meldSoort;
  final void Function(HhKlusStatus) onStap;
  final Future<void> Function() onAnnuleer;
  final Future<void> Function() onVernieuw;
  final void Function(String, HhMeldSoort) onBelMelding;

  static String labelVoor(HhKlusStatus volgende) => switch (volgende) {
    HhKlusStatus.onderweg => TekstenUitvoerenNl.j15KnopOnderweg,
    HhKlusStatus.bezig => TekstenUitvoerenNl.j15KnopAangekomen,
    HhKlusStatus.afgerond => TekstenUitvoerenNl.j15KnopAfgerond,
    _ => TekstenUitvoerenNl.j15KnopOnderweg,
  };

  static IconData icoonVoor(HhKlusStatus volgende) => switch (volgende) {
    HhKlusStatus.onderweg => Icons.directions_walk,
    HhKlusStatus.bezig => Icons.where_to_vote_outlined,
    HhKlusStatus.afgerond => Icons.check_circle_outline,
    _ => Icons.arrow_forward,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final klus = stand.klus;
    final dichtheid = HhDichtheidScope.van(context);
    final tekst = Theme.of(context).textTheme;
    final tussen = HhRuimte.voor(HhRuimte.l, dichtheid);
    final klein = HhRuimte.voor(HhRuimte.s, dichtheid);

    final volgende = volgendeStap(klus.status);
    // M7: al beoordeeld? Laadt de lijst (nog) niet, dan "Beoordeling geven";
    // J17 zet het daar zelf recht.
    final isBeoordeeld =
        ref.watch(gegevenBeoordelingenProvider).value?.containsKey(klus.id) ??
        false;
    final magAnnuleren = isMijn && magJongereAnnuleren(klus.status);
    final magBellen = isMijn && magBellenBij(klus.status);

    // scrollbaar: false, zodat de RefreshIndicator bóven de scrollwikkel
    // zit: pull-to-refresh werkt alleen als hij zelf de scroller omvat.
    return HhScherm(
      titel: TekstenUitvoerenNl.j15Titel,
      onTerug: () => terugOf(context, HhPadenKlussen.mijnKlussen),
      scrollbaar: false,
      child: RefreshIndicator(
        onRefresh: onVernieuw,
        color: Theme.of(context).colorScheme.primary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            HhRuimte.voor(HhRuimte.l, dichtheid),
            0,
            HhRuimte.voor(HhRuimte.l, dichtheid),
            HhRuimte.voor(HhRuimte.xl, dichtheid),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: KlusStatusPil(status: klus.status),
              ),
              SizedBox(height: tussen),
              if (melding != null) ...[
                HhMeldBalk(soort: meldSoort, tekst: melding!),
                SizedBox(height: tussen),
              ],
              if (!isMijn) ...[
                HhLegeStaat(
                  icoon: Icons.assignment_late_outlined,
                  titel: TekstenUitvoerenNl.j15Geannuleerd,
                  uitleg: TekstenUitvoerenNl.j15GeannuleerdUitleg,
                  knopLabel: TekstenUitvoerenNl.j15NaarKlussen,
                  onKnop: () => context.go(HhPaden.jongere),
                ),
                SizedBox(height: tussen),
              ] else ...[
                HhKaart(
                  kop: TekstenUitvoerenNl.j15StapbalkTitel,
                  child: KlusStappen(stand: stand),
                ),
                SizedBox(height: tussen),
              ],
              HhKaart(
                kop: TekstenUitvoerenNl.j15WanneerKop,
                child: Text(
                  wanneerTekst(klus.wanneerVan, klus.wanneerTot, nu),
                  style: tekst.bodyLarge,
                ),
              ),
              SizedBox(height: tussen),
              HhKaart(
                kop: TekstenUitvoerenNl.j15WaarKop,
                child: Text(
                  klus.adres.isEmpty
                      ? TekstenUitvoerenNl.j15GeenAdres
                      : klus.adres,
                  style: tekst.bodyLarge,
                ),
              ),
              SizedBox(height: tussen),
              HhKaart(
                kop: TekstenUitvoerenNl.j15VoorWieKop,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PersoonRegel(
                      naam: klus.isOudereZichtbaar
                          ? klus.oudereNaam
                          : TekstenKlussenNl.buurtbewoner,
                      fotoUrl: klus.oudereFotoUrl,
                    ),
                    if (klus.oudereContactNaam.isNotEmpty) ...[
                      SizedBox(height: klein),
                      Text(
                        '${TekstenUitvoerenNl.j15ContactKop}: ${klus.oudereContactNaam}',
                        style: tekst.bodyMedium,
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(height: tussen),
              HhKaart(
                kop: TekstenKlussenNl.j13ToelichtingKop,
                child: Text(
                  klus.omschrijving.isEmpty
                      ? TekstenKlussenNl.j13GeenToelichting
                      : klus.omschrijving,
                  style: tekst.bodyLarge,
                ),
              ),
              SizedBox(height: HhRuimte.voor(HhRuimte.xl, dichtheid)),

              if (klus.status == HhKlusStatus.afgerond) ...[
                Text(
                  TekstenUitvoerenNl.j15Afgerond,
                  style: tekst.titleLarge,
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: klein),
                Text(
                  TekstenUitvoerenNl.j15AfgerondUitleg,
                  style: tekst.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: tussen),
                // M7: beoordelen (J17). Nog niet gedaan: de hoofdknop.
                if (isMijn && !isBeoordeeld) ...[
                  HhKnop(
                    label: TekstenBeoordelenNl.j15Beoordelen,
                    icoon: Icons.star_outline_rounded,
                    onPressed: () =>
                        context.push(HhPadenReputatie.beoordelen(klus.id)),
                  ),
                  SizedBox(height: tussen),
                ],
                HhKnop(
                  label: TekstenUitvoerenNl.j15NaarMijnKlussen,
                  icoon: Icons.assignment_turned_in_outlined,
                  soort: isMijn && !isBeoordeeld
                      ? HhKnopSoort.tweedeKeus
                      : HhKnopSoort.primair,
                  onPressed: () => context.go(HhPadenKlussen.mijnKlussen),
                ),
                if (isMijn && isBeoordeeld) ...[
                  SizedBox(height: tussen),
                  HhKnop(
                    label: TekstenBeoordelenNl.j15BeoordelingWijzigen,
                    icoon: Icons.edit_outlined,
                    soort: HhKnopSoort.tekst,
                    onPressed: () =>
                        context.push(HhPadenReputatie.beoordelen(klus.id)),
                  ),
                ],
              ] else if (volgende != null && isMijn) ...[
                HhKnop(
                  label: labelVoor(volgende),
                  icoon: icoonVoor(volgende),
                  maat: HhDichtheid.groot,
                  isBezig: isBezig,
                  onPressed: () => onStap(volgende),
                ),
                SizedBox(height: tussen),
              ],

              if (magBellen) ...[
                BelKnop(
                  klusId: klus.id,
                  label: TekstenUitvoerenNl.j15Bellen,
                  onMelding: onBelMelding,
                ),
                SizedBox(height: tussen),
              ],
              if (magAnnuleren)
                HhKnop(
                  label: TekstenUitvoerenNl.j15Annuleren,
                  semantiekLabel: TekstenUitvoerenNl.j15AnnulerenSemantiek,
                  icoon: Icons.undo,
                  soort: HhKnopSoort.tekst,
                  onPressed: isBezig ? null : onAnnuleer,
                ),
              SizedBox(height: tussen),
              HhKnop(
                label: TekstenUitvoerenNl.j15Vernieuwen,
                icoon: Icons.refresh,
                soort: HhKnopSoort.tekst,
                onPressed: onVernieuw,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
