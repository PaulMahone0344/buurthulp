import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
import '../provider/sessie_providers.dart';
import '../validatie.dart';

/// G6. Vraagt de reset-mail van PocketBase aan. De bevestiging verklapt
/// niet of het adres bestaat.
class WachtwoordVergetenScreen extends ConsumerStatefulWidget {
  const WachtwoordVergetenScreen({super.key});

  @override
  ConsumerState<WachtwoordVergetenScreen> createState() =>
      _WachtwoordVergetenScreenState();
}

class _WachtwoordVergetenScreenState
    extends ConsumerState<WachtwoordVergetenScreen> {
  final _email = TextEditingController();
  String? _emailFout;
  HhMeldSoort? _meldSoort;
  String? _melding;
  bool _isBezig = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _versturen() async {
    final emailFout = valideerEmail(_email.text);
    setState(() {
      _emailFout = emailFout;
      _melding = null;
    });
    if (emailFout != null) return;

    setState(() => _isBezig = true);
    final result = await ref
        .read(sessieControllerProvider.notifier)
        .wachtwoordResetAanvragen(_email.text.trim());
    if (!mounted) return;
    setState(() {
      _isBezig = false;
      switch (result) {
        case Ok<void>():
          _meldSoort = HhMeldSoort.geslaagd;
          _melding = TekstenNl.wachtwoordVergetenVerstuurd;
        case Err<void>(:final fout):
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
      titel: TekstenNl.wachtwoordVergetenTitel,
      onTerug: () => terugOf(context, HhPaden.inloggen),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(TekstenNl.wachtwoordVergetenUitleg, style: tekst.bodyLarge),
          SizedBox(height: tussen),
          HhInvoer(
            label: TekstenNl.veldEmail,
            controller: _email,
            fouttekst: _emailFout,
            isVerplicht: true,
            isActief: !_isBezig,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.email],
            onSubmitted: (_) => _versturen(),
          ),
          if (_melding != null) ...[
            SizedBox(height: tussen),
            HhMeldBalk(soort: _meldSoort!, tekst: _melding!),
          ],
          SizedBox(height: HhRuimte.voor(HhRuimte.xl, dichtheid)),
          HhKnop(
            label: TekstenNl.wachtwoordVergetenKnop,
            icoon: Icons.mail_outline,
            isBezig: _isBezig,
            onPressed: _versturen,
          ),
        ],
      ),
    );
  }
}
