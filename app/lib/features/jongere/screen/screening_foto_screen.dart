import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/result.dart';
import '../../../design/components/hh_meld_balk.dart';
import '../../../design/dichtheid_scope.dart';
import '../../../l10n/teksten_aanmelden_nl.dart';
import '../../../l10n/teksten_jongere_nl.dart';
import '../../../l10n/teksten_nl.dart';
import '../../../theme.dart';
import '../foto_kiezer.dart';
import '../model/screening_stap.dart';
import '../paden_jongere.dart';
import '../provider/screening_providers.dart';
import '../widget/foto_blok.dart';
import '../widget/screening_lader.dart';
import '../widget/screening_stap_scherm.dart';

/// J2. Foto van een ID-bewijs (hh_profielen.document_foto), camera of
/// galerij, met "Dek je BSN af" en de tip KopieID. Is het ID gecontroleerd
/// (goedgekeurd), dan is de foto gewist en kan er geen nieuwe meer bij: de
/// server weigert dat ook (80-b2-rules).
class ScreeningIdentiteitScreen extends ConsumerStatefulWidget {
  const ScreeningIdentiteitScreen({super.key});

  @override
  ConsumerState<ScreeningIdentiteitScreen> createState() =>
      _ScreeningIdentiteitScreenState();
}

class _ScreeningIdentiteitScreenState
    extends ConsumerState<ScreeningIdentiteitScreen> {
  bool _isBezig = false;
  Uint8List? _voorbeeld;
  String? _melding;
  HhMeldSoort _meldSoort = HhMeldSoort.fout;

  Future<void> _kies(HhFotoBron bron) async {
    setState(() => _melding = null);
    final gekozen = await ref.read(fotoKiezerProvider).kies(bron);
    if (!mounted) return;
    final HhFoto foto;
    switch (gekozen) {
      case Err<HhFoto?>():
        setState(() {
          _meldSoort = HhMeldSoort.waarschuwing;
          _melding = bron == HhFotoBron.camera
              ? TekstenJongereNl.fotoCameraLuktNiet
              : TekstenJongereNl.fotoKiezenLuktNiet;
        });
        return;
      case Ok<HhFoto?>(waarde: null):
        return;
      case Ok<HhFoto?>(waarde: final w):
        foto = w!;
    }
    setState(() {
      _voorbeeld = foto.bytes;
      _isBezig = true;
    });
    final result = await ref
        .read(screeningControllerProvider.notifier)
        .uploadIdFoto(bytes: foto.bytes, bestandsnaam: foto.bestandsnaam);
    if (!mounted) return;
    setState(() {
      _isBezig = false;
      switch (result) {
        case Ok<void>():
          _meldSoort = HhMeldSoort.geslaagd;
          _melding = TekstenJongereNl.opgeslagen;
        case Err<void>(:final fout):
          _meldSoort = HhMeldSoort.fout;
          _melding = fout.melding;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final dichtheid = HhDichtheidScope.van(context);
    final tekst = Theme.of(context).textTheme;
    final tussen = HhRuimte.voor(HhRuimte.l, dichtheid);
    final klein = HhRuimte.voor(HhRuimte.s, dichtheid);

    return ScreeningLader(
      builder: (context, gegevens) {
        final isGecontroleerd = gegevens.profiel?.isIdGecontroleerd ?? false;
        final heeftFoto = ScreeningStap.identiteit.isAf(gegevens);
        return ScreeningStapScherm(
          stap: ScreeningStap.identiteit,
          gegevens: gegevens,
          uitleg: TekstenJongereNl.j2Uitleg,
          melding: _melding,
          meldSoort: _meldSoort,
          knopLabel: TekstenNl.verder,
          // Verder kan pas als de foto op de server staat.
          onVerder: heeftFoto && !_isBezig
              ? () => context.go(HhPadenJongere.overzicht)
              : null,
          child: isGecontroleerd
              ? const HhMeldBalk(
                  soort: HhMeldSoort.geslaagd,
                  tekst: TekstenAanmeldenNl.idNaGoedkeuring,
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const HhMeldBalk(
                      soort: HhMeldSoort.informatie,
                      tekst: TekstenJongereNl.j2WelZichtbaar,
                    ),
                    SizedBox(height: klein),
                    const HhMeldBalk(
                      soort: HhMeldSoort.waarschuwing,
                      tekst: TekstenJongereNl.j2NietZichtbaar,
                    ),
                    SizedBox(height: klein),
                    Text(
                      TekstenAanmeldenNl.idTipKopieId,
                      style: tekst.bodyMedium,
                    ),
                    SizedBox(height: klein),
                    Text(
                      TekstenJongereNl.j2Vertrouwelijk,
                      style: tekst.bodyMedium,
                    ),
                    SizedBox(height: tussen),
                    FotoBlok(
                      heeftFoto: heeftFoto,
                      voorbeeld: _voorbeeld,
                      isBezig: _isBezig,
                      icoon: Icons.badge_outlined,
                      onCamera: () => _kies(HhFotoBron.camera),
                      onGalerij: () => _kies(HhFotoBron.galerij),
                    ),
                  ],
                ),
        );
      },
    );
  }
}
