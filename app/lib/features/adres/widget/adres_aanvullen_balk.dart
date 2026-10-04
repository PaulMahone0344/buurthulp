import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../design/components/hh_knop.dart';
import '../../../design/dichtheid_scope.dart';
import '../../../l10n/teksten_adres_nl.dart';
import '../../../theme.dart';
import '../../hulpvrager/paden_hulpvrager.dart';
import '../../jongere/paden_jongere.dart';
import '../../jongere/widget/helper_wacht_start.dart' show WachtBalk;
import '../../toegang/model/hh_rol.dart';
import '../../toegang/provider/sessie_providers.dart';

/// ADRES (4 okt): bestaande accounts met een onvolledig adres (geen
/// 6-tekens-postcode of geen huisnummer) krijgen na inloggen een gele balk
/// "Vul je adres aan" met een knop naar hun gegevens. Geen datamigratie: de
/// gebruiker vult het zelf aan. Toont niets als het adres compleet is.
class AdresAanvullenBalk extends ConsumerWidget {
  const AdresAanvullenBalk({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gebruiker = ref.watch(huidigeGebruikerProvider);
    if (gebruiker == null || gebruiker.heeftVolledigAdres) {
      return const SizedBox.shrink();
    }
    final dichtheid = HhDichtheidScope.van(context);
    final pad = gebruiker.rol == HhRol.jongere
        ? HhPadenJongere.adres
        : HhPadenHulpvrager.gegevens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const WachtBalk(
          kop: TekstenAdresNl.aanvullenKop,
          uitleg: TekstenAdresNl.aanvullenUitleg,
        ),
        SizedBox(height: HhRuimte.voor(HhRuimte.s, dichtheid)),
        HhKnop(
          label: TekstenAdresNl.aanvullenKnop,
          icoon: Icons.home_outlined,
          soort: HhKnopSoort.tweedeKeus,
          onPressed: () => context.push(pad),
        ),
        SizedBox(height: HhRuimte.voor(HhRuimte.l, dichtheid)),
      ],
    );
  }
}
