import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/navigatie.dart';
import '../../../../core/pb/beoordeling_gateway.dart';
import '../../../../design/components/hh_invoer.dart';
import '../../../../design/components/hh_kaart.dart';
import '../../../../design/components/hh_knop.dart';
import '../../../../design/components/hh_laad_staat.dart';
import '../../../../design/components/hh_lege_staat.dart';
import '../../../../design/components/hh_meld_balk.dart';
import '../../../../design/components/hh_scherm.dart';
import '../../../../design/dichtheid_scope.dart';
import '../../../../l10n/teksten_beoordelen_nl.dart';
import '../../../../l10n/teksten_nl.dart';
import '../../../../theme.dart';
import '../../../toegang/provider/sessie_providers.dart';
import '../../klussen/paden_klussen.dart';
import '../../provider/screening_providers.dart' show meldingVanFout;
import '../domein/sterren.dart';
import '../provider/beoordeling_providers.dart';
import '../widget/sterren_kiezer.dart';

/// J17. De jongere geeft de oudere sterren en eventueel een tekst (max 500).
/// Vanuit de eindstaat van J15 en vanuit J14 Historie ("Nog beoordelen").
/// Staat er al een beoordeling van hem, dan is alles ingevuld en wordt het
/// wijzigen. Een tweede beoordeling weigert de server (unieke index); dat
/// wordt een nette melding en het scherm schakelt naar wijzigen.
class BeoordelingGevenScreen extends ConsumerStatefulWidget {
  const BeoordelingGevenScreen({required this.klusId, super.key});

  final String klusId;

  @override
  ConsumerState<BeoordelingGevenScreen> createState() =>
      _BeoordelingGevenScreenState();
}

class _BeoordelingGevenScreenState
    extends ConsumerState<BeoordelingGevenScreen> {
  final _tekst = TextEditingController();
  int? _sterren;
  bool _isIngevuld = false;
  bool _isBezig = false;
  bool _isOpgeslagen = false;
  String? _melding;
  HhMeldSoort _meldSoort = HhMeldSoort.informatie;
  String? _tekstFout;

  @override
  void dispose() {
    _tekst.dispose();
    super.dispose();
  }

  /// Eén keer: wat er al stond, in het formulier zetten.
  void _vulIn(TeBeoordelen doel) {
    if (_isIngevuld) return;
    _isIngevuld = true;
    final bestaande = doel.bestaande;
    if (bestaande != null) {
      _sterren = bestaande.sterren;
      _tekst.text = bestaande.tekst;
    }
  }

  Future<void> _opslaan(TeBeoordelen doel) async {
    final sterren = _sterren;
    final tekst = _tekst.text;
    final tekstGoed = isGeldigeBeoordelingTekst(tekst);
    setState(() {
      _tekstFout = tekstGoed ? null : TekstenBeoordelenNl.tekstTeLang;
      _melding = isGeldigAantalSterren(sterren)
          ? null
          : TekstenBeoordelenNl.kiesSterren;
      _meldSoort = HhMeldSoort.fout;
    });
    if (!tekstGoed || sterren == null || !isGeldigAantalSterren(sterren)) {
      return;
    }

    setState(() => _isBezig = true);
    final wasWijzigen = doel.bestaande != null;
    final uitkomst = await ref.read(slaBeoordelingOpProvider)(
      doel,
      sterren: sterren,
      tekst: tekst,
    );
    if (!mounted) return;
    setState(() {
      _isBezig = false;
      switch (uitkomst) {
        case BeoordelingOpgeslagen():
          _isOpgeslagen = true;
          _meldSoort = HhMeldSoort.geslaagd;
          _melding = wasWijzigen
              ? TekstenBeoordelenNl.j17Gewijzigd
              : TekstenBeoordelenNl.j17Gelukt;
        case BeoordelingGeweigerd(:final reden):
          _meldSoort = HhMeldSoort.waarschuwing;
          _melding = switch (reden) {
            BeoordelingReden.alGegeven => TekstenBeoordelenNl.j17AlGegeven,
            BeoordelingReden.nietToegestaan =>
              TekstenBeoordelenNl.nietToegestaan,
            BeoordelingReden.nietGevonden => TekstenBeoordelenNl.nietGevonden,
          };
        case BeoordelingFout(:final fout):
          _meldSoort = HhMeldSoort.fout;
          _melding = fout.melding;
      }
    });
  }

  void _terug() => terugOf(context, HhPadenKlussen.mijnKlussen);

  @override
  Widget build(BuildContext context) {
    final stand = ref.watch(teBeoordelenProvider(widget.klusId));
    final ikId = ref.watch(huidigeGebruikerProvider)?.id ?? '';

    // Tijdens herladen (na opslaan) blijft het formulier staan met de
    // vorige waarde; alleen de eerste keer is er een laadstaat.
    final doel = stand.value;
    if (doel != null) {
      _vulIn(doel);
      return _formulier(context, doel, ikId);
    }
    if (stand.hasError) {
      return HhScherm(
        titel: TekstenBeoordelenNl.j17Titel,
        onTerug: _terug,
        child: HhLegeStaat(
          icoon: Icons.cloud_off_outlined,
          titel: TekstenBeoordelenNl.j17LadenMislukt,
          uitleg: meldingVanFout(stand.error),
          knopLabel: TekstenNl.opnieuwProberen,
          onKnop: () => ref.invalidate(teBeoordelenProvider(widget.klusId)),
        ),
      );
    }
    return HhScherm(
      titel: TekstenBeoordelenNl.j17Titel,
      onTerug: _terug,
      child: const HhLaadStaat.skelet(regels: 3),
    );
  }

  Widget _formulier(BuildContext context, TeBeoordelen doel, String ikId) {
    final dichtheid = HhDichtheidScope.van(context);
    final tekst = Theme.of(context).textTheme;
    final tussen = HhRuimte.voor(HhRuimte.l, dichtheid);
    final klus = doel.klus;
    final isWijzigen = doel.bestaande != null;

    if (klus.status != HhKlusStatus.afgerond || doel.naarVoor(ikId).isEmpty) {
      return HhScherm(
        titel: TekstenBeoordelenNl.j17Titel,
        onTerug: _terug,
        child: HhLegeStaat(
          icoon: Icons.hourglass_empty_outlined,
          titel: TekstenBeoordelenNl.nietAfgerond,
          uitleg: TekstenBeoordelenNl.nietAfgerondUitleg,
          knopLabel: TekstenBeoordelenNl.j17NaarMijnKlussen,
          onKnop: () => context.go(HhPadenKlussen.mijnKlussen),
        ),
      );
    }

    return HhScherm(
      titel: TekstenBeoordelenNl.j17Titel,
      onTerug: _terug,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_melding != null) ...[
            HhMeldBalk(soort: _meldSoort, tekst: _melding!),
            SizedBox(height: tussen),
          ] else if (isWijzigen && !_isOpgeslagen) ...[
            const HhMeldBalk(
              soort: HhMeldSoort.informatie,
              tekst: TekstenBeoordelenNl.j17BestaandUitleg,
            ),
            SizedBox(height: tussen),
          ],
          Text(
            klus.oudereNaam.isEmpty
                ? TekstenBeoordelenNl.j17VraagZonderNaam
                : TekstenBeoordelenNl.j17Vraag(klus.oudereNaam),
            style: tekst.titleLarge,
          ),
          SizedBox(height: tussen),
          HhKaart(
            kop: TekstenBeoordelenNl.j17SterrenKop,
            child: SterrenKiezer(
              gekozen: _sterren,
              onGekozen: _isBezig
                  ? null
                  : (ster) => setState(() {
                      _sterren = ster;
                      if (_melding == TekstenBeoordelenNl.kiesSterren) {
                        _melding = null;
                      }
                    }),
            ),
          ),
          SizedBox(height: tussen),
          HhInvoer(
            label: TekstenBeoordelenNl.j17TekstLabel,
            hulptekst: TekstenBeoordelenNl.j17TekstHulp,
            fouttekst: _tekstFout,
            controller: _tekst,
            isActief: !_isBezig,
            maxRegels: 5,
          ),
          SizedBox(height: HhRuimte.voor(HhRuimte.xl, dichtheid)),
          HhKnop(
            label: isWijzigen
                ? TekstenBeoordelenNl.j17Opslaan
                : TekstenBeoordelenNl.j17Versturen,
            icoon: Icons.send_outlined,
            isBezig: _isBezig,
            onPressed: () => _opslaan(doel),
          ),
          if (_isOpgeslagen) ...[
            SizedBox(height: tussen),
            HhKnop(
              label: TekstenBeoordelenNl.j17NaarMijnKlussen,
              icoon: Icons.assignment_turned_in_outlined,
              soort: HhKnopSoort.tweedeKeus,
              onPressed: () => context.go(HhPadenKlussen.mijnKlussen),
            ),
          ],
        ],
      ),
    );
  }
}
