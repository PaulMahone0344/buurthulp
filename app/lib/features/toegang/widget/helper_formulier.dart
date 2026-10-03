import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config.dart';
import '../../../core/result.dart';
import '../../../design/components/hh_invoer.dart';
import '../../../design/components/hh_knop.dart';
import '../../../design/components/hh_meld_balk.dart';
import '../../../design/dichtheid_scope.dart';
import '../../../l10n/teksten_aanmelden_nl.dart';
import '../../../l10n/teksten_nl.dart';
import '../../../theme.dart';
import '../../hulpvrager/provider/hulpvrager_providers.dart' show klokProvider;
import '../../jongere/datum_invoer.dart';
import '../domein/aanmelding.dart';
import '../provider/sessie_providers.dart';
import '../screen/hulp_screen.dart' show urlOpenerProvider;
import '../validatie.dart';
import 'aanmeld_stappen.dart';
import 'aanmeld_velden.dart';

/// Aanmelden als helper, één pagina (stijl mockup H6, stap 1 "Jij"):
/// voornaam, geboortedatum, e-mail, postcode + huisnummer, wachtwoord.
/// Onder de 18 komt er het veld "E-mail of mobiel van je ouder" bij en de
/// stap "Ouder" in het balkje. Onder de 10 kan het niet (ook de server
/// weigert). Geen IBAN: dat komt pas bij de eerste uitbetaling (B7/B8).
class HelperFormulier extends ConsumerStatefulWidget {
  const HelperFormulier({super.key});

  @override
  ConsumerState<HelperFormulier> createState() => _HelperFormulierState();
}

class _HelperFormulierState extends ConsumerState<HelperFormulier> {
  final _voornaam = TextEditingController();
  final _geboortedatum = TextEditingController();
  final _email = TextEditingController();
  final _postcode = TextEditingController();
  final _huisnummer = TextEditingController();
  final _ouder = TextEditingController();
  final _wachtwoord = TextEditingController();
  Map<String, String?> _fouten = const {};
  bool _isAkkoord = false;
  String? _melding;
  bool _isBezig = false;

  @override
  void dispose() {
    for (final c in [
      _voornaam,
      _geboortedatum,
      _email,
      _postcode,
      _huisnummer,
      _ouder,
      _wachtwoord,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  DateTime get _vandaag => ref.read(klokProvider)();

  /// Onder de 18 volgens wat er nu is ingevuld; bij een (nog) ongeldige
  /// datum niet (dan geen ouderveld tot de datum klopt).
  bool get _isMinderjarig {
    final datum = parseDatumNl(_geboortedatum.text);
    return datum != null && isMinderjarig(datum, _vandaag);
  }

  Map<String, String?> _controleer() => {
    'voornaam': _voornaam.text.trim().isEmpty
        ? TekstenAanmeldenNl.validatieVoornaamVerplicht
        : null,
    'geboortedatum': valideerGeboortedatumHelper(_geboortedatum.text, _vandaag),
    'email': valideerEmail(_email.text),
    'postcode': valideerPostcode(_postcode.text),
    'huisnummer': valideerHuisnummer(_huisnummer.text),
    'ouder': _isMinderjarig ? valideerOuderContact(_ouder.text) : null,
    'wachtwoord': valideerWachtwoord(_wachtwoord.text),
    'akkoord': _isAkkoord ? null : TekstenAanmeldenNl.validatieAkkoord,
  };

  Future<void> _aanmelden() async {
    final fouten = _controleer();
    setState(() {
      _fouten = fouten;
      _melding = null;
    });
    if (fouten.values.any((f) => f != null)) return;

    setState(() => _isBezig = true);
    final result = await ref
        .read(sessieControllerProvider.notifier)
        .registreren(
          HelperAanmelding(
            voornaam: _voornaam.text,
            email: _email.text.trim(),
            wachtwoord: _wachtwoord.text,
            geboortedatum: parseDatumNl(_geboortedatum.text)!,
            postcode: _postcode.text,
            huisnummer: _huisnummer.text,
            ouder: _isMinderjarig ? herkenOuderContact(_ouder.text) : null,
          ),
        );
    if (!mounted) return;
    setState(() {
      _isBezig = false;
      _melding = switch (result) {
        Ok<void>() => null,
        Err<void>(:final fout) => fout.melding,
      };
    });
  }

  Future<void> _leesVoorwaarden() async {
    try {
      await ref.read(urlOpenerProvider)(Uri.parse(HhConfig.voorwaardenUrl));
    } on Exception {
      // Geen browser: niets aan te doen; het vinkje blijft werken.
    }
  }

  @override
  Widget build(BuildContext context) {
    final dichtheid = HhDichtheidScope.van(context);
    final tekst = Theme.of(context).textTheme;
    final tussen = HhRuimte.voor(HhRuimte.l, dichtheid);
    final actief = !_isBezig;
    final metOuder = _isMinderjarig;

    return AutofillGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AanmeldStappen(huidig: AanmeldStap.jij, metOuder: metOuder),
          SizedBox(height: tussen),
          Text(TekstenAanmeldenNl.helperUitleg, style: tekst.bodyLarge),
          SizedBox(height: tussen),
          HhInvoer(
            label: TekstenAanmeldenNl.veldVoornaam,
            controller: _voornaam,
            hulptekst: TekstenAanmeldenNl.veldVoornaamHulp,
            fouttekst: _fouten['voornaam'],
            isVerplicht: true,
            isActief: actief,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.givenName],
          ),
          SizedBox(height: tussen),
          HhInvoer(
            label: TekstenAanmeldenNl.veldGeboortedatum,
            controller: _geboortedatum,
            hulptekst: TekstenAanmeldenNl.veldGeboortedatumHulp,
            fouttekst: _fouten['geboortedatum'],
            isVerplicht: true,
            isActief: actief,
            keyboardType: TextInputType.datetime,
            textInputAction: TextInputAction.next,
            // Het ouderveld verschijnt zodra de datum onder de 18 is.
            onChanged: (_) => setState(() {}),
          ),
          SizedBox(height: tussen),
          HhInvoer(
            label: TekstenNl.veldEmail,
            controller: _email,
            hulptekst: TekstenNl.veldEmailHulp,
            fouttekst: _fouten['email'],
            isVerplicht: true,
            isActief: actief,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.email],
          ),
          SizedBox(height: tussen),
          NaastElkaar(
            linksFlex: 1,
            rechtsFlex: 1,
            links: HhInvoer(
              label: TekstenAanmeldenNl.veldPostcode,
              controller: _postcode,
              hulptekst: TekstenAanmeldenNl.veldPostcodeHulp,
              fouttekst: _fouten['postcode'],
              isVerplicht: true,
              isActief: actief,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.postalCode],
            ),
            rechts: HhInvoer(
              label: TekstenAanmeldenNl.veldHuisnummer,
              controller: _huisnummer,
              fouttekst: _fouten['huisnummer'],
              isVerplicht: true,
              isActief: actief,
              textInputAction: TextInputAction.next,
            ),
          ),
          SizedBox(height: HhRuimte.voor(HhRuimte.s, dichtheid)),
          Text(TekstenAanmeldenNl.postcodeUitleg, style: tekst.bodyMedium),
          if (metOuder) ...[
            SizedBox(height: tussen),
            HhInvoer(
              label: TekstenAanmeldenNl.veldOuder,
              controller: _ouder,
              hulptekst: TekstenAanmeldenNl.veldOuderHulp,
              fouttekst: _fouten['ouder'],
              isVerplicht: true,
              isActief: actief,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
            ),
          ],
          SizedBox(height: tussen),
          WachtwoordVeld(
            controller: _wachtwoord,
            isActief: actief,
            fouttekst: _fouten['wachtwoord'],
          ),
          SizedBox(height: tussen),
          AkkoordVinkje(
            isAkkoord: _isAkkoord,
            fouttekst: _fouten['akkoord'],
            onGewijzigd: actief ? (w) => setState(() => _isAkkoord = w) : null,
            onLees: _leesVoorwaarden,
          ),
          if (_melding != null) ...[
            SizedBox(height: tussen),
            HhMeldBalk(soort: HhMeldSoort.fout, tekst: _melding!),
          ],
          SizedBox(height: HhRuimte.voor(HhRuimte.xl, dichtheid)),
          HhKnop(
            label: TekstenNl.registrerenKnop,
            isBezig: _isBezig,
            onPressed: _aanmelden,
          ),
        ],
      ),
    );
  }
}
