import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/result.dart';
import '../../../design/components/hh_knop.dart';
import '../../../design/components/hh_meld_balk.dart';
import '../../../design/components/hh_scherm.dart';
import '../../../design/dichtheid_scope.dart';
import '../../../l10n/teksten_nl.dart';
import '../../../theme.dart';
import '../provider/sessie_providers.dart';

/// G5. Geen sms in de pilot; de bevestiging loopt via de ingebouwde
/// PocketBase-verificatiemail. De gebruiker is al ingelogd en mag verder;
/// de mail kan opnieuw worden gestuurd.
class BevestigEmailScreen extends ConsumerStatefulWidget {
  const BevestigEmailScreen({super.key});

  @override
  ConsumerState<BevestigEmailScreen> createState() =>
      _BevestigEmailScreenState();
}

class _BevestigEmailScreenState extends ConsumerState<BevestigEmailScreen> {
  bool _isBezig = false;
  HhMeldSoort? _meldSoort;
  String? _melding;

  Future<void> _opnieuwSturen(String email) async {
    setState(() {
      _isBezig = true;
      _melding = null;
    });
    final result = await ref
        .read(sessieControllerProvider.notifier)
        .verificatieAanvragen(email);
    if (!mounted) return;
    setState(() {
      _isBezig = false;
      switch (result) {
        case Ok<void>():
          _meldSoort = HhMeldSoort.geslaagd;
          _melding = TekstenNl.bevestigEmailVerstuurd;
        case Err<void>(:final fout):
          _meldSoort = HhMeldSoort.fout;
          _melding = fout.melding;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final gebruiker = ref.watch(huidigeGebruikerProvider);
    final dichtheid = HhDichtheidScope.van(context);
    final tekst = Theme.of(context).textTheme;
    final tussen = HhRuimte.voor(HhRuimte.l, dichtheid);

    // Zonder sessie stuurt de router-guard al weg; dit is alleen het
    // ene frame ertussen.
    if (gebruiker == null) return const Scaffold();

    return HhScherm(
      titel: TekstenNl.bevestigEmailTitel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            TekstenNl.bevestigEmailUitleg(gebruiker.email),
            style: tekst.bodyLarge,
          ),
          if (_melding != null) ...[
            SizedBox(height: tussen),
            HhMeldBalk(soort: _meldSoort!, tekst: _melding!),
          ],
          SizedBox(height: HhRuimte.voor(HhRuimte.xl, dichtheid)),
          HhKnop(
            label: TekstenNl.verder,
            icoon: Icons.arrow_forward,
            onPressed: _isBezig ? null : () => context.go(gebruiker.rol.pad),
          ),
          SizedBox(height: HhRuimte.voor(HhRuimte.s, dichtheid)),
          HhKnop(
            label: TekstenNl.bevestigEmailOpnieuw,
            soort: HhKnopSoort.tweedeKeus,
            isBezig: _isBezig,
            onPressed: () => _opnieuwSturen(gebruiker.email),
          ),
        ],
      ),
    );
  }
}
