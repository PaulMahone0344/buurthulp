import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/navigatie.dart';
import '../../../core/pb/coordinator_gateway.dart';
import '../../../design/components/hh_kaart.dart';
import '../../../design/components/hh_laad_staat.dart';
import '../../../design/components/hh_lege_staat.dart';
import '../../../design/components/hh_meld_balk.dart';
import '../../../design/components/hh_scherm.dart';
import '../../../design/dichtheid_scope.dart';
import '../../../l10n/teksten_coordinator_nl.dart';
import '../../../l10n/teksten_nl.dart';
import '../../../theme.dart';
import '../../hulpvrager/provider/hulpvrager_providers.dart' show klokProvider;
import '../../jongere/klussen/domein/wanneer_tekst.dart'
    show metHoofdletter, wanneerTekst;
import '../../jongere/klussen/widget/klus_status_pil.dart';
import '../../jongere/provider/screening_providers.dart' show meldingVanFout;
import '../model/hh_coordinator_klus.dart';
import '../model/hh_kandidaat.dart';
import '../paden_coordinator.dart';
import '../provider/coordinator_providers.dart';
import '../widget/kandidaat_lijst.dart';
import '../widget/vrijgeef_blok.dart';

/// C2-detail. Alles van de klus, en daaronder de actie die erbij hoort:
/// een open klus koppel je aan een jongere, een toegewezen klus geef je
/// vrij met een reden. Allebei via de hook-routes, nooit via een
/// record-update, zodat de logregel altijd klopt.
class CoordinatorKlusDetailScreen extends ConsumerStatefulWidget {
  const CoordinatorKlusDetailScreen({required this.klusId, super.key});

  final String klusId;

  @override
  ConsumerState<CoordinatorKlusDetailScreen> createState() =>
      _CoordinatorKlusDetailScreenState();
}

class _CoordinatorKlusDetailScreenState
    extends ConsumerState<CoordinatorKlusDetailScreen> {
  bool _isBezig = false;
  String? _melding;
  HhMeldSoort _meldSoort = HhMeldSoort.fout;

  /// Vraagt om een bevestiging, met bij een andere wijk de waarschuwing
  /// erbij. Geeft true als de coordinator doorzet.
  Future<bool> _bevestig({
    required String titel,
    required String vraag,
    required String knop,
    String? waarschuwing,
  }) async {
    final ja = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(titel),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(vraag),
            if (waarschuwing != null) ...[
              SizedBox(
                height: HhRuimte.voor(
                  HhRuimte.l,
                  HhDichtheidScope.van(context),
                ),
              ),
              HhMeldBalk(
                soort: HhMeldSoort.waarschuwing,
                tekst: waarschuwing,
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(TekstenNl.annuleren),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(knop),
          ),
        ],
      ),
    );
    return ja ?? false;
  }

  Future<void> _koppel(HhCoordinatorKlus klus, HhKandidaat kandidaat) async {
    final anderWijk =
        kandidaat.heeftWijk &&
        klus.oudereWijkId.isNotEmpty &&
        kandidaat.wijkId != klus.oudereWijkId;
    final door = await _bevestig(
      titel: TekstenCoordinatorNl.c2BevestigTitel,
      vraag: TekstenCoordinatorNl.c2BevestigVraag(kandidaat.naam),
      knop: TekstenCoordinatorNl.c2BevestigKoppelen,
      waarschuwing: anderWijk
          ? TekstenCoordinatorNl.c2AndereWijkWaarschuwing(
              kandidaat.wijkNaam.isEmpty
                  ? TekstenCoordinatorNl.c2GeenWijk
                  : kandidaat.wijkNaam,
              klus.oudereWijkNaam.isEmpty
                  ? TekstenCoordinatorNl.c2GeenWijk
                  : klus.oudereWijkNaam,
            )
          : null,
    );
    if (!door || !mounted) return;

    setState(() {
      _isBezig = true;
      _melding = null;
    });
    final uitkomst = await ref.read(koppelProvider)(klus.id, kandidaat.id);
    if (!mounted) return;
    setState(() {
      _isBezig = false;
      switch (uitkomst) {
        case KoppelGelukt():
          _meldSoort = HhMeldSoort.geslaagd;
          _melding = TekstenCoordinatorNl.c2Gekoppeld(kandidaat.naam);
        case KoppelGeweigerd(:final reden, :final melding):
          _meldSoort = HhMeldSoort.fout;
          _melding = melding ?? _tekstVoor(reden);
        case KoppelFout(:final fout):
          _meldSoort = HhMeldSoort.fout;
          _melding = fout.melding;
      }
    });
    if (uitkomst is KoppelGelukt) {
      ref.read(kandidaatZoekProvider.notifier).wis();
    }
  }

  Future<void> _geefVrij(HhCoordinatorKlus klus, String reden) async {
    final door = await _bevestig(
      titel: TekstenCoordinatorNl.c2VrijgevenTitel,
      vraag: TekstenCoordinatorNl.c2VrijgevenVraag(
        klus.toegewezenJongereNaam,
      ),
      knop: TekstenCoordinatorNl.c2BevestigVrijgeven,
    );
    if (!door || !mounted) return;

    setState(() {
      _isBezig = true;
      _melding = null;
    });
    final uitkomst = await ref.read(vrijgeefProvider)(klus.id, reden);
    if (!mounted) return;
    setState(() {
      _isBezig = false;
      switch (uitkomst) {
        case KoppelGelukt():
          _meldSoort = HhMeldSoort.geslaagd;
          _melding = TekstenCoordinatorNl.c2Vrijgegeven;
        case KoppelGeweigerd(:final reden, :final melding):
          _meldSoort = HhMeldSoort.fout;
          _melding = melding ?? _tekstVoor(reden);
        case KoppelFout(:final fout):
          _meldSoort = HhMeldSoort.fout;
          _melding = fout.melding;
      }
    });
  }

  static String _tekstVoor(KoppelReden reden) => switch (reden) {
    KoppelReden.bezet => TekstenCoordinatorNl.c2KoppelenBezet,
    KoppelReden.jongereNietGeschikt =>
      TekstenCoordinatorNl.c2KoppelenNietGoedgekeurd,
    KoppelReden.nietVrijTeGeven =>
      TekstenCoordinatorNl.c2VrijgevenNietMogelijk,
    KoppelReden.geenToegang => TekstenCoordinatorNl.c2KoppelenGeenToegang,
    KoppelReden.nietGevonden => TekstenCoordinatorNl.c2KoppelenNietGevonden,
    KoppelReden.ongeldigeInvoer => TekstenCoordinatorNl.c2KoppelenGeenJongere,
  };

  @override
  Widget build(BuildContext context) {
    final stand = ref.watch(coordinatorKlusProvider(widget.klusId));

    return switch (stand) {
      AsyncData<HhCoordinatorKlus>(:final value) => _Detail(
        klus: value,
        nu: ref.watch(klokProvider)(),
        isBezig: _isBezig,
        melding: _melding,
        meldSoort: _meldSoort,
        onKoppel: (kandidaat) => _koppel(value, kandidaat),
        onVrijgeven: (reden) => _geefVrij(value, reden),
      ),
      AsyncError<HhCoordinatorKlus>(:final error) => HhScherm(
        titel: TekstenCoordinatorNl.c2DetailTitel,
        onTerug: () => terugOf(context, HhPadenCoordinator.klussen),
        child: HhLegeStaat(
          icoon: Icons.cloud_off_outlined,
          titel: TekstenCoordinatorNl.c2DetailLadenMislukt,
          uitleg: meldingVanFout(error),
          knopLabel: TekstenNl.opnieuwProberen,
          onKnop: () =>
              ref.invalidate(coordinatorKlusProvider(widget.klusId)),
        ),
      ),
      _ => HhScherm(
        titel: TekstenCoordinatorNl.c2DetailTitel,
        onTerug: () => terugOf(context, HhPadenCoordinator.klussen),
        child: const HhLaadStaat.skelet(regels: 4),
      ),
    };
  }
}

class _Detail extends StatelessWidget {
  const _Detail({
    required this.klus,
    required this.nu,
    required this.isBezig,
    required this.melding,
    required this.meldSoort,
    required this.onKoppel,
    required this.onVrijgeven,
  });

  final HhCoordinatorKlus klus;
  final DateTime nu;
  final bool isBezig;
  final String? melding;
  final HhMeldSoort meldSoort;
  final void Function(HhKandidaat) onKoppel;
  final void Function(String) onVrijgeven;

  @override
  Widget build(BuildContext context) {
    final dichtheid = HhDichtheidScope.van(context);
    final tekst = Theme.of(context).textTheme;
    final tussen = HhRuimte.voor(HhRuimte.l, dichtheid);
    final klein = HhRuimte.voor(HhRuimte.s, dichtheid);

    return HhScherm(
      titel: metHoofdletter(klus.klustypeNaam),
      onTerug: () => terugOf(context, HhPadenCoordinator.klussen),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: KlusStatusPil(status: klus.status),
          ),
          SizedBox(height: tussen),
          if (melding != null) ...[
            HhMeldBalk(soort: meldSoort, tekst: melding!),
            SizedBox(height: tussen),
          ],
          HhKaart(
            kop: TekstenCoordinatorNl.c2VoorWieKop,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(klus.oudereNaam, style: tekst.bodyLarge),
                SizedBox(height: klein),
                Text(
                  klus.oudereWijkNaam.isEmpty
                      ? TekstenCoordinatorNl.c2GeenWijk
                      : klus.oudereWijkNaam,
                  style: tekst.bodyMedium,
                ),
              ],
            ),
          ),
          SizedBox(height: tussen),
          HhKaart(
            kop: TekstenCoordinatorNl.c2WaarKop,
            child: Text(
              klus.adres.isEmpty
                  ? TekstenCoordinatorNl.c2GeenAdres
                  : klus.adres,
              style: tekst.bodyLarge,
            ),
          ),
          SizedBox(height: tussen),
          HhKaart(
            kop: TekstenCoordinatorNl.c2WanneerKop,
            child: Text(
              wanneerTekst(klus.wanneerVan, klus.wanneerTot, nu),
              style: tekst.bodyLarge,
            ),
          ),
          SizedBox(height: tussen),
          HhKaart(
            kop: TekstenCoordinatorNl.c2ToelichtingKop,
            child: Text(
              klus.omschrijving.isEmpty
                  ? TekstenCoordinatorNl.c2GeenToelichting
                  : klus.omschrijving,
              style: tekst.bodyLarge,
            ),
          ),
          SizedBox(height: tussen),
          if (klus.toegewezenJongereId.isNotEmpty) ...[
            HhKaart(
              kop: TekstenCoordinatorNl.c2ToegewezenKop,
              child: Text(
                klus.toegewezenJongereNaam,
                style: tekst.bodyLarge,
              ),
            ),
            SizedBox(height: tussen),
          ],
          if (klus.isOpen)
            KandidaatLijst(
              wijkId: klus.oudereWijkId,
              isBezig: isBezig,
              onKies: onKoppel,
            )
          else if (klus.isVrijTeGeven)
            VrijgeefBlok(isBezig: isBezig, onVrijgeven: onVrijgeven),
        ],
      ),
    );
  }
}
