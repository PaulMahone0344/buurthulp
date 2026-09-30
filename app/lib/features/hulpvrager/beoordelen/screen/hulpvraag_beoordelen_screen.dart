import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/navigatie.dart';
import '../../../../core/hh_fout.dart';
import '../../../../core/pb/beoordeling_gateway.dart';
import '../../../../design/components/hh_invoer.dart';
import '../../../../design/components/hh_knop.dart';
import '../../../../design/components/hh_laad_staat.dart';
import '../../../../design/components/hh_lege_staat.dart';
import '../../../../design/components/hh_meld_balk.dart';
import '../../../../design/components/hh_scherm.dart';
import '../../../../design/dichtheid_scope.dart';
import '../../../../l10n/teksten_beoordelen_nl.dart';
import '../../../../l10n/teksten_nl.dart';
import '../../../../theme.dart';
import '../../../jongere/reputatie/domein/sterren.dart';
import '../../../jongere/reputatie/provider/beoordeling_providers.dart';
import '../../../jongere/reputatie/widget/sterren_kiezer.dart';
import '../../../toegang/provider/sessie_providers.dart';
import '../../status/paden_status.dart';

/// De stappen van O9. Elke stap heeft hooguit drie keuzes (ouderenregel).
enum _Stap { duim, sterren, bedankt }

/// O9. De oudere zegt hoe het ging: eerst duim omhoog of omlaag (twee grote
/// knoppen), dan de sterren als grote tikvlakken (voorgevuld: omhoog 5,
/// omlaag 2), tekst mag. De duim is alleen een opstapje; opgeslagen worden
/// sterren en tekst. Vanuit O7 bij status afgerond en vanuit O8 Afgerond.
///
/// Ouderenregel: grote tekst en knoppen, altijd een zichtbare terugknop,
/// nooit een cijfer, gemiddelde of aantal. De sterren heten in woorden
/// ("Goed", "Heel goed").
class HulpvraagBeoordelenScreen extends ConsumerStatefulWidget {
  const HulpvraagBeoordelenScreen({required this.klusId, super.key});

  final String klusId;

  @override
  ConsumerState<HulpvraagBeoordelenScreen> createState() =>
      _HulpvraagBeoordelenScreenState();
}

class _HulpvraagBeoordelenScreenState
    extends ConsumerState<HulpvraagBeoordelenScreen> {
  final _tekst = TextEditingController();
  _Stap _stap = _Stap.duim;
  int? _sterren;
  bool _isIngevuld = false;
  bool _wasBestaand = false;
  bool _isBezig = false;
  String? _melding;
  HhMeldSoort _meldSoort = HhMeldSoort.informatie;
  String? _tekstFout;

  @override
  void dispose() {
    _tekst.dispose();
    super.dispose();
  }

  /// Eén keer: is er al een beoordeling, dan meteen naar de sterren, met
  /// wat er stond.
  void _vulIn(TeBeoordelen doel) {
    if (_isIngevuld) return;
    _isIngevuld = true;
    final bestaande = doel.bestaande;
    if (bestaande != null) {
      _wasBestaand = true;
      _stap = _Stap.sterren;
      _sterren = bestaande.sterren;
      _tekst.text = bestaande.tekst;
    }
  }

  void _kiesDuim(Duim duim) {
    setState(() {
      _sterren = sterrenVoorDuim(duim);
      _stap = _Stap.sterren;
      _melding = null;
    });
  }

  void _terug() {
    if (_stap == _Stap.sterren && !_wasBestaand) {
      setState(() {
        _stap = _Stap.duim;
        _melding = null;
      });
      return;
    }
    terugOf(context, HhPadenStatus.hulpvraag(widget.klusId));
  }

  Future<void> _opslaan(TeBeoordelen doel) async {
    final sterren = _sterren;
    final tekstGoed = isGeldigeBeoordelingTekst(_tekst.text);
    setState(() {
      _tekstFout = tekstGoed ? null : TekstenBeoordelenNl.o9TekstTeLang;
      _melding = isGeldigAantalSterren(sterren)
          ? null
          : TekstenBeoordelenNl.o9KiesSterren;
      _meldSoort = HhMeldSoort.waarschuwing;
    });
    if (!tekstGoed || sterren == null || !isGeldigAantalSterren(sterren)) {
      return;
    }

    setState(() => _isBezig = true);
    final uitkomst = await ref.read(slaBeoordelingOpProvider)(
      doel,
      sterren: sterren,
      tekst: _tekst.text,
    );
    if (!mounted) return;
    setState(() {
      _isBezig = false;
      switch (uitkomst) {
        case BeoordelingOpgeslagen():
          _stap = _Stap.bedankt;
          _melding = null;
        case BeoordelingGeweigerd(:final reden):
          _meldSoort = HhMeldSoort.waarschuwing;
          _melding = switch (reden) {
            BeoordelingReden.alGegeven => TekstenBeoordelenNl.o9AlGegeven,
            BeoordelingReden.nietToegestaan =>
              TekstenBeoordelenNl.o9NietAfgerond,
            BeoordelingReden.nietGevonden => TekstenBeoordelenNl.nietGevonden,
          };
        case BeoordelingFout(:final fout):
          _meldSoort = HhMeldSoort.fout;
          _melding = fout.melding;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final stand = ref.watch(teBeoordelenProvider(widget.klusId));
    final ikId = ref.watch(huidigeGebruikerProvider)?.id ?? '';

    final doel = stand.value;
    if (doel != null) {
      _vulIn(doel);
      return _inhoud(context, doel, ikId);
    }
    if (stand.hasError) {
      final fout = stand.error;
      return HhScherm(
        titel: TekstenBeoordelenNl.o9Titel,
        toonTerug: true,
        onTerug: _terug,
        child: HhLegeStaat(
          icoon: Icons.cloud_off_outlined,
          titel: TekstenBeoordelenNl.o9LadenMislukt,
          uitleg: fout is HhFout ? fout.melding : TekstenNl.foutOnbekend,
          knopLabel: TekstenNl.opnieuwProberen,
          onKnop: () => ref.invalidate(teBeoordelenProvider(widget.klusId)),
        ),
      );
    }
    return HhScherm(
      titel: TekstenBeoordelenNl.o9Titel,
      toonTerug: true,
      onTerug: _terug,
      child: const HhLaadStaat.skelet(regels: 3),
    );
  }

  Widget _inhoud(BuildContext context, TeBeoordelen doel, String ikId) {
    final dichtheid = HhDichtheidScope.van(context);
    final tekst = Theme.of(context).textTheme;
    final tussen = HhRuimte.voor(HhRuimte.l, dichtheid);
    final naam = doel.klus.jongereVoornaam;

    final kanBeoordelen =
        doel.klus.status == HhKlusStatus.afgerond &&
        doel.naarVoor(ikId).isNotEmpty;

    final List<Widget> kinderen;
    if (!kanBeoordelen) {
      kinderen = [
        HhLegeStaat(
          icoon: Icons.hourglass_empty_outlined,
          titel: TekstenBeoordelenNl.o9NietAfgerond,
          uitleg: TekstenBeoordelenNl.o9NietAfgerondUitleg,
          knopLabel: TekstenBeoordelenNl.o9NaarHulpvragen,
          onKnop: () => context.go(HhPadenStatus.hulpvragen),
        ),
      ];
    } else {
      kinderen = switch (_stap) {
        _Stap.duim => [
          Text(
            naam.isEmpty
                ? TekstenBeoordelenNl.o9DuimVraagZonderNaam
                : TekstenBeoordelenNl.o9DuimVraag(naam),
            style: tekst.headlineMedium,
          ),
          SizedBox(height: HhRuimte.voor(HhRuimte.xl, dichtheid)),
          HhKnop(
            label: TekstenBeoordelenNl.o9DuimOmhoog,
            semantiekLabel: TekstenBeoordelenNl.o9DuimOmhoogSemantiek,
            icoon: Icons.thumb_up_outlined,
            maat: HhDichtheid.groot,
            onPressed: () => _kiesDuim(Duim.omhoog),
          ),
          SizedBox(height: tussen),
          HhKnop(
            label: TekstenBeoordelenNl.o9DuimOmlaag,
            semantiekLabel: TekstenBeoordelenNl.o9DuimOmlaagSemantiek,
            icoon: Icons.thumb_down_outlined,
            soort: HhKnopSoort.tweedeKeus,
            maat: HhDichtheid.groot,
            onPressed: () => _kiesDuim(Duim.omlaag),
          ),
        ],
        _Stap.sterren => [
          if (_melding != null) ...[
            HhMeldBalk(soort: _meldSoort, tekst: _melding!),
            SizedBox(height: tussen),
          ] else if (_wasBestaand) ...[
            const HhMeldBalk(
              soort: HhMeldSoort.informatie,
              tekst: TekstenBeoordelenNl.o9BestaandUitleg,
            ),
            SizedBox(height: tussen),
          ],
          Text(
            naam.isEmpty
                ? TekstenBeoordelenNl.o9SterrenVraagZonderNaam
                : TekstenBeoordelenNl.o9SterrenVraag(naam),
            style: tekst.headlineMedium,
          ),
          SizedBox(height: tussen),
          SterrenKiezer(
            gekozen: _sterren,
            metAantal: false,
            onGekozen: _isBezig
                ? null
                : (ster) => setState(() => _sterren = ster),
          ),
          SizedBox(height: HhRuimte.voor(HhRuimte.s, dichtheid)),
          Text(
            TekstenBeoordelenNl.o9SterrenUitleg,
            style: tekst.bodyLarge,
            textAlign: TextAlign.center,
          ),
          SizedBox(height: tussen),
          HhInvoer(
            label: TekstenBeoordelenNl.o9TekstLabel,
            hulptekst: TekstenBeoordelenNl.o9TekstHulp,
            fouttekst: _tekstFout,
            controller: _tekst,
            isActief: !_isBezig,
            maxRegels: 4,
          ),
          SizedBox(height: HhRuimte.voor(HhRuimte.xl, dichtheid)),
          HhKnop(
            label: doel.bestaande != null
                ? TekstenBeoordelenNl.o9Opslaan
                : TekstenBeoordelenNl.o9Versturen,
            icoon: Icons.send_outlined,
            isBezig: _isBezig,
            onPressed: () => _opslaan(doel),
          ),
        ],
        _Stap.bedankt => [
          Icon(
            Icons.check_circle_outline,
            size: HhMaten.avatar(dichtheid),
            color: Theme.of(context).colorScheme.primary,
          ),
          SizedBox(height: tussen),
          Text(
            TekstenBeoordelenNl.o9Bedankt,
            style: tekst.headlineMedium,
            textAlign: TextAlign.center,
          ),
          SizedBox(height: HhRuimte.voor(HhRuimte.s, dichtheid)),
          Text(
            TekstenBeoordelenNl.o9BedanktUitleg,
            style: tekst.bodyLarge,
            textAlign: TextAlign.center,
          ),
          SizedBox(height: HhRuimte.voor(HhRuimte.xl, dichtheid)),
          HhKnop(
            label: TekstenBeoordelenNl.o9NaarHulpvragen,
            icoon: Icons.list_alt_outlined,
            onPressed: () => context.go(HhPadenStatus.hulpvragen),
          ),
        ],
      };
    }

    return HhScherm(
      titel: TekstenBeoordelenNl.o9Titel,
      toonTerug: true,
      onTerug: _terug,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: kinderen,
      ),
    );
  }
}
