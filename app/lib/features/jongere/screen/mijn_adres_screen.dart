import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/navigatie.dart';
import '../../../app/paden.dart';
import '../../../core/result.dart';
import '../../../design/components/hh_knop.dart';
import '../../../design/components/hh_meld_balk.dart';
import '../../../design/components/hh_scherm.dart';
import '../../../design/dichtheid_scope.dart';
import '../../../l10n/teksten_adres_nl.dart';
import '../../../l10n/teksten_nl.dart';
import '../../../theme.dart';
import '../../adres/domein/adres_invoer.dart';
import '../../adres/widget/adres_zoeker.dart';
import '../../toegang/provider/sessie_providers.dart';
import '../../toegang/model/hh_gebruiker.dart';

/// ADRES (4 okt): "Mijn adres" van een helper. Zelfde adres-suggestie als bij
/// aanmelden (postcode + huisnummer + toevoeging, straat en plaats van PDOK).
/// Bereikbaar via de gele balk "Vul je adres aan". Opslaan gaat via de sessie,
/// zodat wijk, werkgebied en de balk meteen kloppen.
class MijnAdresScreen extends ConsumerStatefulWidget {
  const MijnAdresScreen({super.key});

  @override
  ConsumerState<MijnAdresScreen> createState() => _MijnAdresScreenState();
}

class _MijnAdresScreenState extends ConsumerState<MijnAdresScreen> {
  /// Vastgehouden in initState: in dispose mag ref niet meer.
  late final SessieController _sessie;

  /// Wat de server na opslaan teruggaf; komt pas in de sessie als dit scherm
  /// weg is (zie SessieController.bijwerkenUitgesteld).
  HhGebruiker? _opgeslagen;
  AdresKeuze? _adres;
  bool _isAangeraakt = false;
  bool _isBezig = false;
  HhMeldSoort? _meldSoort;
  String? _melding;
  String? _fout;

  @override
  void initState() {
    super.initState();
    _sessie = ref.read(sessieControllerProvider.notifier);
  }

  @override
  void dispose() {
    final nieuw = _opgeslagen;
    if (nieuw != null) {
      final sessie = _sessie;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => sessie.vervangGebruiker(nieuw),
      );
    }
    super.dispose();
  }

  Future<void> _opslaan() async {
    final keuze = _adres;
    setState(() {
      _melding = null;
      _fout = _isAangeraakt && keuze == null
          ? TekstenAdresNl.validatieNietBevestigd
          : null;
    });
    if (_fout != null) return;
    if (keuze == null) {
      setState(() {
        _meldSoort = HhMeldSoort.informatie;
        _melding = TekstenAdresNl.nietsGewijzigd;
      });
      return;
    }
    setState(() => _isBezig = true);
    final result = await _sessie.bijwerkenUitgesteld(keuze.velden);
    if (!mounted) return;
    setState(() {
      _isBezig = false;
      switch (result) {
        case Ok<HhGebruiker>(:final waarde):
          _opgeslagen = waarde;
          _meldSoort = HhMeldSoort.geslaagd;
          _melding = TekstenAdresNl.opgeslagen;
          _isAangeraakt = false;
        case Err<HhGebruiker>(:final fout):
          _meldSoort = HhMeldSoort.fout;
          _melding = fout.melding;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final gebruiker = ref.watch(huidigeGebruikerProvider);
    final dichtheid = HhDichtheidScope.van(context);
    final tekst = Theme.of(context).textTheme;
    final tussen = HhRuimte.voor(HhRuimte.l, dichtheid);
    if (gebruiker == null) return const Scaffold();
    return HhScherm(
      titel: TekstenAdresNl.mijnAdresTitel,
      onTerug: () => terugOf(context, HhPaden.jongere),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_melding != null) ...[
            HhMeldBalk(soort: _meldSoort!, tekst: _melding!),
            SizedBox(height: tussen),
          ],
          Text(TekstenAdresNl.mijnAdresUitleg, style: tekst.bodyLarge),
          SizedBox(height: tussen),
          AdresZoeker(
            beginPostcode: isVolledigePostcode(gebruiker.postcode)
                ? normaliseerPostcode(gebruiker.postcode)
                : gebruiker.postcode,
            beginHuisnummer: gebruiker.huisnummer,
            zoekBijStart: true,
            isActief: !_isBezig,
            fouttekst: _fout,
            onGewijzigd: (keuze) => setState(() {
              _adres = keuze;
              _isAangeraakt = true;
            }),
          ),
          SizedBox(height: HhRuimte.voor(HhRuimte.xl, dichtheid)),
          HhKnop(
            label: TekstenNl.opslaan,
            icoon: Icons.save_outlined,
            isBezig: _isBezig,
            onPressed: _opslaan,
          ),
        ],
      ),
    );
  }
}
