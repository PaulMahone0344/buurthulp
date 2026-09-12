import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/navigatie.dart';
import '../../../app/paden.dart';
import '../../../core/result.dart';
import '../../../design/components/hh_invoer.dart';
import '../../../design/components/hh_knop.dart';
import '../../../design/components/hh_meld_balk.dart';
import '../../../design/components/hh_scherm.dart';
import '../../../design/dichtheid_scope.dart';
import '../../../l10n/teksten_nl.dart';
import '../../../theme.dart';
import '../model/sessie_state.dart';
import '../provider/sessie_providers.dart';
import '../validatie.dart';

/// G3. E-mail en wachtwoord voor alle vier rollen. Na een verlopen sessie
/// (401) komt de gebruiker hier met een melding. Bij geen verbinding
/// blijft de knop bruikbaar om het opnieuw te proberen.
class InloggenScreen extends ConsumerStatefulWidget {
  const InloggenScreen({super.key});

  @override
  ConsumerState<InloggenScreen> createState() => _InloggenScreenState();
}

class _InloggenScreenState extends ConsumerState<InloggenScreen> {
  final _email = TextEditingController();
  final _wachtwoord = TextEditingController();
  String? _emailFout;
  String? _wachtwoordFout;
  String? _melding;
  bool _isBezig = false;

  @override
  void dispose() {
    _email.dispose();
    _wachtwoord.dispose();
    super.dispose();
  }

  Future<void> _inloggen() async {
    final emailFout = valideerEmail(_email.text);
    final wachtwoordFout = _wachtwoord.text.isEmpty
        ? TekstenNl.validatieWachtwoordTeKort
        : null;
    setState(() {
      _emailFout = emailFout;
      _wachtwoordFout = wachtwoordFout;
      _melding = null;
    });
    if (emailFout != null || wachtwoordFout != null) return;

    setState(() => _isBezig = true);
    final result = await ref
        .read(sessieControllerProvider.notifier)
        .inloggen(email: _email.text.trim(), wachtwoord: _wachtwoord.text);
    if (!mounted) return;
    setState(() {
      _isBezig = false;
      _melding = switch (result) {
        Ok<void>() => null,
        Err<void>(:final fout) => fout.melding,
      };
    });
    // Geslaagd: de router-guard stuurt zelf door naar de rolroute.
  }

  @override
  Widget build(BuildContext context) {
    final dichtheid = HhDichtheidScope.van(context);
    final tussen = HhRuimte.voor(HhRuimte.l, dichtheid);
    final sessie = ref.watch(sessieControllerProvider);
    final isVerlopen = switch (sessie) {
      SessieUitgelogd(:final reden) => reden == UitlogReden.sessieVerlopen,
      _ => false,
    };

    return HhScherm(
      titel: TekstenNl.inloggenTitel,
      onTerug: () => terugOf(context, HhPaden.welkom),
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (isVerlopen) ...[
              const HhMeldBalk(
                soort: HhMeldSoort.waarschuwing,
                tekst: TekstenNl.foutSessieVerlopen,
              ),
              SizedBox(height: tussen),
            ],
            HhInvoer(
              label: TekstenNl.veldEmail,
              controller: _email,
              fouttekst: _emailFout,
              isVerplicht: true,
              isActief: !_isBezig,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
            ),
            SizedBox(height: tussen),
            HhInvoer(
              label: TekstenNl.veldWachtwoord,
              controller: _wachtwoord,
              fouttekst: _wachtwoordFout,
              isVerplicht: true,
              isActief: !_isBezig,
              obscureText: true,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.password],
              onSubmitted: (_) => _inloggen(),
            ),
            if (_melding != null) ...[
              SizedBox(height: tussen),
              HhMeldBalk(soort: HhMeldSoort.fout, tekst: _melding!),
            ],
            SizedBox(height: HhRuimte.voor(HhRuimte.xl, dichtheid)),
            HhKnop(
              label: TekstenNl.inloggenKnop,
              isBezig: _isBezig,
              onPressed: _inloggen,
            ),
            SizedBox(height: HhRuimte.voor(HhRuimte.s, dichtheid)),
            HhKnop(
              label: TekstenNl.wachtwoordVergetenLink,
              soort: HhKnopSoort.tekst,
              onPressed: _isBezig
                  ? null
                  : () => context.push(HhPaden.wachtwoordVergeten),
            ),
            HhKnop(
              label: TekstenNl.hulpNodig,
              soort: HhKnopSoort.tekst,
              onPressed: _isBezig ? null : () => context.push(HhPaden.hulp),
            ),
          ],
        ),
      ),
    );
  }
}
