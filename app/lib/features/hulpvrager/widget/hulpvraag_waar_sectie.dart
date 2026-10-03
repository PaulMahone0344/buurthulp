import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/hh_fout.dart';
import '../../../design/components/hh_invoer.dart';
import '../../../design/components/hh_knop.dart';
import '../../../design/components/hh_laad_staat.dart';
import '../../../design/components/hh_lege_staat.dart';
import '../../../design/components/hh_meld_balk.dart';
import '../../../design/dichtheid_scope.dart';
import '../../../l10n/teksten_hulpvrager_nl.dart';
import '../../../l10n/teksten_nl.dart';
import '../../../theme.dart';
import '../model/hh_gegevens.dart';
import '../paden_hulpvrager.dart';
import '../provider/concept_controller.dart';
import '../provider/hulpvrager_providers.dart';

/// Deel "Waar" van de hulpvraag-pagina (was O4). Het adres komt uit de
/// eigen gegevens (hh_users); staat het daar compleet, dan zijn er geen
/// adresvelden meer (3 okt), alleen de meerregelige toelichting. Elke wijziging gaat meteen in het concept. Zonder bekend
/// adres eerst naar Mijn gegevens. De microfoonknop staat er al, maar
/// uitgeschakeld: spraakinvoer komt later (OPEN-PUNTEN-M4).
class HulpvraagWaarSectie extends ConsumerStatefulWidget {
  const HulpvraagWaarSectie({required this.toonFouten, super.key});

  /// True na een tik op de plaatsknop: lege verplichte velden kleuren rood.
  final bool toonFouten;

  static const toelichtingRegels = 4;

  @override
  ConsumerState<HulpvraagWaarSectie> createState() =>
      _HulpvraagWaarSectieState();
}

class _HulpvraagWaarSectieState extends ConsumerState<HulpvraagWaarSectie> {
  final _adres = TextEditingController();
  final _postcode = TextEditingController();
  final _plaats = TextEditingController();
  final _toelichting = TextEditingController();
  bool _isVoorgevuld = false;

  /// Het adres staat al compleet in Mijn gegevens (of in het concept):
  /// dan geen adresvelden, alleen de toelichting (3 okt).
  bool _adresBekend = false;

  @override
  void initState() {
    super.initState();
    final concept = ref.read(conceptProvider);
    _toelichting.text = concept.toelichting;
    if (concept.adres != null) {
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
    _toelichting.dispose();
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
      if (mounted) _bewaar();
    });
  }

  void _bewaar([String _ = '']) {
    ref
        .read(conceptProvider.notifier)
        .zetWaar(
          adres: _adres.text,
          postcode: _postcode.text,
          plaats: _plaats.text,
          toelichting: _toelichting.text,
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
    final klein = HhRuimte.voor(HhRuimte.s, dichtheid);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _adresBekend
              ? TekstenHulpvragerNl.waarBekendUitleg
              : TekstenHulpvragerNl.waarUitleg,
          style: tekst.bodyLarge,
        ),
        SizedBox(height: tussen),
        if (!_adresBekend) ..._adresVelden(tussen),
        HhInvoer(
          label: TekstenHulpvragerNl.veldToelichting,
          controller: _toelichting,
          hulptekst: TekstenHulpvragerNl.veldToelichtingHulp,
          maxRegels: HulpvraagWaarSectie.toelichtingRegels,
          onChanged: _bewaar,
        ),
        SizedBox(height: klein),
        // Uitgeschakeld tot spraakinvoer er is; de schermlezer hoort waarom.
        const HhKnop(
          label: TekstenHulpvragerNl.waarInspreken,
          semantiekLabel: TekstenHulpvragerNl.waarInsprekenSemantiek,
          icoon: Icons.mic_none_outlined,
          soort: HhKnopSoort.tweedeKeus,
          onPressed: null,
        ),
      ],
    );
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
      textInputAction: TextInputAction.next,
      onChanged: _bewaar,
    ),
    SizedBox(height: tussen),
  ];
}
