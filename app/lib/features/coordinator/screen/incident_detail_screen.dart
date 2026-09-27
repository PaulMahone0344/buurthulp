import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/navigatie.dart';
import '../../../app/paden.dart';
import '../../../core/result.dart';
import '../../../design/components/hh_invoer.dart';
import '../../../design/components/hh_kaart.dart';
import '../../../design/components/hh_knop.dart';
import '../../../design/components/hh_lege_staat.dart';
import '../../../design/components/hh_meld_balk.dart';
import '../../../design/components/hh_scherm.dart';
import '../../../design/dichtheid_scope.dart';
import '../../../l10n/teksten_coordinator_nl.dart';
import '../../../theme.dart';
import '../../hulpvrager/provider/hulpvrager_providers.dart' show klokProvider;
import '../../jongere/klussen/domein/wanneer_tekst.dart' show wanneerTekst;
import '../../toegang/screen/hulp_screen.dart' show urlOpenerProvider;
import '../model/hh_incident.dart';
import '../paden_coordinator.dart';
import '../provider/coordinator_providers.dart';

/// C1-detail. Wie meldde het (met een belknop), bij welke klus, wat er is
/// gemeld, en het veld afhandeling met de knop "Afgehandeld". Een lege
/// afhandeling wordt geweigerd: dan weet niemand later wat er gebeurde.
class IncidentDetailScreen extends ConsumerStatefulWidget {
  const IncidentDetailScreen({required this.incidentId, super.key});

  final String incidentId;

  @override
  ConsumerState<IncidentDetailScreen> createState() =>
      _IncidentDetailScreenState();
}

class _IncidentDetailScreenState extends ConsumerState<IncidentDetailScreen> {
  final _afhandeling = TextEditingController();
  bool _isGevuld = false;
  bool _isBezig = false;
  bool _toonLeegFout = false;
  String? _melding;
  HhMeldSoort _meldSoort = HhMeldSoort.fout;

  @override
  void dispose() {
    _afhandeling.dispose();
    super.dispose();
  }

  /// De tekst die er al stond, één keer overnemen; daarna is het veld van
  /// de coordinator en mag een realtime-wijziging hem niet overschrijven.
  void _vulEenmalig(HhIncident incident) {
    if (_isGevuld) return;
    _isGevuld = true;
    _afhandeling.text = incident.afhandeling;
  }

  Future<void> _bel(String nummer) async {
    setState(() => _melding = null);
    final uri = Uri(scheme: 'tel', path: nummer);
    var gelukt = false;
    try {
      gelukt = await ref.read(urlOpenerProvider)(uri);
    } on Exception {
      gelukt = false;
    }
    if (!mounted || gelukt) return;
    setState(() {
      _meldSoort = HhMeldSoort.fout;
      _melding = TekstenCoordinatorNl.c1BellenLuktNiet(nummer);
    });
  }

  Future<void> _afhandelen() async {
    final tekst = _afhandeling.text.trim();
    if (tekst.isEmpty) {
      setState(() {
        _toonLeegFout = true;
        _melding = null;
      });
      return;
    }
    setState(() {
      _isBezig = true;
      _toonLeegFout = false;
      _melding = null;
    });
    final result = await ref
        .read(incidentenProvider.notifier)
        .handelAf(widget.incidentId, tekst);
    if (!mounted) return;
    setState(() {
      _isBezig = false;
      switch (result) {
        case Ok<HhIncident>():
          _meldSoort = HhMeldSoort.geslaagd;
          _melding = TekstenCoordinatorNl.c1Afgehandeld;
        case Err<HhIncident>(:final fout):
          _meldSoort = HhMeldSoort.fout;
          _melding = fout.melding;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final incident = ref.watch(incidentProvider(widget.incidentId));
    if (incident == null) {
      return HhScherm(
        titel: TekstenCoordinatorNl.c1DetailTitel,
        onTerug: () => terugOf(context, HhPaden.coordinator),
        child: const HhLegeStaat(
          icoon: Icons.search_off_outlined,
          titel: TekstenCoordinatorNl.c1DetailLadenMislukt,
          uitleg: TekstenCoordinatorNl.c1LegeOpenUitleg,
        ),
      );
    }
    _vulEenmalig(incident);

    final dichtheid = HhDichtheidScope.van(context);
    final tekst = Theme.of(context).textTheme;
    final tussen = HhRuimte.voor(HhRuimte.l, dichtheid);
    final klein = HhRuimte.voor(HhRuimte.s, dichtheid);
    final nu = ref.watch(klokProvider)();
    final stijl = hhStatusStijlen[HhKlusStatus.probleem]!;

    return HhScherm(
      titel: incident.soort.naam,
      onTerug: () => terugOf(context, HhPaden.coordinator),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (incident.isNood) ...[
            Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  size: HhMaten.icoonKeuzerij(dichtheid),
                  color: stijl.vulling,
                ),
                SizedBox(width: klein),
                Expanded(
                  child: Text(
                    TekstenCoordinatorNl.soortNood,
                    style: tekst.titleLarge!.copyWith(color: stijl.vulling),
                  ),
                ),
              ],
            ),
            SizedBox(height: tussen),
          ],
          if (_melding != null) ...[
            HhMeldBalk(soort: _meldSoort, tekst: _melding!),
            SizedBox(height: tussen),
          ],
          Text(
            wanneerTekst(incident.aangemaaktOp, null, nu),
            style: tekst.bodyMedium,
          ),
          SizedBox(height: tussen),
          HhKaart(
            kop: TekstenCoordinatorNl.c1MelderKop,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(incident.melderNaam, style: tekst.bodyLarge),
                SizedBox(height: klein),
                if (incident.heeftTelefoon) ...[
                  Text(incident.melderTelefoon, style: tekst.bodyLarge),
                  SizedBox(height: klein),
                  HhKnop(
                    label: TekstenCoordinatorNl.c1Bellen,
                    icoon: Icons.phone_outlined,
                    soort: HhKnopSoort.tweedeKeus,
                    semantiekLabel: TekstenCoordinatorNl.c1BellenSemantiek(
                      incident.melderNaam,
                      incident.melderTelefoon,
                    ),
                    onPressed: () => _bel(incident.melderTelefoon),
                  ),
                ] else
                  Text(
                    TekstenCoordinatorNl.c1GeenTelefoon,
                    style: tekst.bodyMedium,
                  ),
              ],
            ),
          ),
          SizedBox(height: tussen),
          HhKaart(
            kop: TekstenCoordinatorNl.c1KlusKop,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (incident.heeftKlus) ...[
                  Text(
                    incident.klusOmschrijving.isEmpty
                        ? TekstenCoordinatorNl.c2GeenToelichting
                        : incident.klusOmschrijving,
                    style: tekst.bodyLarge,
                  ),
                  SizedBox(height: klein),
                  HhKnop(
                    label: TekstenCoordinatorNl.c1NaarKlus,
                    icoon: Icons.arrow_forward,
                    soort: HhKnopSoort.tekst,
                    onPressed: () => context.go(
                      HhPadenCoordinator.klusDetail(incident.klusId),
                    ),
                  ),
                ] else
                  Text(
                    TekstenCoordinatorNl.c1GeenKlus,
                    style: tekst.bodyLarge,
                  ),
              ],
            ),
          ),
          SizedBox(height: tussen),
          HhKaart(
            kop: TekstenCoordinatorNl.c1OmschrijvingKop,
            child: Text(
              incident.omschrijving.isEmpty
                  ? TekstenCoordinatorNl.c1GeenOmschrijving
                  : incident.omschrijving,
              style: tekst.bodyLarge,
            ),
          ),
          SizedBox(height: tussen),
          HhKaart(
            kop: TekstenCoordinatorNl.c1AfhandelingKop,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                HhInvoer(
                  label: TekstenCoordinatorNl.c1AfhandelingLabel,
                  controller: _afhandeling,
                  hulptekst: TekstenCoordinatorNl.c1AfhandelingHulp,
                  fouttekst: _toonLeegFout
                      ? TekstenCoordinatorNl.c1AfhandelingLeeg
                      : null,
                  maxRegels: 4,
                  isActief: !_isBezig,
                  onChanged: (_) {
                    if (_toonLeegFout) setState(() => _toonLeegFout = false);
                  },
                ),
                SizedBox(height: tussen),
                HhKnop(
                  label: TekstenCoordinatorNl.c1Afhandelen,
                  icoon: Icons.check_circle_outline,
                  isBezig: _isBezig,
                  onPressed: _afhandelen,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
