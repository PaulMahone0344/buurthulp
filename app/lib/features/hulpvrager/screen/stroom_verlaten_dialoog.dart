import 'package:flutter/material.dart';

import '../../../design/components/hh_knop.dart';
import '../../../design/dichtheid_scope.dart';
import '../../../l10n/teksten_hulpvrager_nl.dart';
import '../../../theme.dart';

/// "Weet u het zeker?" bij het verlaten van de hulpvraag-stroom. Twee
/// knoppen, de veilige keuze (verder gaan) als eerste. Geeft true als de
/// oudere echt wil stoppen.
Future<bool> vraagStroomVerlaten(BuildContext context) async {
  final stoppen = await showDialog<bool>(
    context: context,
    builder: (context) => const _VerlatenDialoog(),
  );
  return stoppen ?? false;
}

class _VerlatenDialoog extends StatelessWidget {
  const _VerlatenDialoog();

  @override
  Widget build(BuildContext context) {
    final dichtheid = HhDichtheidScope.van(context);
    final tekst = Theme.of(context).textTheme;

    return AlertDialog(
      title: Text(TekstenHulpvragerNl.verlatenVraag, style: tekst.titleLarge),
      content: Text(TekstenHulpvragerNl.verlatenUitleg, style: tekst.bodyLarge),
      actionsAlignment: MainAxisAlignment.start,
      actions: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            HhKnop(
              label: TekstenHulpvragerNl.verlatenNee,
              onPressed: () => Navigator.of(context).pop(false),
            ),
            SizedBox(height: HhRuimte.voor(HhRuimte.s, dichtheid)),
            HhKnop(
              label: TekstenHulpvragerNl.verlatenJa,
              soort: HhKnopSoort.gevaar,
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        ),
      ],
    );
  }
}
