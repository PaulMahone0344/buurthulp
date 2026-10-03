import 'package:flutter/material.dart';

import '../../../design/components/hh_knop.dart';
import '../../../design/dichtheid_scope.dart';
import '../../../l10n/teksten_chat_nl.dart';
import '../../../theme.dart';

/// "Gesprek verwijderen?" (integratie, antwoorden Ibrahim 4 okt). Twee
/// knoppen, de veilige keuze (niet verwijderen) als eerste. Geeft true als
/// het gesprek echt weg moet (alleen voor mij; [naam] houdt zijn kopie).
Future<bool> vraagGesprekVerwijderen(BuildContext context, String naam) async {
  final weg = await showDialog<bool>(
    context: context,
    builder: (context) => _VerwijderDialoog(naam: naam),
  );
  return weg ?? false;
}

class _VerwijderDialoog extends StatelessWidget {
  const _VerwijderDialoog({required this.naam});

  final String naam;

  @override
  Widget build(BuildContext context) {
    final dichtheid = HhDichtheidScope.van(context);
    final tekst = Theme.of(context).textTheme;

    return AlertDialog(
      title: Text(TekstenChatNl.verwijderVraag, style: tekst.titleLarge),
      content: Text(
        TekstenChatNl.verwijderUitleg(naam),
        style: tekst.bodyLarge,
      ),
      actionsAlignment: MainAxisAlignment.start,
      actions: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            HhKnop(
              label: TekstenChatNl.verwijderNee,
              onPressed: () => Navigator.of(context).pop(false),
            ),
            SizedBox(height: HhRuimte.voor(HhRuimte.s, dichtheid)),
            HhKnop(
              label: TekstenChatNl.verwijderJa,
              soort: HhKnopSoort.gevaar,
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        ),
      ],
    );
  }
}
