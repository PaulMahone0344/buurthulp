import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/navigatie.dart';
import '../../../../design/components/hh_kaart.dart';
import '../../../../design/components/hh_knop.dart';
import '../../../../design/components/hh_scherm.dart';
import '../../../../design/dichtheid_scope.dart';
import '../../../../l10n/teksten_xp_nl.dart';
import '../../../../theme.dart';
import '../../../toegang/provider/sessie_providers.dart';
import '../../klussen/paden_klussen.dart';
import '../domein/xp_tekst.dart';
import '../model/hh_xp.dart';
import '../widget/niveau_pil.dart';

/// HBeloning (B9): na "Klaar" zegt de app wat de klus opleverde: +XP, een
/// nieuw niveau en nieuwe badges. Alles uit het antwoord van de statusroute;
/// de app rekent niets. Een rustige opkomst-animatie, die wegvalt bij
/// "verminder beweging" (M12).
class BeloningScreen extends ConsumerWidget {
  const BeloningScreen({
    required this.klusId,
    required this.beloning,
    super.key,
  });

  final String klusId;
  final HhBeloning beloning;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dichtheid = HhDichtheidScope.van(context);
    final tekst = Theme.of(context).textTheme;
    final tussen = HhRuimte.voor(HhRuimte.l, dichtheid);
    final naam = ref.watch(huidigeGebruikerProvider)?.naam ?? '';
    final voornaam = naam.trim().split(RegExp(r'\s+')).first;
    final rustig = MediaQuery.disableAnimationsOf(context);

    void klaar() => terugOf(context, HhPadenKlussen.mijnKlussen);

    return HhScherm(
      titel: TekstenXpNl.beloningTitel,
      onTerug: klaar,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            TekstenXpNl.goedGedaan(voornaam),
            style: tekst.headlineSmall,
            textAlign: TextAlign.center,
          ),
          SizedBox(height: tussen),
          _Opkomst(
            rustig: rustig,
            child: Text(
              TekstenXpNl.xpErbij(beloning.xpErbij),
              style: tekst.displaySmall!.copyWith(
                color: HhKleuren.primair,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(height: HhRuimte.voor(HhRuimte.s, dichtheid)),
          Center(
            child: Wrap(
              spacing: HhRuimte.voor(HhRuimte.s, dichtheid),
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                NiveauPil(tekst: beloning.niveau.naam),
                Text(
                  TekstenXpNl.xpTotaal(beloning.totaal),
                  style: tekst.bodyLarge,
                ),
              ],
            ),
          ),
          if (beloning.isNiveauOmhoog) ...[
            SizedBox(height: tussen),
            Text(
              TekstenXpNl.nieuwNiveau(beloning.niveau.naam),
              style: tekst.titleLarge,
              textAlign: TextAlign.center,
            ),
          ],
          for (final badge in beloning.nieuweBadges) ...[
            SizedBox(height: tussen),
            HhKaart(
              kop: TekstenXpNl.nieuweBadge,
              child: MergeSemantics(
                child: Row(
                  children: [
                    _Opkomst(
                      rustig: rustig,
                      child: Icon(
                        badgeIcoon(badge.icoon),
                        size: HhRuimte.voor(HhRuimte.xxxl, dichtheid),
                        color: HhKleuren.accentDonker,
                      ),
                    ),
                    SizedBox(width: HhRuimte.voor(HhRuimte.m, dichtheid)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(badge.naam, style: tekst.titleMedium),
                          if (badge.uitleg.isNotEmpty)
                            Text(badge.uitleg, style: tekst.bodyMedium),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          SizedBox(height: HhRuimte.voor(HhRuimte.xl, dichtheid)),
          HhKnop(
            label: TekstenXpNl.top,
            icoon: Icons.check_rounded,
            onPressed: klaar,
          ),
          SizedBox(height: HhRuimte.voor(HhRuimte.s, dichtheid)),
          HhKnop(
            label: TekstenXpNl.startNaarProfiel,
            icoon: Icons.military_tech_outlined,
            soort: HhKnopSoort.tweedeKeus,
            onPressed: () => context.go(HhPadenKlussen.profiel),
          ),
        ],
      ),
    );
  }
}

/// Komt rustig op (schaal + doorzichtigheid). Met "verminder beweging":
/// meteen staan.
class _Opkomst extends StatelessWidget {
  const _Opkomst({required this.rustig, required this.child});

  final bool rustig;
  final Widget child;

  static const _duur = Duration(milliseconds: 450);

  @override
  Widget build(BuildContext context) {
    if (rustig) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.85, end: 1),
      duration: _duur,
      curve: Curves.easeOutBack,
      builder: (context, waarde, kind) => Opacity(
        opacity: ((waarde - 0.85) / 0.15).clamp(0.0, 1.0),
        child: Transform.scale(scale: waarde, child: kind),
      ),
      child: child,
    );
  }
}
