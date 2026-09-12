import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/result.dart';
import '../../../design/components/hh_invoer.dart';
import '../../../design/components/hh_kaart.dart';
import '../../../design/components/hh_meld_balk.dart';
import '../../../design/dichtheid_scope.dart';
import '../../../l10n/teksten_jongere_nl.dart';
import '../../../theme.dart';
import '../datum_invoer.dart';
import '../foto_kiezer.dart';
import '../model/screening_stap.dart';
import '../provider/screening_providers.dart';
import '../widget/foto_blok.dart';
import '../widget/screening_lader.dart';
import '../widget/screening_stap_scherm.dart';

/// J1. Foto (hh_users.foto, camera of galerij), geboortedatum (hh_users) en
/// over mij (hh_profielen.over_mij). Maakt het profiel aan als het nog niet
/// bestaat. Alleen gewijzigde velden gaan naar de server.
class ScreeningProfielScreen extends ConsumerStatefulWidget {
  const ScreeningProfielScreen({super.key});

  static const maxOverMij = 500;

  @override
  ConsumerState<ScreeningProfielScreen> createState() =>
      _ScreeningProfielScreenState();
}

class _ScreeningProfielScreenState
    extends ConsumerState<ScreeningProfielScreen> {
  final _geboortedatum = TextEditingController();
  final _overMij = TextEditingController();
  bool _isIngevuld = false;
  bool _isBezig = false;
  bool _isFotoBezig = false;
  Uint8List? _fotoVoorbeeld;
  String? _datumFout;
  String? _overMijFout;
  String? _melding;
  HhMeldSoort _meldSoort = HhMeldSoort.fout;

  @override
  void dispose() {
    _geboortedatum.dispose();
    _overMij.dispose();
    super.dispose();
  }

  void _vulIn(ScreeningGegevens gegevens) {
    if (_isIngevuld) return;
    _isIngevuld = true;
    final datum = gegevens.account.geboortedatum;
    if (datum != null) _geboortedatum.text = toonDatumNl(datum);
    _overMij.text = gegevens.profiel?.overMij ?? '';
  }

  Future<void> _kiesFoto(HhFotoBron bron) async {
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
      _fotoVoorbeeld = foto.bytes;
      _isFotoBezig = true;
    });
    final result = await ref
        .read(screeningControllerProvider.notifier)
        .uploadAccountFoto(bytes: foto.bytes, bestandsnaam: foto.bestandsnaam);
    if (!mounted) return;
    setState(() {
      _isFotoBezig = false;
      _toon(result, TekstenJongereNl.opgeslagen);
    });
  }

  void _toon(Result<void> result, String geslaagd) {
    switch (result) {
      case Ok<void>():
        _meldSoort = HhMeldSoort.geslaagd;
        _melding = geslaagd;
      case Err<void>(:final fout):
        _meldSoort = HhMeldSoort.fout;
        _melding = fout.melding;
    }
  }

  Future<void> _opslaan(ScreeningGegevens gegevens) async {
    final datum = parseDatumNl(_geboortedatum.text);
    final overMij = _overMij.text.trim();
    final datumFout = datum == null
        ? TekstenJongereNl.validatieGeboortedatumOngeldig
        : datum.isAfter(DateTime.now())
        ? TekstenJongereNl.validatieGeboortedatumToekomst
        : null;
    final overMijFout = overMij.isEmpty
        ? TekstenJongereNl.validatieOverMijVerplicht
        : overMij.length > ScreeningProfielScreen.maxOverMij
        ? TekstenJongereNl.validatieOverMijTeLang
        : null;
    setState(() {
      _datumFout = datumFout;
      _overMijFout = overMijFout;
      _melding = null;
    });
    if (datumFout != null || overMijFout != null || datum == null) return;

    setState(() => _isBezig = true);
    final controller = ref.read(screeningControllerProvider.notifier);
    if (gegevens.account.geboortedatum != datum) {
      final result = await controller.werkAccountBij({
        'geboortedatum': datumVoorServer(datum),
      });
      if (!mounted) return;
      if (result case Err<void>()) {
        setState(() {
          _isBezig = false;
          _toon(result, '');
        });
        return;
      }
    }
    if (gegevens.profiel == null || gegevens.profiel!.overMij != overMij) {
      final result = await controller.werkProfielBij({'over_mij': overMij});
      if (!mounted) return;
      if (result case Err<void>()) {
        setState(() {
          _isBezig = false;
          _toon(result, '');
        });
        return;
      }
    }
    setState(() => _isBezig = false);
    context.go(ScreeningStap.profiel.volgendPad);
  }

  @override
  Widget build(BuildContext context) {
    final dichtheid = HhDichtheidScope.van(context);
    final tussen = HhRuimte.voor(HhRuimte.l, dichtheid);

    return ScreeningLader(
      builder: (context, gegevens) {
        _vulIn(gegevens);
        return ScreeningStapScherm(
          stap: ScreeningStap.profiel,
          uitleg: TekstenJongereNl.j1Uitleg,
          isBezig: _isBezig,
          melding: _melding,
          meldSoort: _meldSoort,
          onVerder: _isFotoBezig ? null : () => _opslaan(gegevens),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              HhKaart(
                kop: TekstenJongereNl.j1FotoKop,
                child: FotoBlok(
                  heeftFoto: gegevens.account.heeftFoto,
                  voorbeeld: _fotoVoorbeeld,
                  isBezig: _isFotoBezig,
                  icoon: Icons.account_circle_outlined,
                  onCamera: _isBezig
                      ? null
                      : () => _kiesFoto(HhFotoBron.camera),
                  onGalerij: _isBezig
                      ? null
                      : () => _kiesFoto(HhFotoBron.galerij),
                ),
              ),
              SizedBox(height: tussen),
              HhInvoer(
                label: TekstenJongereNl.j1Geboortedatum,
                controller: _geboortedatum,
                hulptekst: TekstenJongereNl.j1GeboortedatumHulp,
                fouttekst: _datumFout,
                isVerplicht: true,
                isActief: !_isBezig,
                keyboardType: TextInputType.datetime,
                textInputAction: TextInputAction.next,
              ),
              SizedBox(height: tussen),
              HhInvoer(
                label: TekstenJongereNl.j1OverMij,
                controller: _overMij,
                hulptekst: TekstenJongereNl.j1OverMijHulp,
                fouttekst: _overMijFout,
                isVerplicht: true,
                isActief: !_isBezig,
                maxRegels: 6,
              ),
            ],
          ),
        );
      },
    );
  }
}
