import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/result.dart';
import '../../../design/components/hh_kaart.dart';
import '../../../design/components/hh_knop.dart';
import '../../../design/components/hh_meld_balk.dart';
import '../../../design/dichtheid_scope.dart';
import '../../../l10n/teksten_familie_nl.dart';
import '../../../theme.dart';
import '../../familie/model/hh_koppeling.dart';
import '../../familie/provider/familie_providers.dart';

/// Het blok "Familie" op O12 (M9). Een openstaande vraag met Ja / Nee
/// ("Karin de Vries wil met u meekijken ... Vindt u dat goed?"), en de
/// gekoppelde familie met "Ontkoppelen" (met een bevestigvraag).
/// Ouderenregel: grote knoppen, gewone taal, per vraag hooguit twee keuzes.
class FamilieToestemmingBlok extends ConsumerStatefulWidget {
  const FamilieToestemmingBlok({super.key});

  @override
  ConsumerState<FamilieToestemmingBlok> createState() =>
      _FamilieToestemmingBlokState();
}

class _FamilieToestemmingBlokState
    extends ConsumerState<FamilieToestemmingBlok> {
  String? _bezigMet;
  String? _melding;
  HhMeldSoort _meldSoort = HhMeldSoort.geslaagd;

  Future<void> _doe(
    String koppelingId,
    Future<Result<Object?>> Function() actie,
    String gelukt,
  ) async {
    setState(() {
      _bezigMet = koppelingId;
      _melding = null;
    });
    final result = await actie();
    if (!mounted) return;
    ref.invalidate(familieVanMijProvider);
    setState(() {
      _bezigMet = null;
      switch (result) {
        case Ok():
          _meldSoort = HhMeldSoort.geslaagd;
          _melding = gelukt;
        case Err(:final fout):
          _meldSoort = HhMeldSoort.fout;
          _melding = fout.melding;
      }
    });
  }

  Future<void> _ja(HhKoppeling k) => _doe(
    k.id,
    () => ref.read(familieGatewayProvider).geefToestemming(k.id),
    TekstenFamilieNl.o12JaGelukt,
  );

  Future<void> _nee(HhKoppeling k) => _doe(
    k.id,
    () => ref.read(familieGatewayProvider).verwijder(k.id),
    TekstenFamilieNl.o12NeeGelukt,
  );

  Future<void> _ontkoppel(HhKoppeling k, String naam) async {
    final zeker = await showDialog<bool>(
      context: context,
      builder: (context) => _OntkoppelVraag(naam: naam),
    );
    if (zeker != true || !mounted) return;
    await _doe(
      k.id,
      () => ref.read(familieGatewayProvider).verwijder(k.id),
      TekstenFamilieNl.o12OntkoppeldGelukt,
    );
  }

  @override
  Widget build(BuildContext context) {
    final stand = ref.watch(familieVanMijProvider);
    final dichtheid = HhDichtheidScope.van(context);
    final tekst = Theme.of(context).textTheme;
    final tussen = HhRuimte.voor(HhRuimte.l, dichtheid);
    final klein = HhRuimte.voor(HhRuimte.s, dichtheid);

    final lijst = stand.value;
    final List<Widget> inhoud;
    if (lijst == null) {
      inhoud = [
        if (stand.hasError)
          Text(TekstenFamilieNl.o12LadenMislukt, style: tekst.bodyLarge),
      ];
    } else if (lijst.isEmpty) {
      inhoud = [Text(TekstenFamilieNl.o12Niemand, style: tekst.bodyLarge)];
    } else {
      inhoud = [
        for (final k in lijst) ...[
          if (k != lijst.first) SizedBox(height: tussen),
          ..._regel(k, tekst, klein),
        ],
      ];
    }

    return HhKaart(
      kop: TekstenFamilieNl.o12Kop,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_melding != null) ...[
            HhMeldBalk(soort: _meldSoort, tekst: _melding!),
            SizedBox(height: klein),
          ],
          ...inhoud,
        ],
      ),
    );
  }

  List<Widget> _regel(HhKoppeling k, TextTheme tekst, double klein) {
    final naam = k.familielidNaam.isEmpty
        ? TekstenFamilieNl.onbekendeNaam
        : k.familielidNaam;
    final isBezig = _bezigMet == k.id;
    if (!k.isActief) {
      return [
        Text(TekstenFamilieNl.o12Vraag(naam), style: tekst.bodyLarge),
        SizedBox(height: klein),
        HhKnop(
          label: TekstenFamilieNl.o12Ja,
          icoon: Icons.check,
          isBezig: isBezig,
          onPressed: () => _ja(k),
        ),
        SizedBox(height: klein),
        HhKnop(
          label: TekstenFamilieNl.o12Nee,
          icoon: Icons.close,
          soort: HhKnopSoort.tweedeKeus,
          onPressed: isBezig ? null : () => _nee(k),
        ),
      ];
    }
    return [
      Text(TekstenFamilieNl.o12Gekoppeld(naam), style: tekst.bodyLarge),
      SizedBox(height: klein),
      HhKnop(
        label: TekstenFamilieNl.o12Ontkoppelen,
        semantiekLabel: TekstenFamilieNl.o12OntkoppelenSemantiek(naam),
        icoon: Icons.link_off,
        soort: HhKnopSoort.tweedeKeus,
        isBezig: isBezig,
        onPressed: () => _ontkoppel(k, naam),
      ),
    ];
  }
}

class _OntkoppelVraag extends StatelessWidget {
  const _OntkoppelVraag({required this.naam});

  final String naam;

  @override
  Widget build(BuildContext context) {
    final dichtheid = HhDichtheidScope.van(context);
    final tekst = Theme.of(context).textTheme;
    final klein = HhRuimte.voor(HhRuimte.s, dichtheid);
    return AlertDialog(
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              TekstenFamilieNl.o12OntkoppelVraag(naam),
              style: tekst.titleLarge,
            ),
            SizedBox(height: HhRuimte.voor(HhRuimte.l, dichtheid)),
            HhKnop(
              label: TekstenFamilieNl.o12OntkoppelJa,
              soort: HhKnopSoort.gevaar,
              onPressed: () => Navigator.of(context).pop(true),
            ),
            SizedBox(height: klein),
            HhKnop(
              label: TekstenFamilieNl.o12OntkoppelNee,
              soort: HhKnopSoort.tweedeKeus,
              onPressed: () => Navigator.of(context).pop(false),
            ),
          ],
        ),
      ),
    );
  }
}
