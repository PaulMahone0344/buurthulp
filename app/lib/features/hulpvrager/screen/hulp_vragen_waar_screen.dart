import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/navigatie.dart';
import '../../../core/hh_fout.dart';
import '../../../design/components/hh_invoer.dart';
import '../../../design/components/hh_knop.dart';
import '../../../design/components/hh_laad_staat.dart';
import '../../../design/components/hh_lege_staat.dart';
import '../../../design/components/hh_meld_balk.dart';
import '../../../design/components/hh_scherm.dart';
import '../../../design/components/hh_stapbalk.dart';
import '../../../design/dichtheid_scope.dart';
import '../../../l10n/teksten_hulpvrager_nl.dart';
import '../../../l10n/teksten_nl.dart';
import '../../../theme.dart';
import '../model/hh_gegevens.dart';
import '../paden_hulpvrager.dart';
import '../provider/concept_controller.dart';
import '../provider/hulpvrager_providers.dart';

/// O4, stap 3 van 4: waar en toelichting. Het adres komt uit de eigen
/// gegevens (hh_users) en is te bewerken; de toelichting is meerregelig.
/// Zonder bekend adres eerst O12 als tussenstap. De microfoonknop staat
/// er al, maar uitgeschakeld: spraakinvoer komt later (OPEN-PUNTEN-M4).
class HulpVragenWaarScreen extends ConsumerStatefulWidget {
  const HulpVragenWaarScreen({super.key});

  static const toelichtingRegels = 4;

  @override
  ConsumerState<HulpVragenWaarScreen> createState() =>
      _HulpVragenWaarScreenState();
}

class _HulpVragenWaarScreenState extends ConsumerState<HulpVragenWaarScreen> {
  final _adres = TextEditingController();
  final _postcode = TextEditingController();
  final _plaats = TextEditingController();
  final _toelichting = TextEditingController();
  bool _isVoorgevuld = false;
  String? _adresFout;
  String? _postcodeFout;
  String? _plaatsFout;

  @override
  void initState() {
    super.initState();
    // Terug-navigatie: wat de oudere al invulde staat in het concept.
    final concept = ref.read(conceptProvider);
    _toelichting.text = concept.toelichting;
    if (concept.adres != null) {
      _adres.text = concept.adres!;
      _postcode.text = concept.postcode ?? '';
      _plaats.text = concept.plaats ?? '';
      _isVoorgevuld = true;
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

  /// Eerste keer op dit scherm: het adres uit de eigen gegevens.
  void _vulVoor(HhGegevens gegevens) {
    if (_isVoorgevuld) return;
    _isVoorgevuld = true;
    _adres.text = gegevens.adres;
    _postcode.text = gegevens.postcode;
    _plaats.text = gegevens.plaats;
  }

  void _bewaar() {
    ref
        .read(conceptProvider.notifier)
        .zetWaar(
          adres: _adres.text,
          postcode: _postcode.text,
          plaats: _plaats.text,
          toelichting: _toelichting.text,
        );
  }

  void _terug() {
    _bewaar();
    terugOf(context, HhPadenHulpvrager.hulpVragenWanneer);
  }

  void _verder() {
    setState(() {
      _adresFout = _adres.text.trim().isEmpty
          ? TekstenHulpvragerNl.validatieAdres
          : null;
      _postcodeFout = _postcode.text.trim().isEmpty
          ? TekstenHulpvragerNl.validatiePostcode
          : null;
      _plaatsFout = _plaats.text.trim().isEmpty
          ? TekstenHulpvragerNl.validatiePlaats
          : null;
    });
    if (_adresFout != null || _postcodeFout != null || _plaatsFout != null) {
      return;
    }
    _bewaar();
    context.push(HhPadenHulpvrager.hulpVragenBevestigen);
  }

  @override
  Widget build(BuildContext context) {
    final gegevens = ref.watch(gegevensProvider);
    final dichtheid = HhDichtheidScope.van(context);
    final tekst = Theme.of(context).textTheme;
    final tussen = HhRuimte.voor(HhRuimte.l, dichtheid);

    return HhScherm(
      titel: TekstenHulpvragerNl.waarTitel,
      onTerug: _terug,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const HhStapbalk(
            stap: 3,
            totaal: TekstenHulpvragerNl.stappenTotaal,
            titel: TekstenHulpvragerNl.stapWaar,
          ),
          SizedBox(height: tussen),
          switch (gegevens) {
            AsyncData(:final value) when !_isVoorgevuld && !value.heeftAdres =>
              HhLegeStaat(
                icoon: Icons.home_outlined,
                titel: TekstenHulpvragerNl.waarGeenAdresTitel,
                uitleg: TekstenHulpvragerNl.waarGeenAdresUitleg,
                knopLabel: TekstenHulpvragerNl.waarGeenAdresKnop,
                onKnop: () => context.push(HhPadenHulpvrager.gegevens),
              ),
            AsyncData(:final value) => _formulier(value, tekst, dichtheid),
            AsyncError(:final error) when !_isVoorgevuld => Column(
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
            AsyncError() => _formulier(null, tekst, dichtheid),
            _ when _isVoorgevuld => _formulier(null, tekst, dichtheid),
            _ => const HhLaadStaat.skelet(
              regels: 2,
              label: TekstenHulpvragerNl.waarLaden,
            ),
          },
        ],
      ),
    );
  }

  Widget _formulier(HhGegevens? gegevens, TextTheme tekst, HhDichtheid d) {
    if (gegevens != null) _vulVoor(gegevens);
    final tussen = HhRuimte.voor(HhRuimte.l, d);
    final klein = HhRuimte.voor(HhRuimte.s, d);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(TekstenHulpvragerNl.waarUitleg, style: tekst.bodyLarge),
        SizedBox(height: tussen),
        HhInvoer(
          label: TekstenHulpvragerNl.veldAdres,
          controller: _adres,
          isVerplicht: true,
          fouttekst: _adresFout,
          autofillHints: const [AutofillHints.streetAddressLine1],
          textInputAction: TextInputAction.next,
        ),
        SizedBox(height: tussen),
        HhInvoer(
          label: TekstenHulpvragerNl.veldPostcode,
          controller: _postcode,
          isVerplicht: true,
          fouttekst: _postcodeFout,
          autofillHints: const [AutofillHints.postalCode],
          textInputAction: TextInputAction.next,
        ),
        SizedBox(height: tussen),
        HhInvoer(
          label: TekstenHulpvragerNl.veldPlaats,
          controller: _plaats,
          isVerplicht: true,
          fouttekst: _plaatsFout,
          autofillHints: const [AutofillHints.addressCity],
          textInputAction: TextInputAction.next,
        ),
        SizedBox(height: tussen),
        HhInvoer(
          label: TekstenHulpvragerNl.veldToelichting,
          controller: _toelichting,
          hulptekst: TekstenHulpvragerNl.veldToelichtingHulp,
          maxRegels: HulpVragenWaarScreen.toelichtingRegels,
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
        SizedBox(height: HhRuimte.voor(HhRuimte.xl, d)),
        HhKnop(
          label: TekstenNl.verder,
          icoon: Icons.arrow_forward,
          onPressed: _verder,
        ),
      ],
    );
  }
}
