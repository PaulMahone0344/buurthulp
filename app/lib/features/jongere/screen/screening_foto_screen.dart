import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/result.dart';
import '../../../design/components/hh_meld_balk.dart';
import '../../../design/dichtheid_scope.dart';
import '../../../l10n/teksten_jongere_nl.dart';
import '../../../l10n/teksten_nl.dart';
import '../../../theme.dart';
import '../foto_kiezer.dart';
import '../model/screening_stap.dart';
import '../provider/screening_providers.dart';
import '../widget/foto_blok.dart';
import '../widget/screening_lader.dart';
import '../widget/screening_stap_scherm.dart';

/// J2. Documentfoto (hh_profielen.document_foto), camera of galerij, met
/// uitleg wat wel en niet zichtbaar mag zijn (BSN afschermen).
class ScreeningIdentiteitScreen extends StatelessWidget {
  const ScreeningIdentiteitScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final dichtheid = HhDichtheidScope.van(context);
    final tekst = Theme.of(context).textTheme;
    final tussen = HhRuimte.voor(HhRuimte.s, dichtheid);
    return _FotoStapScreen(
      stap: ScreeningStap.identiteit,
      veld: 'document_foto',
      uitleg: TekstenJongereNl.j2Uitleg,
      isSelfie: false,
      icoon: Icons.badge_outlined,
      boven: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const HhMeldBalk(
            soort: HhMeldSoort.informatie,
            tekst: TekstenJongereNl.j2WelZichtbaar,
          ),
          SizedBox(height: tussen),
          const HhMeldBalk(
            soort: HhMeldSoort.waarschuwing,
            tekst: TekstenJongereNl.j2NietZichtbaar,
          ),
          SizedBox(height: tussen),
          Text(TekstenJongereNl.j2Vertrouwelijk, style: tekst.bodyMedium),
        ],
      ),
    );
  }
}

/// J3. Selfie (hh_profielen.selfie), alleen de camera aan de voorkant.
class ScreeningSelfieScreen extends StatelessWidget {
  const ScreeningSelfieScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _FotoStapScreen(
      stap: ScreeningStap.selfie,
      veld: 'selfie',
      uitleg: TekstenJongereNl.j3Uitleg,
      isSelfie: true,
      icoon: Icons.face_outlined,
      cameraLabel: TekstenJongereNl.j3Knop,
    );
  }
}

class _FotoStapScreen extends ConsumerStatefulWidget {
  const _FotoStapScreen({
    required this.stap,
    required this.veld,
    required this.uitleg,
    required this.isSelfie,
    required this.icoon,
    this.boven,
    this.cameraLabel,
  });

  final ScreeningStap stap;
  final String veld;
  final String uitleg;
  final bool isSelfie;
  final IconData icoon;
  final Widget? boven;
  final String? cameraLabel;

  @override
  ConsumerState<_FotoStapScreen> createState() => _FotoStapScreenState();
}

class _FotoStapScreenState extends ConsumerState<_FotoStapScreen> {
  bool _isBezig = false;
  Uint8List? _voorbeeld;
  String? _melding;
  HhMeldSoort _meldSoort = HhMeldSoort.fout;

  Future<void> _kies(HhFotoBron bron) async {
    setState(() => _melding = null);
    final gekozen = await ref
        .read(fotoKiezerProvider)
        .kies(bron, isSelfie: widget.isSelfie);
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
        .uploadProfielFoto(
          veld: widget.veld,
          bytes: foto.bytes,
          bestandsnaam: foto.bestandsnaam,
        );
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
    final tussen = HhRuimte.voor(HhRuimte.l, dichtheid);

    return ScreeningLader(
      builder: (context, gegevens) {
        final heeftFoto = widget.stap.isAf(gegevens);
        return ScreeningStapScherm(
          stap: widget.stap,
          uitleg: widget.uitleg,
          isBezig: false,
          melding: _melding,
          meldSoort: _meldSoort,
          knopLabel: TekstenNl.verder,
          // Verder kan pas als de foto op de server staat.
          onVerder: heeftFoto && !_isBezig
              ? () => context.go(widget.stap.volgendPad)
              : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.boven != null) ...[
                widget.boven!,
                SizedBox(height: tussen),
              ],
              FotoBlok(
                heeftFoto: heeftFoto,
                voorbeeld: _voorbeeld,
                isBezig: _isBezig,
                icoon: widget.icoon,
                cameraLabel: widget.cameraLabel,
                onCamera: () => _kies(HhFotoBron.camera),
                onGalerij: widget.isSelfie
                    ? null
                    : () => _kies(HhFotoBron.galerij),
              ),
            ],
          ),
        );
      },
    );
  }
}
