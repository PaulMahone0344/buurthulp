import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../design/components/hh_knop.dart';
import '../../../design/components/hh_lege_staat.dart';
import '../../../design/dichtheid_scope.dart';
import '../../../design/lijn.dart';
import '../../../l10n/teksten_aanmelden_nl.dart';
import '../../../l10n/teksten_ouder_nl.dart';
import '../../../theme.dart';
import '../domein/helper_wacht.dart';
import '../paden_jongere.dart';
import '../provider/screening_providers.dart';

/// Kop en uitleg van de gele balk per wachtstand.
(String, String)? wachtTekst(HelperWacht wacht) => switch (wacht) {
  HelperWacht.nietInBuurt => (
    TekstenAanmeldenNl.nietInBuurtKop,
    TekstenAanmeldenNl.nietInBuurt,
  ),
  HelperWacht.adresOnbekend => (
    TekstenAanmeldenNl.adresOnbekendKop,
    TekstenAanmeldenNl.adresOnbekend,
  ),
  HelperWacht.nagekeken => (
    TekstenAanmeldenNl.wachtNagekeken,
    TekstenAanmeldenNl.wachtNagekekenUitleg,
  ),
  HelperWacht.ouder => (
    TekstenAanmeldenNl.wachtOuder,
    TekstenAanmeldenNl.wachtOuderUitleg,
  ),
  HelperWacht.ouderIngetrokken => (
    TekstenOuderNl.ingetrokkenKop,
    TekstenOuderNl.balkIngetrokkenUitleg,
  ),
  HelperWacht.vog => (
    TekstenAanmeldenNl.wachtVog,
    TekstenAanmeldenNl.wachtVogUitleg,
  ),
  HelperWacht.aanmelden || HelperWacht.afgewezen || HelperWacht.klaar => null,
};

/// De gele balk bovenaan Start (zoals BuurtHeld): wat er nog ontbreekt.
class WachtBalk extends StatelessWidget {
  const WachtBalk({required this.kop, required this.uitleg, super.key});

  final String kop;
  final String uitleg;

  @override
  Widget build(BuildContext context) {
    final dichtheid = HhDichtheidScope.van(context);
    final tekst = Theme.of(context).textTheme;
    return Semantics(
      container: true,
      liveRegion: true,
      label: '$kop. $uitleg',
      excludeSemantics: true,
      child: Container(
        padding: EdgeInsets.all(HhRuimte.voor(HhRuimte.l, dichtheid)),
        decoration: BoxDecoration(
          color: HhKleuren.accentZacht,
          borderRadius: BorderRadius.circular(HhRadius.groot),
          border: Border.all(
            color: HhKleuren.accent,
            width: HhLijn.dik(context),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.hourglass_top_outlined,
              color: HhKleuren.waarschuwing,
              size: HhMaten.icoonKeuzerij(dichtheid),
            ),
            SizedBox(width: HhRuimte.voor(HhRuimte.m, dichtheid)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    kop,
                    style: tekst.bodyLarge!.copyWith(
                      fontWeight: FontWeight.w700,
                      color: HhKleuren.tekst,
                    ),
                  ),
                  SizedBox(height: HhRuimte.voor(HhRuimte.xs, dichtheid)),
                  Text(
                    uitleg,
                    style: tekst.bodyMedium!.copyWith(color: HhKleuren.tekst),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Start van een helper die nog wacht: de gele balk, bij de VOG de weg
/// naar uitleg, "Opnieuw kijken" en geen klussen.
class HelperWachtStart extends ConsumerWidget {
  const HelperWachtStart({required this.wacht, super.key});

  final HelperWacht wacht;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dichtheid = HhDichtheidScope.van(context);
    final tussen = HhRuimte.voor(HhRuimte.l, dichtheid);
    final tekst = wachtTekst(wacht);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (tekst != null) WachtBalk(kop: tekst.$1, uitleg: tekst.$2),
        // B3: naar de stap "Ouder" (opnieuw sturen, adres wijzigen). Na
        // intrekken niet: dan eerst de meldkamer.
        if (wacht == HelperWacht.ouder) ...[
          SizedBox(height: HhRuimte.voor(HhRuimte.s, dichtheid)),
          HhKnop(
            label: TekstenOuderNl.balkKnop,
            icoon: Icons.mail_outline,
            soort: HhKnopSoort.tweedeKeus,
            onPressed: () => context.push(HhPadenOuder.ouder),
          ),
        ],
        if (wacht == HelperWacht.vog) ...[
          SizedBox(height: HhRuimte.voor(HhRuimte.s, dichtheid)),
          HhKnop(
            label: TekstenAanmeldenNl.wachtVogKnop,
            icoon: Icons.description_outlined,
            soort: HhKnopSoort.tweedeKeus,
            onPressed: () => context.push(HhPadenJongere.vog),
          ),
        ],
        SizedBox(height: tussen),
        const HhLegeStaat(
          icoon: Icons.volunteer_activism_outlined,
          titel: TekstenAanmeldenNl.wachtGeenKlussenKop,
          uitleg: TekstenAanmeldenNl.wachtGeenKlussen,
        ),
        SizedBox(height: tussen),
        HhKnop(
          label: TekstenAanmeldenNl.wachtVernieuwen,
          icoon: Icons.refresh,
          soort: HhKnopSoort.tekst,
          onPressed: () =>
              ref.read(screeningControllerProvider.notifier).vernieuw(),
        ),
      ],
    );
  }
}
