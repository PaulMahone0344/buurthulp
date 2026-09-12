import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/navigatie.dart';
import '../../../app/paden.dart';
import '../../../core/config.dart';
import '../../../design/components/hh_kaart.dart';
import '../../../design/components/hh_knop.dart';
import '../../../design/components/hh_meld_balk.dart';
import '../../../design/components/hh_scherm.dart';
import '../../../design/dichtheid_scope.dart';
import '../../../l10n/teksten_nl.dart';
import '../../../theme.dart';
import '../model/hh_rol.dart';
import '../provider/sessie_providers.dart';

/// Opent een url buiten de app (bellen). Losse provider zodat tests hem
/// vervangen en er nooit een plugin-aanroep in een test zit.
final urlOpenerProvider = Provider<Future<bool> Function(Uri)>(
  (ref) => launchUrl,
);

/// G8. Belknop naar de meldkamer plus statische veelgestelde vragen. Voor
/// een ingelogde (of op G2 gekozen) rol alleen het eigen blok; zonder rol
/// alle blokken.
class HulpScreen extends ConsumerStatefulWidget {
  const HulpScreen({super.key});

  @override
  ConsumerState<HulpScreen> createState() => _HulpScreenState();
}

class _HulpScreenState extends ConsumerState<HulpScreen> {
  String? _melding;

  static List<HhVraag> vragenVoor(HhRol rol) => switch (rol) {
    HhRol.hulpvrager => TekstenNl.hulpVragenHulpvrager,
    HhRol.jongere => TekstenNl.hulpVragenJongere,
    HhRol.familie => TekstenNl.hulpVragenFamilie,
    HhRol.coordinator => TekstenNl.hulpVragenCoordinator,
  };

  Future<void> _bel() async {
    setState(() => _melding = null);
    final uri = Uri(scheme: 'tel', path: HhConfig.meldkamerTelefoon);
    var gelukt = false;
    try {
      gelukt = await ref.read(urlOpenerProvider)(uri);
    } on Exception {
      gelukt = false;
    }
    if (!mounted || gelukt) return;
    setState(
      () => _melding = TekstenNl.hulpBellenLuktNiet(HhConfig.meldkamerTelefoon),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gebruiker = ref.watch(huidigeGebruikerProvider);
    final rol = gebruiker?.rol ?? ref.watch(gekozenRolProvider);
    final dichtheid = HhDichtheidScope.van(context);
    final tekst = Theme.of(context).textTheme;
    final tussen = HhRuimte.voor(HhRuimte.l, dichtheid);
    final rollen = rol == null ? HhRol.values : [rol];

    return HhScherm(
      titel: TekstenNl.hulpTitel,
      onTerug: () => terugOf(context, gebruiker?.rol.pad ?? HhPaden.welkom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          HhKnop(
            label: TekstenNl.hulpBelMeldkamer,
            icoon: Icons.phone_outlined,
            semantiekLabel:
                '${TekstenNl.hulpBelMeldkamer}, ${HhConfig.meldkamerTelefoon}',
            onPressed: _bel,
          ),
          SizedBox(height: HhRuimte.voor(HhRuimte.s, dichtheid)),
          ExcludeSemantics(
            child: Text(
              HhConfig.meldkamerTelefoon,
              style: tekst.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ),
          if (_melding != null) ...[
            SizedBox(height: tussen),
            HhMeldBalk(soort: HhMeldSoort.waarschuwing, tekst: _melding!),
          ],
          SizedBox(height: HhRuimte.voor(HhRuimte.xl, dichtheid)),
          for (final r in rollen) ...[
            HhKaart(
              kop: rollen.length == 1 ? TekstenNl.hulpVeelgesteld : r.naam,
              child: _VragenLijst(vragen: vragenVoor(r)),
            ),
            if (r != rollen.last) SizedBox(height: tussen),
          ],
        ],
      ),
    );
  }
}

class _VragenLijst extends StatelessWidget {
  const _VragenLijst({required this.vragen});

  final List<HhVraag> vragen;

  @override
  Widget build(BuildContext context) {
    final dichtheid = HhDichtheidScope.van(context);
    final tekst = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < vragen.length; i++) ...[
          if (i > 0) ...[
            SizedBox(height: HhRuimte.voor(HhRuimte.m, dichtheid)),
            const Divider(),
            SizedBox(height: HhRuimte.voor(HhRuimte.m, dichtheid)),
          ],
          MergeSemantics(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  vragen[i].vraag,
                  style: tekst.bodyLarge!.copyWith(fontWeight: FontWeight.w600),
                ),
                SizedBox(height: HhRuimte.voor(HhRuimte.xs, dichtheid)),
                Text(vragen[i].antwoord, style: tekst.bodyMedium),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
