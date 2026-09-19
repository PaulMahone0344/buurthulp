import 'package:flutter/material.dart';

import '../../../../design/components/hh_invoer.dart';
import '../../../../design/components/hh_knop.dart';
import '../../../../design/dichtheid_scope.dart';
import '../../../../l10n/teksten_nl.dart';
import '../../../../l10n/teksten_uitvoeren_nl.dart';
import '../../../../theme.dart';
import '../domein/klus_overgang.dart';

/// Vraagt de jongere waarom het niet lukt. Geeft de reden terug, of null
/// als hij toch doorgaat. De reden is verplicht (5 tot 300 tekens, gelijk
/// aan de hook) en wordt hier al gecontroleerd, zodat er geen verzoek
/// vertrekt dat de server toch weigert.
Future<String?> vraagAnnuleerReden(BuildContext context) {
  return showDialog<String>(
    context: context,
    builder: (context) => const _RedenDialoog(),
  );
}

class _RedenDialoog extends StatefulWidget {
  const _RedenDialoog();

  @override
  State<_RedenDialoog> createState() => _RedenDialoogState();
}

class _RedenDialoogState extends State<_RedenDialoog> {
  final _veld = TextEditingController();
  String? _fout;

  @override
  void dispose() {
    _veld.dispose();
    super.dispose();
  }

  void _bevestig() {
    final reden = _veld.text.trim();
    if (reden.length < redenMinLengte) {
      setState(
        () => _fout = TekstenUitvoerenNl.annuleerRedenTeKort(redenMinLengte),
      );
      return;
    }
    if (reden.length > redenMaxLengte) {
      setState(
        () => _fout = TekstenUitvoerenNl.annuleerRedenTeLang(redenMaxLengte),
      );
      return;
    }
    Navigator.of(context).pop(reden);
  }

  @override
  Widget build(BuildContext context) {
    final dichtheid = HhDichtheidScope.van(context);
    final tekst = Theme.of(context).textTheme;
    final tussen = HhRuimte.voor(HhRuimte.l, dichtheid);

    return AlertDialog(
      title: Text(
        TekstenUitvoerenNl.annuleerTitelJongere,
        style: tekst.titleLarge,
      ),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            TekstenUitvoerenNl.annuleerUitlegJongere,
            style: tekst.bodyLarge,
          ),
          SizedBox(height: tussen),
          HhInvoer(
            label: TekstenUitvoerenNl.annuleerLabelReden,
            controller: _veld,
            hulptekst: TekstenUitvoerenNl.annuleerHintReden,
            fouttekst: _fout,
            isVerplicht: true,
            maxRegels: 3,
            onChanged: (_) {
              if (_fout != null) setState(() => _fout = null);
            },
          ),
        ],
      ),
      actionsAlignment: MainAxisAlignment.start,
      actions: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            HhKnop(
              label: TekstenUitvoerenNl.annuleerAfbreken,
              onPressed: () => Navigator.of(context).pop(),
            ),
            SizedBox(height: HhRuimte.voor(HhRuimte.s, dichtheid)),
            HhKnop(
              label: TekstenUitvoerenNl.annuleerBevestigJongere,
              soort: HhKnopSoort.gevaar,
              semantiekLabel: TekstenUitvoerenNl.annuleerBevestigJongere,
              onPressed: _bevestig,
            ),
          ],
        ),
      ],
    );
  }
}

/// De bevestigingsvraag bij "Klus aannemen" (M5 OPEN-PUNT 80). Twee knoppen;
/// de veilige keuze staat bovenaan. Geeft true als de jongere doorzet.
Future<bool> vraagAannemenBevestiging(
  BuildContext context, {
  required String vraag,
  required String uitleg,
  required String jaLabel,
}) async {
  final ja = await showDialog<bool>(
    context: context,
    builder: (context) {
      final dichtheid = HhDichtheidScope.van(context);
      final tekst = Theme.of(context).textTheme;
      return AlertDialog(
        title: Text(vraag, style: tekst.titleLarge),
        content: Text(uitleg, style: tekst.bodyLarge),
        actionsAlignment: MainAxisAlignment.start,
        actions: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              HhKnop(
                label: jaLabel,
                onPressed: () => Navigator.of(context).pop(true),
              ),
              SizedBox(height: HhRuimte.voor(HhRuimte.s, dichtheid)),
              HhKnop(
                label: TekstenNl.annuleren,
                soort: HhKnopSoort.tekst,
                onPressed: () => Navigator.of(context).pop(false),
              ),
            ],
          ),
        ],
      );
    },
  );
  return ja ?? false;
}
