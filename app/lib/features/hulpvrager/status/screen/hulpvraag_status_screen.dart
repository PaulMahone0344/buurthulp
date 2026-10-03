import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/navigatie.dart';
import '../../../../core/hh_fout.dart';
import '../../../../core/pb/uitvoer_gateway.dart';
import '../../../../design/components/hh_kaart.dart';
import '../../../../design/components/hh_knop.dart';
import '../../../../design/components/hh_laad_staat.dart';
import '../../../../design/components/hh_lege_staat.dart';
import '../../../../design/components/hh_meld_balk.dart';
import '../../../../design/components/hh_scherm.dart';
import '../../../../design/dichtheid_scope.dart';
import '../../../../l10n/teksten_beoordelen_nl.dart';
import '../../../../l10n/teksten_nl.dart';
import '../../../../l10n/teksten_uitvoeren_nl.dart';
import '../../../../theme.dart';
import '../../../chat/domein/chat_regels.dart';
import '../../../chat/widget/chat_knop.dart';
import '../../../jongere/klussen/domein/wanneer_tekst.dart';
import '../../../jongere/klussen/model/hh_klus.dart';
import '../../../jongere/uitvoeren/domein/klus_overgang.dart';
import '../../../jongere/uitvoeren/provider/uitvoeren_providers.dart';
import '../../../jongere/uitvoeren/widget/bel_actie.dart';
import '../../../jongere/uitvoeren/widget/persoon_regel.dart';
import '../../beoordelen/paden_beoordelen.dart';
import '../../provider/hulpvrager_providers.dart' show klokProvider;
import '../domein/hulpvraag_indeling.dart';
import '../paden_status.dart';
import '../provider/status_providers.dart';
import '../widget/oudere_annuleer_dialoog.dart';
import '../../../../l10n/teksten_klus_nl.dart';

/// O7. Waar de hulpvraag staat, in gewone taal: "Sanne is onderweg naar u."
/// Ouderenregel: hooguit drie acties (chat, bellen, stoppen; zonder helper
/// vernieuwen in plaats van chat), grote tekst en knoppen, altijd een
/// zichtbare terugknop, geen cijfers of statistiek. De klus wordt live
/// gevolgd; valt dat weg, dan blijft pull-to-refresh werken.
class HulpvraagStatusScreen extends ConsumerStatefulWidget {
  const HulpvraagStatusScreen({required this.klusId, super.key});

  final String klusId;

  @override
  ConsumerState<HulpvraagStatusScreen> createState() =>
      _HulpvraagStatusScreenState();
}

class _HulpvraagStatusScreenState extends ConsumerState<HulpvraagStatusScreen> {
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
    ref.invalidate(mijnHulpvragenProvider);
  }

  Future<void> _stop() async {
    final reden = await vraagOudereAnnuleerReden(context);
    if (reden == null || !mounted) return;
    setState(() {
      _isBezig = true;
      _melding = null;
    });
    final uitkomst = await ref.read(annuleerProvider)(widget.klusId, reden);
    if (!mounted) return;
    setState(() => _isBezig = false);
    ref.invalidate(mijnHulpvragenProvider);
    switch (uitkomst) {
      case UitvoerGelukt():
        _toon(TekstenUitvoerenNl.o7AnnuleerGelukt, HhMeldSoort.geslaagd);
      case UitvoerGeweigerd(:final melding):
        _toon(
          melding ?? TekstenUitvoerenNl.annuleerMislukt,
          HhMeldSoort.waarschuwing,
        );
      case UitvoerFout(:final fout):
        _toon(fout.melding, HhMeldSoort.fout);
    }
  }

  @override
  Widget build(BuildContext context) {
    final stand = ref.watch(klusVolgerProvider(widget.klusId));
    final nu = ref.watch(klokProvider)();

    return switch (stand) {
      AsyncData<KlusMetGeschiedenis>(:final value) => _Inhoud(
        klus: value.klus,
        nu: nu,
        isBezig: _isBezig,
        melding: _melding,
        meldSoort: _meldSoort,
        onStop: _stop,
        onVernieuw: _vernieuw,
        onBelMelding: _toon,
      ),
      AsyncError<KlusMetGeschiedenis>(:final error) => HhScherm(
        titel: TekstenUitvoerenNl.o7Titel,
        onTerug: () => terugOf(context, HhPadenStatus.hulpvragen),
        child: HhLegeStaat(
          icoon: Icons.cloud_off_outlined,
          titel: TekstenUitvoerenNl.o7LadenMislukt,
          uitleg: error is HhFout ? error.melding : TekstenNl.foutOnbekend,
          knopLabel: TekstenNl.opnieuwProberen,
          onKnop: _vernieuw,
        ),
      ),
      _ => HhScherm(
        titel: TekstenUitvoerenNl.o7Titel,
        onTerug: () => terugOf(context, HhPadenStatus.hulpvragen),
        child: const HhLaadStaat.skelet(regels: 3),
      ),
    };
  }
}

class _Inhoud extends StatelessWidget {
  const _Inhoud({
    required this.klus,
    required this.nu,
    required this.isBezig,
    required this.melding,
    required this.meldSoort,
    required this.onStop,
    required this.onVernieuw,
    required this.onBelMelding,
  });

  final HhKlus klus;
  final DateTime nu;
  final bool isBezig;
  final String? melding;
  final HhMeldSoort meldSoort;
  final Future<void> Function() onStop;
  final Future<void> Function() onVernieuw;
  final void Function(String, HhMeldSoort) onBelMelding;

  @override
  Widget build(BuildContext context) {
    final dichtheid = HhDichtheidScope.van(context);
    final tekst = Theme.of(context).textTheme;
    final rand = HhRuimte.voor(HhRuimte.l, dichtheid);
    final tussen = HhRuimte.voor(HhRuimte.l, dichtheid);

    final heeftJongere = klus.jongereVoornaam.isNotEmpty;
    final magBellen = heeftJongere && magBellenBij(klus.status);
    final magStoppen = magOudereAnnuleren(klus.status);
    // M7: bij afgerond "Hoe ging het?" (O9). Bellen en stoppen zijn dan al
    // weg, dus het blijven hooguit drie acties. Nooit sterren van de jongere
    // op dit scherm (ouderenregel).
    final magBeoordelen = heeftJongere && klus.status == HhKlusStatus.afgerond;
    final wanneer = wanneerTekst(klus.wanneerVan, klus.wanneerTot, nu);
    final toonChat = heeftJongere && heeftChat(klus);

    return HhScherm(
      titel: TekstenUitvoerenNl.o7Titel,
      onTerug: () => terugOf(context, HhPadenStatus.hulpvragen),
      toonTerug: true,
      scrollbaar: false,
      child: RefreshIndicator(
        onRefresh: onVernieuw,
        color: Theme.of(context).colorScheme.primary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            rand,
            0,
            rand,
            HhRuimte.voor(HhRuimte.xl, dichtheid),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (melding != null) ...[
                HhMeldBalk(soort: meldSoort, tekst: melding!),
                SizedBox(height: tussen),
              ],
              // De ene zin die telt, groot en zonder cijfers.
              Text(statusZin(klus), style: tekst.headlineMedium),
              // B4: eerst kijkt de meldkamer; een afkeuring met de reden.
              if (klus.wordtNagekeken) ...[
                SizedBox(height: HhRuimte.voor(HhRuimte.s, dichtheid)),
                const HhMeldBalk(
                  soort: HhMeldSoort.waarschuwing,
                  tekst: TekstenKlusNl.wordtNagekekenUitleg,
                ),
              ] else if (klus.afkeurReden.isNotEmpty) ...[
                SizedBox(height: HhRuimte.voor(HhRuimte.s, dichtheid)),
                HhMeldBalk(
                  soort: HhMeldSoort.waarschuwing,
                  tekst: TekstenKlusNl.afgekeurdReden(klus.afkeurReden),
                ),
              ] else if (!heeftJongere) ...[
                SizedBox(height: HhRuimte.voor(HhRuimte.s, dichtheid)),
                Text(
                  TekstenUitvoerenNl.o7GeenJongereUitleg,
                  style: tekst.bodyLarge,
                ),
              ],
              SizedBox(height: tussen),
              if (heeftJongere) ...[
                HhKaart(
                  semantiekLabel: TekstenUitvoerenNl.o7Helper,
                  child: PersoonRegel(
                    naam: klus.jongereVoornaam,
                    isIdGecontroleerd: klus.isJongereIdGecontroleerd,
                    onderregel: TekstenUitvoerenNl.o7Helper,
                  ),
                ),
                SizedBox(height: tussen),
              ],
              HhKaart(
                kop: TekstenUitvoerenNl.o7WanneerKop,
                child: Text(
                  wanneer.isEmpty ? TekstenUitvoerenNl.o7GeenTijd : wanneer,
                  style: tekst.bodyLarge,
                ),
              ),
              SizedBox(height: tussen),
              HhKaart(
                kop: TekstenUitvoerenNl.o7WatKop,
                child: Text(
                  klus.omschrijving.isEmpty
                      ? metHoofdletter(klus.klustypeNaam)
                      : klus.omschrijving,
                  style: tekst.bodyLarge,
                ),
              ),
              SizedBox(height: HhRuimte.voor(HhRuimte.xl, dichtheid)),

              // Hooguit drie acties, groot en onder elkaar. B6: zodra er een
              // helper is, neemt de chat de plaats van "Vernieuwen" in (die
              // blijft als pull-to-refresh; realtime loopt door).
              if (toonChat) ...[
                ChatKnop(
                  klusId: klus.id,
                  naam: klus.jongereVoornaam,
                  soort: HhKnopSoort.primair,
                ),
                SizedBox(height: tussen),
              ],
              if (magBellen) ...[
                BelKnop(
                  klusId: klus.id,
                  label: TekstenUitvoerenNl.o7Bellen,
                  semantiekLabel: TekstenUitvoerenNl.o7BellenSemantiek(
                    klus.jongereVoornaam,
                  ),
                  soort: HhKnopSoort.primair,
                  onMelding: onBelMelding,
                ),
                SizedBox(height: tussen),
              ],
              if (magStoppen) ...[
                HhKnop(
                  label: TekstenUitvoerenNl.o7Annuleren,
                  semantiekLabel: TekstenUitvoerenNl.o7AnnulerenSemantiek,
                  icoon: Icons.cancel_outlined,
                  soort: HhKnopSoort.tweedeKeus,
                  onPressed: isBezig ? null : onStop,
                ),
                SizedBox(height: tussen),
              ],
              if (magBeoordelen) ...[
                HhKnop(
                  label: TekstenBeoordelenNl.o7HoeGingHet,
                  semantiekLabel: TekstenBeoordelenNl.o7HoeGingHetSemantiek(
                    klus.jongereVoornaam,
                  ),
                  icoon: Icons.thumb_up_outlined,
                  onPressed: () =>
                      context.push(HhPadenBeoordelen.beoordelen(klus.id)),
                ),
                SizedBox(height: tussen),
              ],
              if (klus.status == HhKlusStatus.geannuleerd) ...[
                Text(
                  TekstenUitvoerenNl.o7GeannuleerdUitleg,
                  style: tekst.bodyLarge,
                ),
                SizedBox(height: tussen),
              ],
              if (!toonChat)
                HhKnop(
                  label: TekstenUitvoerenNl.o7Vernieuwen,
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
