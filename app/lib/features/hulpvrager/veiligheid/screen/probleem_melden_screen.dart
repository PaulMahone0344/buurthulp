import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/navigatie.dart';
import '../../../../core/pb/incident_gateway.dart';
import '../../../../core/result.dart';
import '../../../../design/components/hh_invoer.dart';
import '../../../../design/components/hh_knop.dart';
import '../../../../design/components/hh_meld_balk.dart';
import '../../../../design/components/hh_scherm.dart';
import '../../../../design/dichtheid_scope.dart';
import '../../../../l10n/teksten_meldingen_nl.dart';
import '../../../../l10n/teksten_nl.dart';
import '../../../../theme.dart';
import '../../../toegang/model/hh_rol.dart';
import '../../../toegang/provider/sessie_providers.dart';
import '../meldkamer_config.dart';
import '../provider/veiligheid_providers.dart';

/// De stappen van O11. Elke stap heeft hooguit drie grote keuzes.
enum O11Stap { keuze, noodBevestig, noodVerstuurd, probleem, anders, verstuurd }

/// Hooguit zoveel tekens bij "iets anders".
const _andersMin = 3;
const _andersMax = 500;

/// O11. Probleem melden en noodknop, voor de oudere (en via J15 voor de
/// jongere):
///   - "Ik heb nu hulp nodig" -> bevestigvraag -> incident soort nood ->
///     "We bellen u zo snel mogelijk" + knop Bel ons.
///   - "Er is iets niet goed gegaan" -> drie vaste keuzes (of "Iets
///     anders", zelf typen) -> incident soort probleem, met de lopende klus
///     erbij als die er is.
/// De server (hook) meldt het meteen aan elke coordinator; bij nood ook aan
/// het gekoppelde familielid.
class ProbleemMeldenScreen extends ConsumerStatefulWidget {
  const ProbleemMeldenScreen({this.klusId = '', super.key});

  /// Meegegeven vanaf J15; leeg vanaf O10 (dan zoekt het scherm de klus die
  /// bij de oudere nu loopt).
  final String klusId;

  @override
  ConsumerState<ProbleemMeldenScreen> createState() =>
      _ProbleemMeldenScreenState();
}

class _ProbleemMeldenScreenState extends ConsumerState<ProbleemMeldenScreen> {
  final _anders = TextEditingController();
  O11Stap _stap = O11Stap.keuze;
  bool _isBezig = false;
  String? _melding;
  String? _andersFout;
  String? _belMelding;

  @override
  void dispose() {
    _anders.dispose();
    super.dispose();
  }

  String get _klusId {
    if (widget.klusId.isNotEmpty) return widget.klusId;
    return ref.read(lopendeKlusProvider).value ?? '';
  }

  void _naar(O11Stap stap) => setState(() {
    _stap = stap;
    _melding = null;
  });

  Future<void> _meld(
    IncidentSoort soort,
    String omschrijving,
    O11Stap daarna,
  ) async {
    final gebruiker = ref.read(huidigeGebruikerProvider);
    if (gebruiker == null) return;
    setState(() {
      _isBezig = true;
      _melding = null;
    });
    final result = await ref
        .read(incidentGatewayProvider)
        .meld(
          melderId: gebruiker.id,
          soort: soort,
          klusId: _klusId,
          omschrijving: omschrijving,
        );
    if (!mounted) return;
    setState(() {
      _isBezig = false;
      switch (result) {
        case Ok<String>():
          _stap = daarna;
        case Err<String>():
          _melding = TekstenMeldingenNl.o11Mislukt;
      }
    });
  }

  Future<void> _verstuurAnders() async {
    final tekst = _anders.text.trim();
    final fout = tekst.length < _andersMin
        ? TekstenMeldingenNl.o11AndersTeKort
        : tekst.length > _andersMax
        ? TekstenMeldingenNl.o11AndersTeLang
        : null;
    setState(() => _andersFout = fout);
    if (fout != null) return;
    await _meld(IncidentSoort.probleem, tekst, O11Stap.verstuurd);
  }

  Future<void> _bel() async {
    setState(() => _belMelding = null);
    final gelukt = await ref.read(belMeldkamerProvider)();
    if (!mounted || gelukt) return;
    setState(
      () =>
          _belMelding = TekstenNl.hulpBellenLuktNiet(MeldkamerConfig.telefoon),
    );
  }

  void _terug(HhRol rol) {
    switch (_stap) {
      case O11Stap.noodBevestig:
      case O11Stap.probleem:
        _naar(O11Stap.keuze);
      case O11Stap.anders:
        _naar(O11Stap.probleem);
      case O11Stap.keuze:
      case O11Stap.noodVerstuurd:
      case O11Stap.verstuurd:
        terugOf(context, rol.pad);
    }
  }

  @override
  Widget build(BuildContext context) {
    final gebruiker = ref.watch(huidigeGebruikerProvider);
    final rol = gebruiker?.rol ?? HhRol.hulpvrager;
    final isOudere = rol == HhRol.hulpvrager;
    // Alvast laden, zodat de klus klaarstaat als er gemeld wordt.
    final heeftKlus =
        widget.klusId.isNotEmpty ||
        (ref.watch(lopendeKlusProvider).value ?? '').isNotEmpty;

    final dichtheid = HhDichtheidScope.van(context);
    final tekst = Theme.of(context).textTheme;
    final tussen = HhRuimte.voor(HhRuimte.l, dichtheid);
    final groot = HhRuimte.voor(HhRuimte.xl, dichtheid);

    Widget vraag(String zin) => Text(zin, style: tekst.headlineMedium);

    final List<Widget> kinderen = switch (_stap) {
      O11Stap.keuze => [
        vraag(TekstenMeldingenNl.o11Vraag),
        SizedBox(height: groot),
        HhKnop(
          label: TekstenMeldingenNl.o11Nood,
          semantiekLabel: TekstenMeldingenNl.o11NoodSemantiek,
          icoon: Icons.sos_outlined,
          soort: HhKnopSoort.gevaar,
          maat: HhDichtheid.groot,
          onPressed: () => _naar(O11Stap.noodBevestig),
        ),
        SizedBox(height: tussen),
        HhKnop(
          label: TekstenMeldingenNl.o11Probleem,
          icoon: Icons.report_problem_outlined,
          soort: HhKnopSoort.tweedeKeus,
          maat: HhDichtheid.groot,
          onPressed: () => _naar(O11Stap.probleem),
        ),
      ],
      O11Stap.noodBevestig => [
        vraag(
          isOudere
              ? TekstenMeldingenNl.o11NoodVraagU
              : TekstenMeldingenNl.o11NoodVraagJe,
        ),
        SizedBox(height: groot),
        HhKnop(
          label: TekstenMeldingenNl.o11NoodJa,
          icoon: Icons.phone_in_talk_outlined,
          soort: HhKnopSoort.gevaar,
          maat: HhDichtheid.groot,
          isBezig: _isBezig,
          onPressed: () => _meld(IncidentSoort.nood, '', O11Stap.noodVerstuurd),
        ),
        SizedBox(height: tussen),
        HhKnop(
          label: TekstenMeldingenNl.o11NoodNee,
          soort: HhKnopSoort.tweedeKeus,
          maat: HhDichtheid.groot,
          onPressed: _isBezig ? null : () => _naar(O11Stap.keuze),
        ),
      ],
      O11Stap.noodVerstuurd => [
        vraag(
          isOudere
              ? TekstenMeldingenNl.o11NoodVerstuurdU
              : TekstenMeldingenNl.o11NoodVerstuurdJe,
        ),
        SizedBox(height: HhRuimte.voor(HhRuimte.s, dichtheid)),
        Text(
          isOudere
              ? TekstenMeldingenNl.o11NoodVerstuurdUitleg
              : TekstenMeldingenNl.o11NoodVerstuurdUitlegJe,
          style: tekst.bodyLarge,
        ),
        if (_belMelding != null) ...[
          SizedBox(height: tussen),
          HhMeldBalk(soort: HhMeldSoort.waarschuwing, tekst: _belMelding!),
        ],
        SizedBox(height: groot),
        HhKnop(
          label: TekstenMeldingenNl.o10Titel,
          semantiekLabel: TekstenMeldingenNl.o10BellenSemantiek(
            MeldkamerConfig.telefoon,
          ),
          icoon: Icons.phone_outlined,
          maat: HhDichtheid.groot,
          onPressed: _bel,
        ),
        SizedBox(height: tussen),
        HhKnop(
          label: TekstenMeldingenNl.o11Klaar,
          soort: HhKnopSoort.tweedeKeus,
          maat: HhDichtheid.groot,
          onPressed: () => context.go(rol.pad),
        ),
      ],
      O11Stap.probleem => [
        vraag(TekstenMeldingenNl.o11ProbleemVraag),
        if (heeftKlus) ...[
          SizedBox(height: HhRuimte.voor(HhRuimte.s, dichtheid)),
          Text(TekstenMeldingenNl.o11MetKlus, style: tekst.bodyLarge),
        ],
        SizedBox(height: groot),
        for (final keuze in const [
          TekstenMeldingenNl.o11KeuzeNietGekomen,
          TekstenMeldingenNl.o11KeuzeKapot,
          TekstenMeldingenNl.o11KeuzeNietPrettig,
        ]) ...[
          HhKnop(
            label: keuze,
            soort: HhKnopSoort.tweedeKeus,
            maat: HhDichtheid.groot,
            onPressed: _isBezig
                ? null
                : () => _meld(IncidentSoort.probleem, keuze, O11Stap.verstuurd),
          ),
          SizedBox(height: tussen),
        ],
        // "Iets anders" is een kleine tekstknop naast de drie grote keuzes,
        // zoals de "Anders"-reden bij annuleren (M6).
        HhKnop(
          label: TekstenMeldingenNl.o11KeuzeAnders,
          icoon: Icons.edit_outlined,
          soort: HhKnopSoort.tekst,
          onPressed: _isBezig ? null : () => _naar(O11Stap.anders),
        ),
      ],
      O11Stap.anders => [
        HhInvoer(
          label: TekstenMeldingenNl.o11AndersLabel,
          hulptekst: TekstenMeldingenNl.o11AndersHulp,
          fouttekst: _andersFout,
          controller: _anders,
          isActief: !_isBezig,
          maxRegels: 4,
        ),
        SizedBox(height: groot),
        HhKnop(
          label: TekstenMeldingenNl.o11Versturen,
          icoon: Icons.send_outlined,
          maat: HhDichtheid.groot,
          isBezig: _isBezig,
          onPressed: _verstuurAnders,
        ),
      ],
      O11Stap.verstuurd => [
        Icon(
          Icons.check_circle_outline,
          size: HhMaten.avatar(dichtheid),
          color: Theme.of(context).colorScheme.primary,
        ),
        SizedBox(height: tussen),
        vraag(
          isOudere
              ? TekstenMeldingenNl.o11ProbleemVerstuurdU
              : TekstenMeldingenNl.o11ProbleemVerstuurdJe,
        ),
        SizedBox(height: groot),
        HhKnop(
          label: TekstenMeldingenNl.o11Klaar,
          maat: HhDichtheid.groot,
          onPressed: () => context.go(rol.pad),
        ),
      ],
    };

    return HhScherm(
      titel: TekstenMeldingenNl.o11Titel,
      toonTerug: true,
      onTerug: () => _terug(rol),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_melding != null) ...[
            HhMeldBalk(soort: HhMeldSoort.fout, tekst: _melding!),
            SizedBox(height: tussen),
          ],
          ...kinderen,
        ],
      ),
    );
  }
}
