import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/hh_fout.dart';
import '../../../design/components/hh_invoer.dart';
import '../../../design/components/hh_keuzerij.dart';
import '../../../design/components/hh_knop.dart';
import '../../../design/components/hh_laad_staat.dart';
import '../../../design/components/hh_lege_staat.dart';
import '../../../design/components/hh_meld_balk.dart';
import '../../../design/dichtheid_scope.dart';
import '../../../l10n/teksten_hulpvrager_nl.dart';
import '../../../l10n/teksten_klus_nl.dart';
import '../../../l10n/teksten_nl.dart';
import '../../../theme.dart';
import '../../adres/domein/adres_invoer.dart';
import '../../adres/model/hh_adres.dart';
import '../../adres/widget/adres_zoeker.dart';
import '../domein/adres.dart';
import '../model/hh_gegevens.dart';
import '../paden_hulpvrager.dart';
import '../provider/concept_controller.dart';
import '../provider/hulpvrager_providers.dart';

/// "Waar?" op "Klus plaatsen". Het adres komt uit Mijn gegevens (B2) en
/// wordt niet opnieuw gevraagd (B4): staat het daar compleet, dan alleen
/// één regel "Bij jou thuis: ...". Zonder bekend adres eerst naar Mijn
/// gegevens. Elke wijziging gaat meteen in het concept.
///
/// Feedbackronde 1 punt B: met een bekend adres kiest de bewoner "Bij mij
/// thuis" of "Ergens anders". Ergens anders gaat met postcode en huisnummer
/// via PDOK, net als Mijn gegevens; de server zoekt er zelf het punt bij.
class HulpvraagWaarSectie extends ConsumerStatefulWidget {
  const HulpvraagWaarSectie({required this.toonFouten, super.key});

  /// True na een tik op de plaatsknop: lege verplichte velden kleuren rood.
  final bool toonFouten;

  @override
  ConsumerState<HulpvraagWaarSectie> createState() =>
      _HulpvraagWaarSectieState();
}

class _HulpvraagWaarSectieState extends ConsumerState<HulpvraagWaarSectie> {
  final _adres = TextEditingController();
  final _postcode = TextEditingController();
  final _plaats = TextEditingController();
  bool _isVoorgevuld = false;

  /// Het adres staat al compleet in Mijn gegevens (of in het concept):
  /// dan geen adresvelden, alleen de toelichting (3 okt).
  bool _adresBekend = false;

  /// Punt B: "Ergens anders" gekozen, met het gevonden adres (binnen het
  /// werkgebied) of null.
  bool _isElders = false;
  HhAdres? _eldersAdres;

  @override
  void initState() {
    super.initState();
    final concept = ref.read(conceptProvider);
    _isElders = concept.isElders;
    _eldersAdres = concept.eldersAdres;
    // Bij "Ergens anders" komt het eigen adres gewoon weer uit de gegevens.
    if (concept.adres != null && !concept.isElders) {
      _adres.text = concept.adres!;
      _postcode.text = concept.postcode ?? '';
      _plaats.text = concept.plaats ?? '';
      _isVoorgevuld = true;
      _adresBekend = concept.heeftWaar;
    }
  }

  @override
  void dispose() {
    _adres.dispose();
    _postcode.dispose();
    _plaats.dispose();
    super.dispose();
  }

  /// Eerste keer: het adres uit de eigen gegevens, meteen in het concept.
  void _vulVoor(HhGegevens gegevens) {
    if (_isVoorgevuld) return;
    _isVoorgevuld = true;
    _adres.text = gegevens.adres;
    _postcode.text = gegevens.postcode;
    _plaats.text = gegevens.plaats;
    _adresBekend = gegevens.heeftAdres;
    // Na de build: een provider wijzigen tijdens het bouwen mag niet.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_isElders) _bewaar();
    });
  }

  void _kiesElders(bool elders) {
    setState(() => _isElders = elders);
    if (elders) {
      ref.read(conceptProvider.notifier).zetElders(_eldersAdres);
    } else {
      _bewaar();
    }
  }

  /// Alleen een gevonden adres binnen het werkgebied telt; de zoeker meldt
  /// zelf "nog niet in jouw buurt".
  void _eldersGewijzigd(AdresKeuze? keuze) {
    final adres = keuze?.adres;
    _eldersAdres = adres != null && adres.binnenWerkgebied ? adres : null;
    ref.read(conceptProvider.notifier).zetElders(_eldersAdres);
  }

  void _bewaar([String _ = '']) {
    ref
        .read(conceptProvider.notifier)
        .zetWaar(
          adres: _adres.text,
          postcode: _postcode.text,
          plaats: _plaats.text,
        );
  }

  String? _fout(TextEditingController veld, String melding) =>
      widget.toonFouten && veld.text.trim().isEmpty ? melding : null;

  @override
  Widget build(BuildContext context) {
    final gegevens = ref.watch(gegevensProvider);
    final tussen = HhRuimte.voor(HhRuimte.l, HhDichtheidScope.van(context));

    return switch (gegevens) {
      AsyncData(:final value) when !_isVoorgevuld && !value.heeftAdres =>
        HhLegeStaat(
          icoon: Icons.home_outlined,
          titel: TekstenHulpvragerNl.waarGeenAdresTitel,
          uitleg: TekstenHulpvragerNl.waarGeenAdresUitleg,
          knopLabel: TekstenHulpvragerNl.waarGeenAdresKnop,
          onKnop: () => context.push(HhPadenHulpvrager.gegevens),
        ),
      AsyncData(:final value) => _formulier(value),
      AsyncError(:final error) when !_isVoorgevuld => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          HhMeldBalk(
            soort: HhMeldSoort.fout,
            tekst: error is HhFout ? error.melding : TekstenNl.foutOnbekend,
          ),
          SizedBox(height: tussen),
          HhKnop(
            label: TekstenNl.opnieuwProberen,
            soort: HhKnopSoort.tweedeKeus,
            onPressed: () => ref.invalidate(gegevensProvider),
          ),
        ],
      ),
      AsyncError() => _formulier(null),
      _ when _isVoorgevuld => _formulier(null),
      _ => const HhLaadStaat.skelet(
        regels: 2,
        label: TekstenHulpvragerNl.waarLaden,
      ),
    };
  }

  Widget _formulier(HhGegevens? gegevens) {
    if (gegevens != null) _vulVoor(gegevens);
    final dichtheid = HhDichtheidScope.van(context);
    final tekst = Theme.of(context).textTheme;
    final tussen = HhRuimte.voor(HhRuimte.l, dichtheid);

    if (_adresBekend) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          HhKeuzerij<bool>(
            semantiekLabel: TekstenKlusNl.waarKeuzeLabel,
            keuzes: const [
              HhKeuze(
                waarde: false,
                label: TekstenKlusNl.waarThuis,
                semantiekLabel: TekstenKlusNl.waarThuisSemantiek,
                icoon: Icons.home_outlined,
              ),
              HhKeuze(
                waarde: true,
                label: TekstenKlusNl.waarElders,
                semantiekLabel: TekstenKlusNl.waarEldersSemantiek,
                icoon: Icons.place_outlined,
              ),
            ],
            geselecteerd: {_isElders},
            onGewijzigd: (keuze) => _kiesElders(keuze.first),
          ),
          SizedBox(height: tussen),
          ...(_isElders ? _elders(tekst) : _thuis(tekst, dichtheid)),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(TekstenKlusNl.waarUitleg, style: tekst.bodyLarge),
        SizedBox(height: tussen),
        ..._adresVelden(tussen),
      ],
    );
  }

  List<Widget> _thuis(TextTheme tekst, HhDichtheid dichtheid) {
    final adres = stelAdresSamen(
      adres: _adres.text,
      postcode: _postcode.text,
      plaats: _plaats.text,
    );
    return [
      Text(
        TekstenKlusNl.waarAdres(adres),
        style: tekst.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
      SizedBox(height: HhRuimte.voor(HhRuimte.xs, dichtheid)),
      Text(TekstenKlusNl.waarAnders, style: tekst.bodyMedium),
    ];
  }

  List<Widget> _elders(TextTheme tekst) {
    final begin = _eldersAdres;
    return [
      Text(TekstenKlusNl.waarEldersUitleg, style: tekst.bodyLarge),
      SizedBox(
        height: HhRuimte.voor(HhRuimte.s, HhDichtheidScope.van(context)),
      ),
      AdresZoeker(
        beginPostcode: begin?.postcode ?? '',
        beginHuisnummer: begin?.huisnummer ?? '',
        beginToevoeging: begin?.toevoeging ?? '',
        beginWeergave: begin?.weergave,
        fouttekst: widget.toonFouten && begin == null
            ? TekstenKlusNl.waarEldersFout
            : null,
        onGewijzigd: _eldersGewijzigd,
      ),
    ];
  }

  /// Straat, postcode en plaats; alleen als het adres nog niet bekend is.
  List<Widget> _adresVelden(double tussen) => [
    HhInvoer(
      label: TekstenHulpvragerNl.veldAdres,
      controller: _adres,
      isVerplicht: true,
      fouttekst: _fout(_adres, TekstenHulpvragerNl.validatieAdres),
      autofillHints: const [AutofillHints.streetAddressLine1],
      textInputAction: TextInputAction.next,
      onChanged: _bewaar,
    ),
    SizedBox(height: tussen),
    HhInvoer(
      label: TekstenHulpvragerNl.veldPostcode,
      controller: _postcode,
      isVerplicht: true,
      fouttekst: _fout(_postcode, TekstenHulpvragerNl.validatiePostcode),
      autofillHints: const [AutofillHints.postalCode],
      textInputAction: TextInputAction.next,
      onChanged: _bewaar,
    ),
    SizedBox(height: tussen),
    HhInvoer(
      label: TekstenHulpvragerNl.veldPlaats,
      controller: _plaats,
      isVerplicht: true,
      fouttekst: _fout(_plaats, TekstenHulpvragerNl.validatiePlaats),
      autofillHints: const [AutofillHints.addressCity],
      textInputAction: TextInputAction.done,
      onChanged: _bewaar,
    ),
  ];
}
