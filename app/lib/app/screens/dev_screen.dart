import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../design/components/hh_kaart.dart';
import '../../design/components/hh_keuzerij.dart';
import '../../design/components/hh_knop.dart';
import '../../design/components/hh_meld_balk.dart';
import '../../design/components/hh_scherm.dart';
import '../../design/dichtheid_scope.dart';
import '../../features/toegang/model/hh_rol.dart';
import '../../features/toegang/provider/sessie_providers.dart';
import '../../l10n/teksten_nl.dart';
import '../../theme.dart';
import '../dichtheid_controller.dart';
import '../paden.dart';

/// Ontwikkelscherm, alleen geregistreerd in debug-builds (/dev). Wisselt
/// de dichtheid via de gekozen rol (zolang niemand is ingelogd; daarna
/// volgt de dichtheid de rol van de gebruiker) en springt naar elk scherm.
/// De router-guard blijft gelden: een rolroute zonder sessie gaat naar G2.
class DevScreen extends ConsumerWidget {
  const DevScreen({super.key});

  static const _schermen = [
    ('G1 Splash', HhPaden.splash),
    ('G2 Welkom', HhPaden.welkom),
    ('G3 Inloggen', HhPaden.inloggen),
    ('G4 Registreren', HhPaden.registreren),
    ('G5 Bevestig e-mail', HhPaden.bevestigEmail),
    ('G6 Wachtwoord vergeten', HhPaden.wachtwoordVergeten),
    ('G7 Instellingen', HhPaden.instellingen),
    ('G8 Hulp', HhPaden.hulp),
    ('Hulpvrager', HhPaden.hulpvrager),
    ('Jongere', HhPaden.jongere),
    ('Familie', HhPaden.familie),
    ('Coordinator', HhPaden.coordinator),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dichtheid = ref.watch(dichtheidProvider);
    final tussen = HhRuimte.voor(HhRuimte.l, HhDichtheidScope.van(context));

    return HhScherm(
      titel: TekstenNl.devTitel,
      toonTerug: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const HhMeldBalk(
            soort: HhMeldSoort.informatie,
            tekst: TekstenNl.devUitleg,
          ),
          SizedBox(height: tussen),
          HhKaart(
            kop: TekstenNl.devDichtheid,
            child: HhKeuzerij<HhDichtheid>(
              semantiekLabel: TekstenNl.devDichtheid,
              keuzes: const [
                HhKeuze(
                  waarde: HhDichtheid.normaal,
                  label: TekstenNl.devNormaal,
                  icoon: Icons.text_fields,
                ),
                HhKeuze(
                  waarde: HhDichtheid.groot,
                  label: TekstenNl.devGroot,
                  icoon: Icons.format_size,
                ),
              ],
              geselecteerd: {dichtheid},
              onGewijzigd: (keuze) => ref
                  .read(gekozenRolProvider.notifier)
                  .kies(
                    keuze.first == HhDichtheid.groot
                        ? HhRol.hulpvrager
                        : HhRol.jongere,
                  ),
            ),
          ),
          SizedBox(height: tussen),
          HhKaart(
            kop: TekstenNl.devSchermen,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (label, pad) in _schermen) ...[
                  HhKnop(
                    label: label,
                    soort: HhKnopSoort.tweedeKeus,
                    onPressed: () => context.go(pad),
                  ),
                  if (pad != _schermen.last.$2)
                    SizedBox(height: HhRuimte.voor(HhRuimte.s, dichtheid)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
