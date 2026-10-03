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
import '../domein/aanmelding.dart';
import '../provider/sessie_providers.dart';
import '../screen/hulp_screen.dart' show urlOpenerProvider;
import '../validatie.dart';
import 'aanmeld_velden.dart';

/// Aanmelden als bewoner, één pagina (mockup AAanmeldenBewoner): naam,
/// e-mail, straat + huisnummer, postcode + plaats, wachtwoord, vinkje
/// voorwaarden. Geen telefoon: de chat loopt in de app.
class BewonerFormulier extends ConsumerStatefulWidget {
  const BewonerFormulier({super.key});

  @override
  ConsumerState<BewonerFormulier> createState() => _BewonerFormulierState();
}

class _BewonerFormulierState extends ConsumerState<BewonerFormulier> {
  final _naam = TextEditingController();
  final _email = TextEditingController();
  final _straat = TextEditingController();
  final _huisnummer = TextEditingController();
  final _postcode = TextEditingController();
  final _plaats = TextEditingController();
  final _wachtwoord = TextEditingController();
  Map<String, String?> _fouten = const {};
  bool _isAkkoord = false;
  String? _melding;
  bool _isBezig = false;

  @override
  void dispose() {
    for (final c in [
      _naam,
      _email,
      _straat,
      _huisnummer,
      _postcode,
      _plaats,
      _wachtwoord,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Map<String, String?> _controleer() => {
    'naam': valideerNaam(_naam.text),
    'email': valideerEmail(_email.text),
    'straat': valideerStraat(_straat.text),
    'huisnummer': valideerHuisnummer(_huisnummer.text),
    'postcode': valideerPostcode(_postcode.text),
    'plaats': valideerPlaats(_plaats.text),
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
          BewonerAanmelding(
            naam: _naam.text.trim(),
            email: _email.text.trim(),
            wachtwoord: _wachtwoord.text,
            straat: _straat.text,
            huisnummer: _huisnummer.text,
            postcode: _postcode.text,
            plaats: _plaats.text,
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

    return AutofillGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(TekstenAanmeldenNl.bewonerUitleg, style: tekst.bodyLarge),
          SizedBox(height: tussen),
          HhInvoer(
            label: TekstenAanmeldenNl.veldNaam,
            controller: _naam,
            fouttekst: _fouten['naam'],
            isVerplicht: true,
            isActief: actief,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.name],
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
            links: HhInvoer(
              label: TekstenAanmeldenNl.veldStraat,
              controller: _straat,
              fouttekst: _fouten['straat'],
              isVerplicht: true,
              isActief: actief,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.streetAddressLine1],
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
          SizedBox(height: tussen),
          NaastElkaar(
            linksFlex: 1,
            rechtsFlex: 1,
            links: HhInvoer(
              label: TekstenAanmeldenNl.veldPostcode,
              controller: _postcode,
              fouttekst: _fouten['postcode'],
              isVerplicht: true,
              isActief: actief,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.postalCode],
            ),
            rechts: HhInvoer(
              label: TekstenAanmeldenNl.veldPlaats,
              controller: _plaats,
              fouttekst: _fouten['plaats'],
              isVerplicht: true,
              isActief: actief,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.addressCity],
            ),
          ),
          SizedBox(height: tussen),
          WachtwoordVeld(
            controller: _wachtwoord,
            isActief: actief,
            fouttekst: _fouten['wachtwoord'],
          ),
          SizedBox(height: tussen),
          const HhMeldBalk(
            soort: HhMeldSoort.informatie,
            tekst: TekstenAanmeldenNl.adresUitleg,
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
