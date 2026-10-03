import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/navigatie.dart';
import '../../../core/hh_fout.dart';
import '../../../core/pb/uitvoer_gateway.dart';
import '../../../design/components/hh_kaart.dart';
import '../../../design/components/hh_knop.dart';
import '../../../design/components/hh_laad_staat.dart';
import '../../../design/components/hh_lege_staat.dart';
import '../../../design/components/hh_meld_balk.dart';
import '../../../design/components/hh_scherm.dart';
import '../../../design/dichtheid_scope.dart';
import '../../../l10n/teksten_familie_nl.dart';
import '../../../l10n/teksten_nl.dart';
import '../../../l10n/teksten_uitvoeren_nl.dart';
import '../../../theme.dart';
import '../../hulpvrager/provider/hulpvrager_providers.dart' show klokProvider;
import '../domein/status_zin_familie.dart';
import '../../hulpvrager/status/widget/oudere_annuleer_dialoog.dart';
import '../../jongere/klussen/domein/wanneer_tekst.dart';
import '../../jongere/klussen/model/hh_klus.dart';
import '../../jongere/uitvoeren/domein/klus_overgang.dart';
import '../../jongere/uitvoeren/provider/uitvoeren_providers.dart';
import '../../jongere/uitvoeren/widget/persoon_regel.dart';
import '../../toegang/provider/sessie_providers.dart';
import '../paden_familie.dart';
import '../provider/familie_providers.dart';

/// F3-detail. Eén hulpvraag van de oudere, zoals O7 maar alleen-lezen: de
/// zin waar het staat, de jongere (naam en foto), wanneer en wat. Plus
/// "Hulpvraag stoppen" als ik hem zelf plaatste (de M6-route staat dat toe
/// voor geplaatst_door). Geen statusstappen, geen beoordelen, geen bellen.
class FamilieHulpvraagScreen extends ConsumerStatefulWidget {
  const FamilieHulpvraagScreen({
    required this.oudereId,
    required this.klusId,
    super.key,
  });

  final String oudereId;
  final String klusId;

  @override
  ConsumerState<FamilieHulpvraagScreen> createState() =>
      _FamilieHulpvraagScreenState();
}

class _FamilieHulpvraagScreenState
    extends ConsumerState<FamilieHulpvraagScreen> {
  bool _isBezig = false;
  String? _melding;
  HhMeldSoort _meldSoort = HhMeldSoort.informatie;

  void _terug() => terugOf(context, HhPadenFamilie.oudere(widget.oudereId));

  Future<void> _vernieuw() async {
    await ref.read(klusVolgerProvider(widget.klusId).notifier).vernieuw();
  }

  Future<void> _stop() async {
    final reden = await vraagOudereAnnuleerReden(context);
    if (reden == null || !mounted) return;
    setState(() {
      _isBezig = true;
      _melding = null;
    });
    final uitkomst = await ref.read(annuleerProvider)(widget.klusId, reden);
    if (!mounted) return;
    ref.invalidate(hulpvragenVanOudereProvider(widget.oudereId));
    setState(() {
      _isBezig = false;
      switch (uitkomst) {
        case UitvoerGelukt():
          _meldSoort = HhMeldSoort.geslaagd;
          _melding = TekstenFamilieNl.f3Geannuleerd;
        case UitvoerGeweigerd(:final melding):
          _meldSoort = HhMeldSoort.waarschuwing;
          _melding = melding ?? TekstenUitvoerenNl.annuleerMislukt;
        case UitvoerFout(:final fout):
          _meldSoort = HhMeldSoort.fout;
          _melding = fout.melding;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final stand = ref.watch(klusVolgerProvider(widget.klusId));
    final ikId = ref.watch(huidigeGebruikerProvider)?.id ?? '';
    final nu = ref.watch(klokProvider)();

    return switch (stand) {
      AsyncData<KlusMetGeschiedenis>(:final value) => _inhoud(
        value.klus,
        ikId,
        nu,
      ),
      AsyncError<KlusMetGeschiedenis>(:final error) => HhScherm(
        titel: TekstenFamilieNl.f3DetailTitel,
        toonTerug: true,
        onTerug: _terug,
        child: HhLegeStaat(
          icoon: Icons.cloud_off_outlined,
          titel: TekstenUitvoerenNl.o7LadenMislukt,
          uitleg: error is HhFout ? error.melding : TekstenNl.foutOnbekend,
          knopLabel: TekstenNl.opnieuwProberen,
          onKnop: _vernieuw,
        ),
      ),
      _ => HhScherm(
        titel: TekstenFamilieNl.f3DetailTitel,
        toonTerug: true,
        onTerug: _terug,
        child: const HhLaadStaat.skelet(regels: 3),
      ),
    };
  }

  Widget _inhoud(HhKlus klus, String ikId, DateTime nu) {
    final dichtheid = HhDichtheidScope.van(context);
    final tekst = Theme.of(context).textTheme;
    final tussen = HhRuimte.voor(HhRuimte.l, dichtheid);
    final doorMij = ikId.isNotEmpty && klus.geplaatstDoorId == ikId;
    final magStoppen = doorMij && magOudereAnnuleren(klus.status);
    final wanneer = wanneerTekst(klus.wanneerVan, klus.wanneerTot, nu);

    return HhScherm(
      titel: TekstenFamilieNl.f3DetailTitel,
      toonTerug: true,
      onTerug: _terug,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_melding != null) ...[
            HhMeldBalk(soort: _meldSoort, tekst: _melding!),
            SizedBox(height: tussen),
          ],
          Text(statusZinVoorFamilie(klus), style: tekst.headlineMedium),
          if (doorMij) ...[
            SizedBox(height: HhRuimte.voor(HhRuimte.s, dichtheid)),
            Text(TekstenFamilieNl.f3DoorMij, style: tekst.bodyMedium),
          ],
          SizedBox(height: tussen),
          if (klus.jongereVoornaam.isNotEmpty) ...[
            HhKaart(
              semantiekLabel: TekstenFamilieNl.f3Helper,
              child: PersoonRegel(
                naam: klus.jongereVoornaam,
                isIdGecontroleerd: klus.isJongereIdGecontroleerd,
                onderregel: TekstenFamilieNl.f3Helper,
              ),
            ),
            SizedBox(height: tussen),
          ],
          HhKaart(
            kop: TekstenUitvoerenNl.o7WanneerKop,
            child: Text(
              wanneer.isEmpty ? TekstenUitvoerenNl.o7GeenTijd : wanneer,
              style: tekst.bodyLarge,
            ),
          ),
          SizedBox(height: tussen),
          HhKaart(
            kop: TekstenUitvoerenNl.o7WatKop,
            child: Text(
              klus.omschrijving.isEmpty
                  ? metHoofdletter(klus.klustypeNaam)
                  : klus.omschrijving,
              style: tekst.bodyLarge,
            ),
          ),
          SizedBox(height: HhRuimte.voor(HhRuimte.xl, dichtheid)),
          if (magStoppen) ...[
            HhKnop(
              label: TekstenFamilieNl.f3Annuleren,
              semantiekLabel: TekstenFamilieNl.f3AnnulerenSemantiek,
              icoon: Icons.cancel_outlined,
              soort: HhKnopSoort.tweedeKeus,
              onPressed: _isBezig ? null : _stop,
            ),
            SizedBox(height: tussen),
          ],
          HhKnop(
            label: TekstenUitvoerenNl.o7Vernieuwen,
            icoon: Icons.refresh,
            soort: HhKnopSoort.tekst,
            onPressed: _vernieuw,
          ),
        ],
      ),
    );
  }
}
