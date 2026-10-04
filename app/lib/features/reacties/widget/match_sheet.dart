import 'package:flutter/material.dart';

import '../../../design/components/hh_knop.dart';
import '../../../design/dichtheid_scope.dart';
import '../../../l10n/teksten_reacties_nl.dart';
import '../../../theme.dart';
import 'initialen_avatar.dart';

/// Wat de bewoner na de keuze doet.
enum MatchKeuze { chat, later }

/// "Het is een match!" (mockup Match): twee initialen-cirkels, wie helpt
/// waarmee, en "Open de chat" (B6) of "Later". Rustig: geen confetti of
/// beweging (B13 maakt het later feestelijker, met "verminder beweging").
class MatchSheet extends StatelessWidget {
  const MatchSheet({
    required this.bewonerVoornaam,
    required this.helperVoornaam,
    required this.klusTekst,
    super.key,
  });

  final String bewonerVoornaam;
  final String helperVoornaam;

  /// "Tuin op zaterdag om 10:00".
  final String klusTekst;

  /// Toont het blad; null als de bewoner het wegveegt (= later).
  static Future<MatchKeuze?> toon(
    BuildContext context, {
    required String bewonerVoornaam,
    required String helperVoornaam,
    required String klusTekst,
  }) {
    return showModalBottomSheet<MatchKeuze>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: HhKleuren.achtergrond,
      builder: (_) => MatchSheet(
        bewonerVoornaam: bewonerVoornaam,
        helperVoornaam: helperVoornaam,
        klusTekst: klusTekst,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dichtheid = HhDichtheidScope.van(context);
    final tekst = Theme.of(context).textTheme;
    final tussen = HhRuimte.voor(HhRuimte.l, dichtheid);

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          HhRuimte.voor(HhRuimte.xl, dichtheid),
          0,
          HhRuimte.voor(HhRuimte.xl, dichtheid),
          HhRuimte.voor(HhRuimte.xl, dichtheid),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                InitialenAvatar(voornaam: bewonerVoornaam, groot: true),
                SizedBox(width: HhRuimte.voor(HhRuimte.s, dichtheid)),
                const ExcludeSemantics(
                  child: Icon(Icons.add_rounded, color: HhKleuren.accentDonker),
                ),
                SizedBox(width: HhRuimte.voor(HhRuimte.s, dichtheid)),
                InitialenAvatar(voornaam: helperVoornaam, groot: true),
              ],
            ),
            SizedBox(height: tussen),
            Semantics(
              header: true,
              child: Text(
                TekstenReactiesNl.matchTitel,
                textAlign: TextAlign.center,
                style: tekst.headlineSmall,
              ),
            ),
            SizedBox(height: HhRuimte.voor(HhRuimte.s, dichtheid)),
            Text(
              TekstenReactiesNl.matchTekst(helperVoornaam, klusTekst),
              textAlign: TextAlign.center,
              style: tekst.bodyLarge,
            ),
            SizedBox(height: HhRuimte.voor(HhRuimte.s, dichtheid)),
            Text(
              TekstenReactiesNl.matchUitleg,
              textAlign: TextAlign.center,
              style: tekst.bodyMedium,
            ),
            SizedBox(height: HhRuimte.voor(HhRuimte.xl, dichtheid)),
            HhKnop(
              label: TekstenReactiesNl.openDeChat,
              icoon: Icons.chat_bubble_outline,
              onPressed: () => Navigator.of(context).pop(MatchKeuze.chat),
            ),
            SizedBox(height: HhRuimte.voor(HhRuimte.s, dichtheid)),
            HhKnop(
              label: TekstenReactiesNl.later,
              soort: HhKnopSoort.tekst,
              onPressed: () => Navigator.of(context).pop(MatchKeuze.later),
            ),
          ],
        ),
      ),
    );
  }
}
