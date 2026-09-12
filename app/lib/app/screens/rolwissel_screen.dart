import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../design/components/hh_kaart.dart';
import '../../design/components/hh_keuzerij.dart';
import '../../design/components/hh_knop.dart';
import '../../design/components/hh_meld_balk.dart';
import '../../theme.dart';
import '../dichtheid_controller.dart';
import '../router.dart';

/// TIJDELIJK ontwikkelscherm. Springt naar de vier rol-stubs en wisselt
/// de dichtheid, zodat elke bouwsteen in beide maten te zien is. Gaat weg
/// zodra splash, welkom en inloggen (G1-G3) bestaan. Geen enkele tekst
/// hieruit hoort in de echte app.
class RolwisselScreen extends ConsumerWidget {
  const RolwisselScreen({super.key});

  static const _rollen = [
    (label: 'Hulpvrager', pad: hulpvragerPad),
    (label: 'Jongere', pad: jongerePad),
    (label: 'Familie', pad: familiePad),
    (label: 'Coordinator', pad: coordinatorPad),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dichtheid = ref.watch(dichtheidControllerProvider);
    final ruimte = HhRuimte.voor(HhRuimte.l, dichtheid);

    return Scaffold(
      appBar: AppBar(title: const Text('Rolwissel (tijdelijk)')),
      body: ListView(
        padding: EdgeInsets.all(ruimte),
        children: [
          const HhMeldBalk(
            soort: HhMeldSoort.informatie,
            tekst:
                'Tijdelijk ontwikkelscherm. Verdwijnt zodra inloggen '
                'bestaat.',
          ),
          SizedBox(height: ruimte),
          HhKaart(
            kop: 'Dichtheid',
            child: HhKeuzerij<HhDichtheid>(
              semantiekLabel: 'Dichtheid',
              keuzes: const [
                HhKeuze(
                  waarde: HhDichtheid.normaal,
                  label: 'Normaal',
                  icoon: Icons.text_fields,
                ),
                HhKeuze(
                  waarde: HhDichtheid.groot,
                  label: 'Groot',
                  icoon: Icons.format_size,
                ),
              ],
              geselecteerd: {dichtheid},
              onGewijzigd: (keuze) => ref
                  .read(dichtheidControllerProvider.notifier)
                  .zet(keuze.first),
            ),
          ),
          SizedBox(height: ruimte),
          HhKaart(
            kop: 'Rol',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final rol in _rollen) ...[
                  HhKnop(
                    label: rol.label,
                    onPressed: () => context.go(rol.pad),
                  ),
                  if (rol != _rollen.last)
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
