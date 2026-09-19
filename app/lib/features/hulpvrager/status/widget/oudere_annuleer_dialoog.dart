import 'package:flutter/material.dart';

import '../../../../design/components/hh_invoer.dart';
import '../../../../design/components/hh_knop.dart';
import '../../../../design/dichtheid_scope.dart';
import '../../../../l10n/teksten_uitvoeren_nl.dart';
import '../../../../theme.dart';
import '../../../jongere/uitvoeren/domein/klus_overgang.dart';

/// Vraagt de oudere of de hulp echt mag stoppen, en waarom. Drie vaste
/// redenen als grote knoppen, zodat er niet getypt hoeft te worden; wie iets
/// anders wil, krijgt alsnog een veld. Geeft de reden terug, of null als de
/// hulpvraag blijft staan.
///
/// De reden gaat als hele zin naar de server (die minstens vijf tekens
/// eist). Eén dialoog met vier keuzes onder elkaar; de ouderenregel
/// "maximaal drie keuzes" houden we aan per rij, zoals M4 (OPEN-PUNT 45).
Future<String?> vraagOudereAnnuleerReden(BuildContext context) {
  return showDialog<String>(
    context: context,
    builder: (context) => const _OudereRedenDialoog(),
  );
}

class _OudereRedenDialoog extends StatefulWidget {
  const _OudereRedenDialoog();

  @override
  State<_OudereRedenDialoog> createState() => _OudereRedenDialoogState();
}

class _OudereRedenDialoogState extends State<_OudereRedenDialoog> {
  final _veld = TextEditingController();
  bool _typtZelf = false;
  String? _fout;

  static const vasteRedenen = <(String, String, IconData)>[
    (
      TekstenUitvoerenNl.o7RedenOpgelost,
      TekstenUitvoerenNl.o7RedenOpgelostZin,
      Icons.check_circle_outline,
    ),
    (
      TekstenUitvoerenNl.o7RedenAndereDag,
      TekstenUitvoerenNl.o7RedenAndereDagZin,
      Icons.event_outlined,
    ),
    (
      TekstenUitvoerenNl.o7RedenNietThuis,
      TekstenUitvoerenNl.o7RedenNietThuisZin,
      Icons.home_outlined,
    ),
  ];

  @override
  void dispose() {
    _veld.dispose();
    super.dispose();
  }

  void _bevestigEigenReden() {
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
    final klein = HhRuimte.voor(HhRuimte.s, dichtheid);
    final tussen = HhRuimte.voor(HhRuimte.l, dichtheid);

    return AlertDialog(
      title: Text(TekstenUitvoerenNl.o7AnnuleerTitel, style: tekst.titleLarge),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(TekstenUitvoerenNl.o7AnnuleerUitleg, style: tekst.bodyLarge),
            SizedBox(height: tussen),
            if (_typtZelf) ...[
              HhInvoer(
                label: TekstenUitvoerenNl.o7RedenAndersLabel,
                controller: _veld,
                fouttekst: _fout,
                isVerplicht: true,
                maxRegels: 3,
                onChanged: (_) {
                  if (_fout != null) setState(() => _fout = null);
                },
              ),
              SizedBox(height: tussen),
              HhKnop(
                label: TekstenUitvoerenNl.o7AnnuleerBevestig,
                soort: HhKnopSoort.gevaar,
                maat: HhDichtheid.groot,
                onPressed: _bevestigEigenReden,
              ),
            ] else ...[
              for (final (label, zin, icoon) in vasteRedenen) ...[
                HhKnop(
                  label: label,
                  icoon: icoon,
                  soort: HhKnopSoort.tweedeKeus,
                  maat: HhDichtheid.groot,
                  onPressed: () => Navigator.of(context).pop(zin),
                ),
                SizedBox(height: klein),
              ],
              HhKnop(
                label: TekstenUitvoerenNl.o7RedenAnders,
                icoon: Icons.edit_outlined,
                soort: HhKnopSoort.tweedeKeus,
                maat: HhDichtheid.groot,
                onPressed: () => setState(() => _typtZelf = true),
              ),
            ],
          ],
        ),
      ),
      actionsAlignment: MainAxisAlignment.start,
      actions: [
        HhKnop(
          label: TekstenUitvoerenNl.o7AnnuleerAfbreken,
          maat: HhDichtheid.groot,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}
