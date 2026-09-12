import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/navigatie.dart';
import '../../../app/paden.dart';
import '../../../core/hh_fout.dart';
import '../../../core/result.dart';
import '../../../design/components/hh_invoer.dart';
import '../../../design/components/hh_kaart.dart';
import '../../../design/components/hh_knop.dart';
import '../../../design/components/hh_laad_staat.dart';
import '../../../design/components/hh_meld_balk.dart';
import '../../../design/components/hh_scherm.dart';
import '../../../design/dichtheid_scope.dart';
import '../../../l10n/teksten_hulpvrager_nl.dart';
import '../../../l10n/teksten_nl.dart';
import '../../../theme.dart';
import '../model/hh_gegevens.dart';
import '../provider/hulpvrager_providers.dart';

/// O12. Naam, telefoon, adres en contactpersoon. Opslaan stuurt alleen de
/// gewijzigde velden (backend OPEN-PUNT 10). Bereikbaar vanaf O1 en als
/// tussenstap vanuit O4 wanneer er nog geen adres bekend is.
class MijnGegevensScreen extends ConsumerStatefulWidget {
  const MijnGegevensScreen({super.key});

  @override
  ConsumerState<MijnGegevensScreen> createState() => _MijnGegevensScreenState();
}

class _MijnGegevensScreenState extends ConsumerState<MijnGegevensScreen> {
  final _velden = {
    HhGegevens.veldNaam: TextEditingController(),
    HhGegevens.veldTelefoon: TextEditingController(),
    HhGegevens.veldAdres: TextEditingController(),
    HhGegevens.veldPostcode: TextEditingController(),
    HhGegevens.veldPlaats: TextEditingController(),
    HhGegevens.veldContactNaam: TextEditingController(),
    HhGegevens.veldContactTelefoon: TextEditingController(),
  };
  bool _isVoorgevuld = false;
  bool _isBezig = false;
  HhMeldSoort? _meldSoort;
  String? _melding;
  String? _naamFout;

  @override
  void dispose() {
    for (final controller in _velden.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _vulVoor(HhGegevens gegevens) {
    if (_isVoorgevuld) return;
    _isVoorgevuld = true;
    for (final veld in gegevens.alsVelden.entries) {
      _velden[veld.key]!.text = veld.value;
    }
  }

  Map<String, String> get _invoer => {
    for (final veld in _velden.entries) veld.key: veld.value.text.trim(),
  };

  Future<void> _opslaan(HhGegevens huidig) async {
    final invoer = _invoer;
    setState(() {
      _melding = null;
      _naamFout = invoer[HhGegevens.veldNaam]!.isEmpty
          ? TekstenHulpvragerNl.gegevensNaamVerplicht
          : null;
    });
    if (_naamFout != null) return;

    final gewijzigd = huidig.gewijzigdeVelden(invoer);
    if (gewijzigd.isEmpty) {
      setState(() {
        _meldSoort = HhMeldSoort.informatie;
        _melding = TekstenHulpvragerNl.gegevensNietsGewijzigd;
      });
      return;
    }

    setState(() => _isBezig = true);
    final result = await ref
        .read(gegevensProvider.notifier)
        .bijwerken(gewijzigd);
    if (!mounted) return;
    setState(() {
      _isBezig = false;
      switch (result) {
        case Ok<void>():
          _meldSoort = HhMeldSoort.geslaagd;
          _melding = TekstenHulpvragerNl.gegevensOpgeslagen;
        case Err<void>(:final fout):
          _meldSoort = HhMeldSoort.fout;
          _melding = fout.melding;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final gegevens = ref.watch(gegevensProvider);
    final dichtheid = HhDichtheidScope.van(context);
    final tussen = HhRuimte.voor(HhRuimte.l, dichtheid);

    return HhScherm(
      titel: TekstenHulpvragerNl.gegevensTitel,
      onTerug: () => terugOf(context, HhPaden.hulpvrager),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_melding != null) ...[
            HhMeldBalk(soort: _meldSoort!, tekst: _melding!),
            SizedBox(height: tussen),
          ],
          switch (gegevens) {
            AsyncData(:final value) => _formulier(value),
            AsyncError(:final error) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                HhMeldBalk(
                  soort: HhMeldSoort.fout,
                  tekst: error is HhFout
                      ? error.melding
                      : TekstenNl.foutOnbekend,
                ),
                SizedBox(height: tussen),
                HhKnop(
                  label: TekstenNl.opnieuwProberen,
                  soort: HhKnopSoort.tweedeKeus,
                  onPressed: () => ref.invalidate(gegevensProvider),
                ),
              ],
            ),
            _ => const HhLaadStaat.skelet(
              regels: 3,
              label: TekstenHulpvragerNl.gegevensLaden,
            ),
          },
        ],
      ),
    );
  }

  Widget _formulier(HhGegevens gegevens) {
    _vulVoor(gegevens);
    final dichtheid = HhDichtheidScope.van(context);
    final tekst = Theme.of(context).textTheme;
    final tussen = HhRuimte.voor(HhRuimte.l, dichtheid);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(TekstenHulpvragerNl.gegevensUitleg, style: tekst.bodyLarge),
        SizedBox(height: tussen),
        HhInvoer(
          label: TekstenNl.veldNaam,
          controller: _velden[HhGegevens.veldNaam],
          isVerplicht: true,
          fouttekst: _naamFout,
          isActief: !_isBezig,
          autofillHints: const [AutofillHints.name],
          textInputAction: TextInputAction.next,
        ),
        SizedBox(height: tussen),
        HhInvoer(
          label: TekstenNl.veldTelefoon,
          controller: _velden[HhGegevens.veldTelefoon],
          isActief: !_isBezig,
          keyboardType: TextInputType.phone,
          autofillHints: const [AutofillHints.telephoneNumber],
          textInputAction: TextInputAction.next,
        ),
        SizedBox(height: tussen),
        HhKaart(
          kop: TekstenHulpvragerNl.gegevensKaartAdres,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              HhInvoer(
                label: TekstenHulpvragerNl.veldAdres,
                controller: _velden[HhGegevens.veldAdres],
                isActief: !_isBezig,
                autofillHints: const [AutofillHints.streetAddressLine1],
                textInputAction: TextInputAction.next,
              ),
              SizedBox(height: tussen),
              HhInvoer(
                label: TekstenHulpvragerNl.veldPostcode,
                controller: _velden[HhGegevens.veldPostcode],
                isActief: !_isBezig,
                autofillHints: const [AutofillHints.postalCode],
                textInputAction: TextInputAction.next,
              ),
              SizedBox(height: tussen),
              HhInvoer(
                label: TekstenHulpvragerNl.veldPlaats,
                controller: _velden[HhGegevens.veldPlaats],
                isActief: !_isBezig,
                autofillHints: const [AutofillHints.addressCity],
                textInputAction: TextInputAction.next,
              ),
            ],
          ),
        ),
        SizedBox(height: tussen),
        HhKaart(
          kop: TekstenHulpvragerNl.gegevensKaartContact,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                TekstenHulpvragerNl.gegevensContactUitleg,
                style: tekst.bodyMedium,
              ),
              SizedBox(height: tussen),
              HhInvoer(
                label: TekstenHulpvragerNl.veldContactNaam,
                controller: _velden[HhGegevens.veldContactNaam],
                isActief: !_isBezig,
                textInputAction: TextInputAction.next,
              ),
              SizedBox(height: tussen),
              HhInvoer(
                label: TekstenHulpvragerNl.veldContactTelefoon,
                controller: _velden[HhGegevens.veldContactTelefoon],
                isActief: !_isBezig,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.done,
              ),
            ],
          ),
        ),
        SizedBox(height: HhRuimte.voor(HhRuimte.xl, dichtheid)),
        HhKnop(
          label: TekstenNl.opslaan,
          icoon: Icons.save_outlined,
          isBezig: _isBezig,
          onPressed: () => _opslaan(gegevens),
        ),
      ],
    );
  }
}
