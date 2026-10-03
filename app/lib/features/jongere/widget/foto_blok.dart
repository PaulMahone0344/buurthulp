import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../design/components/hh_knop.dart';
import '../../../design/dichtheid_scope.dart';
import '../../../design/lijn.dart';
import '../../../l10n/teksten_jongere_nl.dart';
import '../../../theme.dart';

/// Foto maken of kiezen, met een voorbeeld van de zojuist gekozen foto. Een
/// foto die al op de server staat wordt niet opnieuw opgehaald (de
/// screeningfoto's zijn beschermd); het blok zegt dan dat hij er is.
class FotoBlok extends StatelessWidget {
  const FotoBlok({
    required this.heeftFoto,
    required this.onCamera,
    required this.onGalerij,
    this.voorbeeld,
    this.isBezig = false,
    this.icoon = Icons.photo_camera_outlined,
    super.key,
  });

  /// Staat er al een foto op de server.
  final bool heeftFoto;
  final VoidCallback? onCamera;
  final VoidCallback? onGalerij;

  /// De bytes van de foto die net gekozen is, om te tonen.
  final Uint8List? voorbeeld;
  final bool isBezig;
  final IconData icoon;

  /// Verhouding van het voorbeeldvlak: liggend, zodat het op een smal
  /// scherm niet de hele hoogte pakt.
  static const _verhouding = 4 / 3;

  @override
  Widget build(BuildContext context) {
    final dichtheid = HhDichtheidScope.van(context);
    final tekst = Theme.of(context).textTheme;
    final schema = Theme.of(context).colorScheme;
    final tussen = HhRuimte.voor(HhRuimte.s, dichtheid);
    final bytes = voorbeeld;

    final statusTekst = isBezig
        ? TekstenJongereNl.fotoBezig
        : heeftFoto
        ? TekstenJongereNl.fotoStaatKlaar
        : TekstenJongereNl.fotoNogGeen;

    final vlak = ClipRRect(
      borderRadius: BorderRadius.circular(HhRadius.groot),
      child: AspectRatio(
        aspectRatio: _verhouding,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: HhKleuren.oppervlak,
            border: Border.all(
              color: schema.outline,
              width: HhLijn.dun(context),
            ),
            borderRadius: BorderRadius.circular(HhRadius.groot),
          ),
          child: bytes != null
              ? Image.memory(
                  bytes,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  errorBuilder: (context, error, stack) =>
                      _Leeg(icoon: icoon, tekst: statusTekst),
                )
              : _Leeg(
                  icoon: heeftFoto ? Icons.check_circle_outline : icoon,
                  tekst: statusTekst,
                ),
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          container: true,
          label: statusTekst,
          liveRegion: true,
          excludeSemantics: true,
          child: vlak,
        ),
        SizedBox(height: HhRuimte.voor(HhRuimte.m, dichtheid)),
        HhKnop(
          label: TekstenJongereNl.fotoMaken,
          icoon: Icons.photo_camera_outlined,
          soort: heeftFoto ? HhKnopSoort.tweedeKeus : HhKnopSoort.primair,
          isBezig: isBezig,
          onPressed: onCamera,
        ),
        SizedBox(height: tussen),
        HhKnop(
          label: TekstenJongereNl.fotoKiezen,
          icoon: Icons.photo_library_outlined,
          soort: HhKnopSoort.tweedeKeus,
          onPressed: isBezig ? null : onGalerij,
        ),
        if (heeftFoto && bytes == null) ...[
          SizedBox(height: tussen),
          ExcludeSemantics(
            child: Text(
              TekstenJongereNl.fotoStaatKlaar,
              style: tekst.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ],
    );
  }
}

class _Leeg extends StatelessWidget {
  const _Leeg({required this.icoon, required this.tekst});

  final IconData icoon;
  final String tekst;

  @override
  Widget build(BuildContext context) {
    final dichtheid = HhDichtheidScope.van(context);
    final stijl = Theme.of(context).textTheme.bodyMedium;
    // Geen scrollen, wel knippen: bij 200 procent tekst op een smal scherm
    // past de tekst niet altijd in het vlak, en dat mag nooit een fout zijn.
    return Center(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.all(HhRuimte.voor(HhRuimte.l, dichtheid)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icoon,
              size: HhMaten.avatar(dichtheid),
              color: HhKleuren.tekstDerde,
            ),
            SizedBox(height: HhRuimte.voor(HhRuimte.s, dichtheid)),
            Text(tekst, style: stijl, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
