import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/result.dart';
import '../../../design/components/hh_knop.dart';
import '../../../design/components/hh_meld_balk.dart';
import '../../../design/dichtheid_scope.dart';
import '../../../l10n/teksten_klus_nl.dart';
import '../../../theme.dart';
import '../../jongere/foto_kiezer.dart';
import '../provider/concept_controller.dart';

/// "Foto van de klus" (B4, verplicht): maken of kiezen, met een voorbeeld en
/// een knop om hem weer weg te halen. De foto is al verkleind (FotoKiezer:
/// max 1600 px, jpeg) en gaat pas mee bij het plaatsen.
class KlusFotoSectie extends ConsumerStatefulWidget {
  const KlusFotoSectie({required this.toonFout, super.key});

  /// True na een tik op "Klus plaatsen" zonder foto.
  final bool toonFout;

  /// Hoogte van het voorbeeld, net als in de mockup.
  static const voorbeeldHoogte = 160.0;

  @override
  ConsumerState<KlusFotoSectie> createState() => _KlusFotoSectieState();
}

class _KlusFotoSectieState extends ConsumerState<KlusFotoSectie> {
  bool _isBezig = false;
  bool _luktNiet = false;

  Future<void> _kies(HhFotoBron bron) async {
    setState(() {
      _isBezig = true;
      _luktNiet = false;
    });
    final result = await ref.read(fotoKiezerProvider).kies(bron);
    if (!mounted) return;
    setState(() => _isBezig = false);
    switch (result) {
      case Ok<HhFoto?>(:final waarde):
        if (waarde != null) {
          ref.read(conceptProvider.notifier).zetFoto(waarde);
        }
      case Err<HhFoto?>():
        setState(() => _luktNiet = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final foto = ref.watch(conceptProvider.select((c) => c.foto));
    final dichtheid = HhDichtheidScope.van(context);
    final tussen = HhRuimte.voor(HhRuimte.s, dichtheid);
    final tekst = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(TekstenKlusNl.fotoUitleg, style: tekst.bodyMedium),
        SizedBox(height: tussen),
        if (foto != null) ...[
          Semantics(
            image: true,
            label: TekstenKlusNl.fotoVoorbeeldSemantiek,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(HhRadius.groot),
              child: Image.memory(
                foto.bytes,
                height: KlusFotoSectie.voorbeeldHoogte,
                fit: BoxFit.cover,
                excludeFromSemantics: true,
                errorBuilder: (_, _, _) => const SizedBox(
                  height: KlusFotoSectie.voorbeeldHoogte,
                  child: ColoredBox(color: HhKleuren.oppervlak),
                ),
              ),
            ),
          ),
          SizedBox(height: tussen),
          Text(
            TekstenKlusNl.fotoGekozen,
            style: tekst.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          SizedBox(height: tussen),
          HhKnop(
            label: TekstenKlusNl.fotoVerwijderen,
            icoon: Icons.close,
            soort: HhKnopSoort.tekst,
            onPressed: _isBezig
                ? null
                : () => ref.read(conceptProvider.notifier).zetFoto(null),
          ),
        ] else ...[
          HhKnop(
            label: TekstenKlusNl.fotoMaken,
            icoon: Icons.photo_camera_outlined,
            soort: HhKnopSoort.tweedeKeus,
            isBezig: _isBezig,
            onPressed: () => _kies(HhFotoBron.camera),
          ),
          SizedBox(height: tussen),
          HhKnop(
            label: TekstenKlusNl.fotoKiezen,
            icoon: Icons.photo_library_outlined,
            soort: HhKnopSoort.tweedeKeus,
            onPressed: _isBezig ? null : () => _kies(HhFotoBron.galerij),
          ),
        ],
        if (_luktNiet || (widget.toonFout && foto == null)) ...[
          SizedBox(height: tussen),
          HhMeldBalk(
            soort: HhMeldSoort.fout,
            tekst: _luktNiet
                ? TekstenKlusNl.fotoLuktNiet
                : TekstenKlusNl.ontbreektFoto,
          ),
        ],
      ],
    );
  }
}
