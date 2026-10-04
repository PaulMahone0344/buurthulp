import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/pb/reactie_gateway.dart';
import '../../../core/result.dart';
import '../../../design/components/hh_invoer.dart';
import '../../../design/components/hh_kaart.dart';
import '../../../design/components/hh_knop.dart';
import '../../../design/components/hh_meld_balk.dart';
import '../../../design/dichtheid_scope.dart';
import '../../../l10n/teksten_reacties_nl.dart';
import '../../../theme.dart';
import '../../hulpvrager/provider/hulpvrager_providers.dart' show klokProvider;
import '../../jongere/klussen/model/hh_klus.dart';
import '../../jongere/klussen/provider/klussen_providers.dart';
import '../../jongere/model/hh_profiel.dart';
import '../../jongere/model/screening_stap.dart';
import '../../jongere/provider/screening_providers.dart';
import '../domein/reactie_regels.dart';
import '../model/hh_reactie.dart';
import '../paden_reacties.dart';
import '../provider/reactie_providers.dart';

/// HKlusBekijken (B5): onderaan de open klus. Nog niet gereageerd: een kort
/// berichtje (mag leeg, max 200), bij de eerste klus bij deze bewoner voor
/// 10-12 jaar het verplichte vinkje "Mijn ouder gaat mee" (13+ alleen een
/// tip), en de knop "Ik wil helpen". Al gereageerd: de stand en "Reactie
/// intrekken". De server beslist; een weigering toont zijn melding.
class ReageerBlok extends ConsumerStatefulWidget {
  const ReageerBlok({required this.klus, super.key});

  final HhKlus klus;

  @override
  ConsumerState<ReageerBlok> createState() => _ReageerBlokState();
}

class _ReageerBlokState extends ConsumerState<ReageerBlok> {
  final _bericht = TextEditingController();
  bool _ouderMee = false;
  bool _vraagOuderMee = false;
  bool _isBezig = false;
  String? _melding;
  HhMeldSoort _meldSoort = HhMeldSoort.fout;

  @override
  void dispose() {
    _bericht.dispose();
    super.dispose();
  }

  int? _leeftijd() {
    final account = switch (ref.watch(screeningControllerProvider)) {
      AsyncData<ScreeningGegevens>(:final value) => value.account,
      _ => const HhAccountGegevens(),
    };
    return leeftijdOp(account.geboortedatum, ref.watch(klokProvider)());
  }

  bool _isEerste() {
    final mijn = ref.watch(mijnKlussenProvider).value ?? const <HhKlus>[];
    return isEersteKlusBij(mijn, widget.klus.hulpvragerId);
  }

  Future<void> _reageer({required bool vinkjeNodig}) async {
    final tekst = _bericht.text.trim();
    if (tekst.length > 200) {
      setState(() {
        _melding = TekstenReactiesNl.berichtTeLang;
        _meldSoort = HhMeldSoort.fout;
      });
      return;
    }
    if (vinkjeNodig && !_ouderMee) {
      setState(() {
        _melding = TekstenReactiesNl.ouderMeeNodig;
        _meldSoort = HhMeldSoort.waarschuwing;
      });
      return;
    }
    setState(() {
      _isBezig = true;
      _melding = null;
    });
    final uitkomst = await ref.read(reageerProvider)(
      widget.klus.id,
      bericht: tekst,
      ouderGaatMee: _ouderMee,
    );
    if (!mounted) return;
    setState(() => _isBezig = false);
    switch (uitkomst) {
      case Gereageerd(:final status):
        context.push(
          HhPadenReacties.verstuurd(
            widget.klus.id,
            ouder: status == HhReactieStatus.wachtOpOuder,
          ),
        );
      case ReageerGeweigerd(:final melding) when uitkomst.vraagtOuderMee:
        setState(() {
          _vraagOuderMee = true;
          _melding = melding;
          _meldSoort = HhMeldSoort.waarschuwing;
        });
      // Antwoord Ibrahim 5: onder 18 nog dicht (tot de site online is). Geen
      // fout van het kind: een rustige, vriendelijke balk.
      case ReageerGeweigerd(:final melding) when uitkomst.isOnder18Dicht:
        setState(() {
          _melding = melding;
          _meldSoort = HhMeldSoort.informatie;
        });
      case ReageerGeweigerd(:final melding):
        setState(() {
          _melding = melding;
          _meldSoort = HhMeldSoort.fout;
        });
      case ReageerFout(:final fout):
        setState(() {
          _melding = fout.melding;
          _meldSoort = HhMeldSoort.fout;
        });
    }
  }

  Future<void> _trekIn(HhReactie reactie) async {
    final ja = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(TekstenReactiesNl.intrekkenVraag),
        content: const Text(TekstenReactiesNl.intrekkenUitleg),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(TekstenReactiesNl.intrekkenNee),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(TekstenReactiesNl.intrekkenJa),
          ),
        ],
      ),
    );
    if (ja != true || !mounted) return;
    setState(() => _isBezig = true);
    final result = await ref.read(intrekProvider)(reactie.id, widget.klus.id);
    if (!mounted) return;
    setState(() {
      _isBezig = false;
      switch (result) {
        case Ok<void>():
          _melding = TekstenReactiesNl.ingetrokken;
          _meldSoort = HhMeldSoort.geslaagd;
        case Err<void>(:final fout):
          _melding = fout.melding;
          _meldSoort = HhMeldSoort.fout;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final dichtheid = HhDichtheidScope.van(context);
    final tekst = Theme.of(context).textTheme;
    final tussen = HhRuimte.voor(HhRuimte.l, dichtheid);
    final klus = widget.klus;

    final mijn = HhReactieStatus.vanCode(klus.mijnReactie);
    final eigen = (ref.watch(mijnReactiesProvider).value ?? const <HhReactie>[])
        .where((r) => r.klusId == klus.id && r.status.isActief)
        .firstOrNull;
    final melding = _melding;

    // Al gereageerd (de server zegt het via mijn_reactie, of de eigen lijst).
    if (mijn.isActief || eigen != null) {
      final wachtOuder =
          mijn == HhReactieStatus.wachtOpOuder ||
          eigen?.status == HhReactieStatus.wachtOpOuder;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (melding != null) ...[
            HhMeldBalk(soort: _meldSoort, tekst: melding),
            SizedBox(height: tussen),
          ],
          HhKaart(
            kop: TekstenReactiesNl.gereageerdKop,
            child: Text(
              wachtOuder
                  ? TekstenReactiesNl.gereageerdOuder
                  : TekstenReactiesNl.gereageerdWacht,
              style: tekst.bodyLarge,
            ),
          ),
          if (eigen != null) ...[
            SizedBox(height: tussen),
            HhKnop(
              label: TekstenReactiesNl.intrekken,
              icoon: Icons.undo_rounded,
              soort: HhKnopSoort.tweedeKeus,
              isBezig: _isBezig,
              onPressed: () => _trekIn(eigen),
            ),
          ],
        ],
      );
    }

    if (!klus.isOpen) return const SizedBox.shrink();

    final leeftijd = _leeftijd();
    final eerste = _isEerste();
    final vinkjeNodig =
        _vraagOuderMee ||
        moetOuderMeeVinkje(leeftijd: leeftijd, isEerste: eerste);
    final tip = toonOuderMeeTip(leeftijd: leeftijd, isEerste: eerste);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (melding != null) ...[
          HhMeldBalk(soort: _meldSoort, tekst: melding),
          SizedBox(height: tussen),
        ],
        HhInvoer(
          label: TekstenReactiesNl.reageerKop,
          controller: _bericht,
          hulptekst: TekstenReactiesNl.reageerHint,
          maxRegels: 3,
          textCapitalization: TextCapitalization.sentences,
          inputFormatters: [LengthLimitingTextInputFormatter(200)],
        ),
        if (vinkjeNodig) ...[
          SizedBox(height: tussen),
          Text(TekstenReactiesNl.ouderMeeUitleg, style: tekst.bodyMedium),
          CheckboxListTile(
            value: _ouderMee,
            onChanged: (w) => setState(() => _ouderMee = w ?? false),
            title: Text(
              TekstenReactiesNl.ouderMeeVinkje,
              style: tekst.bodyLarge,
            ),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
          ),
        ] else if (tip) ...[
          SizedBox(height: tussen),
          const HhMeldBalk(
            soort: HhMeldSoort.informatie,
            tekst: TekstenReactiesNl.ouderMeeTip,
          ),
        ],
        SizedBox(height: tussen),
        HhKnop(
          label: TekstenReactiesNl.reageerKnop,
          icoon: Icons.check_circle_outline,
          isBezig: _isBezig,
          onPressed: () => _reageer(vinkjeNodig: vinkjeNodig),
        ),
        SizedBox(height: HhRuimte.voor(HhRuimte.s, dichtheid)),
        Text(
          klus.reactiesAantal > 0
              ? TekstenReactiesNl.alReacties(klus.reactiesAantal)
              : TekstenReactiesNl.reageerUitleg,
          textAlign: TextAlign.center,
          style: tekst.bodyMedium,
        ),
      ],
    );
  }
}
