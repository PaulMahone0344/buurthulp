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
import '../../../l10n/teksten_adres_nl.dart';
import '../../adres/domein/adres_invoer.dart';
import '../../adres/widget/adres_zoeker.dart';
import '../../toegang/provider/sessie_providers.dart';
import '../domein/adres.dart';
import '../model/hh_gegevens.dart';
import '../provider/hulpvrager_providers.dart';
import '../widget/woning_kaart.dart';

/// O12. Naam, telefoon, adres en contactpersoon. Opslaan stuurt alleen de
/// gewijzigde velden (backend OPEN-PUNT 10). Bereikbaar vanaf O1 en als
/// tussenstap vanuit O4 wanneer er nog geen adres bekend is.
/// ADRES (4 okt): het adres gaat "zoals bol.com" (postcode + huisnummer +
/// toevoeging, straat en plaats van PDOK); niet meer vrij te typen.
class MijnGegevensScreen extends ConsumerStatefulWidget {
  const MijnGegevensScreen({super.key});

  @override
  ConsumerState<MijnGegevensScreen> createState() => _MijnGegevensScreenState();
}

class _MijnGegevensScreenState extends ConsumerState<MijnGegevensScreen> {
  final _velden = {
    HhGegevens.veldNaam: TextEditingController(),
    HhGegevens.veldTelefoon: TextEditingController(),
    HhGegevens.veldContactNaam: TextEditingController(),
    HhGegevens.veldContactTelefoon: TextEditingController(),
    HhGegevens.veldVerdieping: TextEditingController(),
    HhGegevens.veldBereikbaarheid: TextEditingController(),
  };

  /// Punt F: de knop-keuzes van "Je woning" (leeg = niet ingevuld).
  final _keuzes = {
    HhGegevens.veldWoningType: '',
    HhGegevens.veldLift: '',
    HhGegevens.veldTrap: '',
  };
  bool _isVoorgevuld = false;
  bool _isBezig = false;
  HhMeldSoort? _meldSoort;
  String? _melding;
  String? _naamFout;

  /// ADRES: de keuze uit de adres-suggestie; [_adresAangeraakt] zodra de
  /// gebruiker iets aan het adres veranderde.
  AdresKeuze? _adres;
  bool _adresAangeraakt = false;
  String? _adresFout;

  /// Na een adreswijziging haalt de sessie de gebruiker opnieuw op (wijk,
  /// werkgebied, gele balk), maar pas als dit scherm weg is: verandert de
  /// sessie terwijl het scherm eronder gepauzeerd staat, dan wil Riverpod 3
  /// bij terugkomen midden in een build opnieuw bouwen.
  late final SessieController _sessie;
  bool _sessieVerversen = false;

  @override
  void initState() {
    super.initState();
    _sessie = ref.read(sessieControllerProvider.notifier);
  }

  @override
  void dispose() {
    for (final controller in _velden.values) {
      controller.dispose();
    }
    if (_sessieVerversen) {
      final sessie = _sessie;
      WidgetsBinding.instance.addPostFrameCallback((_) => sessie.ververs());
    }
    super.dispose();
  }

  void _vulVoor(HhGegevens gegevens) {
    if (_isVoorgevuld) return;
    _isVoorgevuld = true;
    for (final veld in gegevens.alsVelden.entries) {
      _velden[veld.key]?.text = veld.value;
      if (_keuzes.containsKey(veld.key)) _keuzes[veld.key] = veld.value;
    }
  }

  Map<String, String> get _invoer => {
    for (final veld in _velden.entries) veld.key: veld.value.text.trim(),
    ..._keuzes,
  };

  /// Alleen de adresvelden die anders zijn dan wat er staat.
  Map<String, dynamic> _adresWijziging(HhGegevens huidig) {
    final keuze = _adres;
    if (!_adresAangeraakt || keuze == null) return const {};
    final huidigeVelden = huidig.alsVelden;
    final anders = keuze.velden.entries.any(
      (v) => (huidigeVelden[v.key] ?? '') != v.value,
    );
    return anders ? keuze.velden : const {};
  }

  final _naamSleutel = GlobalKey();
  final _adresSleutel = GlobalKey();
  final _meldingSleutel = GlobalKey();

  /// Scrolt [sleutel] in beeld na de volgende frame (de melding of het veld
  /// met de fout).
  void _toon(GlobalKey sleutel) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final doel = sleutel.currentContext;
      if (doel == null || !doel.mounted) return;
      Scrollable.ensureVisible(
        doel,
        alignment: 0.1,
        duration: MediaQuery.disableAnimationsOf(doel)
            ? Duration.zero
            : const Duration(milliseconds: 250),
      );
    });
  }

  Future<void> _opslaan(HhGegevens huidig) async {
    // Toetsenbord weg, zodat de melding boven de knop te zien is.
    FocusManager.instance.primaryFocus?.unfocus();
    final invoer = _invoer;
    setState(() {
      _melding = null;
      _naamFout = invoer[HhGegevens.veldNaam]!.isEmpty
          ? TekstenHulpvragerNl.gegevensNaamVerplicht
          : null;
      _adresFout = _adresAangeraakt && _adres == null
          ? TekstenAdresNl.validatieNietBevestigd
          : null;
    });
    if (_naamFout != null || _adresFout != null) {
      setState(() {
        _meldSoort = HhMeldSoort.fout;
        _melding = TekstenHulpvragerNl.gegevensNakijken;
      });
      _toon(_naamFout != null ? _naamSleutel : _adresSleutel);
      return;
    }

    final adresWijziging = _adresWijziging(huidig);
    final gewijzigd = {...huidig.gewijzigdeVelden(invoer), ...adresWijziging};
    if (gewijzigd.isEmpty) {
      setState(() {
        _meldSoort = HhMeldSoort.informatie;
        _melding = TekstenHulpvragerNl.gegevensNietsGewijzigd;
      });
      _toon(_meldingSleutel);
      return;
    }

    setState(() => _isBezig = true);
    final result = await ref
        .read(gegevensProvider.notifier)
        .bijwerken(gewijzigd);
    // Een nieuw adres kan een nieuw werkgebied geven (en de gele balk weg):
    // de sessie haalt de gebruiker opnieuw op als dit scherm weg is.
    if (result is Ok<void> && adresWijziging.isNotEmpty) {
      _sessieVerversen = true;
    }
    if (!mounted) return;
    setState(() {
      _isBezig = false;
      switch (result) {
        case Ok<void>():
          _meldSoort = HhMeldSoort.geslaagd;
          _melding = TekstenHulpvragerNl.gegevensOpgeslagen;
          _adresAangeraakt = false;
        case Err<void>(:final fout):
          _meldSoort = HhMeldSoort.fout;
          _melding = fout.melding;
      }
    });
    _toon(_meldingSleutel);
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
          key: _naamSleutel,
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
          key: _adresSleutel,
          kop: TekstenHulpvragerNl.gegevensKaartAdres,
          child: AdresZoeker(
            beginPostcode: gegevens.postcode,
            beginHuisnummer: gegevens.huisnummer,
            beginToevoeging: gegevens.toevoeging,
            beginWeergave:
                heeftVolledigAdres(gegevens.postcode, gegevens.huisnummer) &&
                    gegevens.adres.trim().isNotEmpty
                ? stelAdresSamen(
                    adres: gegevens.adres,
                    postcode: gegevens.postcode,
                    plaats: gegevens.plaats,
                  )
                : null,
            isActief: !_isBezig,
            fouttekst: _adresFout,
            onGewijzigd: (keuze) => setState(() {
              _adres = keuze;
              _adresAangeraakt = true;
            }),
          ),
        ),
        SizedBox(height: tussen),
        WoningKaart(
          woningType: _keuzes[HhGegevens.veldWoningType]!,
          lift: _keuzes[HhGegevens.veldLift]!,
          trap: _keuzes[HhGegevens.veldTrap]!,
          verdieping: _velden[HhGegevens.veldVerdieping]!,
          bereikbaarheid: _velden[HhGegevens.veldBereikbaarheid]!,
          isActief: !_isBezig,
          onKeuze: (veld, waarde) => setState(() => _keuzes[veld] = waarde),
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
        // De uitkomst staat vlak boven de knop, niet bovenaan: anders zie je
        // na "Opslaan" niets gebeuren (Ibrahim 4 okt).
        if (_melding != null) ...[
          HhMeldBalk(
            key: _meldingSleutel,
            soort: _meldSoort!,
            tekst: _melding!,
          ),
          SizedBox(height: tussen),
        ],
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
