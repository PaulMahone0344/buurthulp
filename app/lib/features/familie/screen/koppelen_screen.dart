import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/navigatie.dart';
import '../../../core/pb/familie_gateway.dart';
import '../../../design/components/hh_invoer.dart';
import '../../../design/components/hh_knop.dart';
import '../../../design/components/hh_meld_balk.dart';
import '../../../design/components/hh_scherm.dart';
import '../../../design/dichtheid_scope.dart';
import '../../../l10n/teksten_familie_nl.dart';
import '../../../theme.dart';
import '../paden_familie.dart';
import '../provider/familie_providers.dart';

/// Aanvragen: het familielid vult het e-mailadres van de oudere in. Het
/// antwoord is altijd hetzelfde vaste bericht (de server verklapt niet of
/// het adres bestaat).
class KoppelenScreen extends ConsumerStatefulWidget {
  const KoppelenScreen({super.key});

  @override
  ConsumerState<KoppelenScreen> createState() => _KoppelenScreenState();
}

class _KoppelenScreenState extends ConsumerState<KoppelenScreen> {
  final _email = TextEditingController();
  bool _isBezig = false;
  bool _isVerstuurd = false;
  String? _melding;
  HhMeldSoort _meldSoort = HhMeldSoort.informatie;
  String? _emailFout;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  static final _vorm = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  Future<void> _verstuur() async {
    final email = _email.text.trim();
    if (!_vorm.hasMatch(email)) {
      setState(() => _emailFout = TekstenFamilieNl.aanvraagEmailFout);
      return;
    }
    setState(() {
      _emailFout = null;
      _melding = null;
      _isBezig = true;
    });
    final uitkomst = await ref.read(aanvragenProvider)(email);
    if (!mounted) return;
    setState(() {
      _isBezig = false;
      switch (uitkomst) {
        case AanvraagVerstuurd(:final melding):
          _isVerstuurd = true;
          _meldSoort = HhMeldSoort.geslaagd;
          _melding = melding.isEmpty
              ? TekstenFamilieNl.aanvraagVastBericht
              : melding;
        case AanvraagGeweigerd(:final reden, :final melding):
          _meldSoort = HhMeldSoort.waarschuwing;
          switch (reden) {
            case AanvraagReden.email:
              _emailFout = TekstenFamilieNl.aanvraagEmailFout;
              _melding = null;
            case AanvraagReden.limiet:
              _melding = melding ?? TekstenFamilieNl.aanvraagLimiet;
            case AanvraagReden.rol:
              _melding = melding ?? TekstenFamilieNl.aanvraagGeenFamilie;
          }
        case AanvraagFout(:final fout):
          _meldSoort = HhMeldSoort.fout;
          _melding = fout.melding;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final dichtheid = HhDichtheidScope.van(context);
    final tekst = Theme.of(context).textTheme;
    final tussen = HhRuimte.voor(HhRuimte.l, dichtheid);

    return HhScherm(
      titel: TekstenFamilieNl.aanvraagTitel,
      onTerug: () => terugOf(context, HhPadenFamilie.lijst),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_melding != null) ...[
            HhMeldBalk(soort: _meldSoort, tekst: _melding!),
            SizedBox(height: tussen),
          ],
          if (_isVerstuurd)
            HhKnop(
              label: TekstenFamilieNl.aanvraagTerug,
              icoon: Icons.arrow_back,
              onPressed: () => context.go(HhPadenFamilie.lijst),
            )
          else ...[
            Text(TekstenFamilieNl.aanvraagUitleg, style: tekst.bodyLarge),
            SizedBox(height: tussen),
            HhInvoer(
              label: TekstenFamilieNl.aanvraagEmailLabel,
              controller: _email,
              fouttekst: _emailFout,
              isActief: !_isBezig,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              onSubmitted: (_) => _verstuur(),
            ),
            SizedBox(height: HhRuimte.voor(HhRuimte.xl, dichtheid)),
            HhKnop(
              label: TekstenFamilieNl.aanvraagVersturen,
              icoon: Icons.send_outlined,
              isBezig: _isBezig,
              onPressed: _verstuur,
            ),
          ],
        ],
      ),
    );
  }
}
