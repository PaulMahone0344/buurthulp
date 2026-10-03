import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/paden.dart';
import '../../../../core/pb/ouder_gateway.dart';
import '../../../../design/components/hh_invoer.dart';
import '../../../../design/components/hh_knop.dart';
import '../../../../design/components/hh_meld_balk.dart';
import '../../../../design/components/hh_scherm.dart';
import '../../../../design/dichtheid_scope.dart';
import '../../../../l10n/teksten_ouder_nl.dart';
import '../../../../theme.dart';
import '../../../toegang/validatie.dart';
import '../../../toegang/widget/aanmeld_stappen.dart';
import '../../model/hh_screening_status.dart';
import '../../model/screening_stap.dart';
import '../../paden_jongere.dart';
import '../../provider/screening_providers.dart';
import '../../widget/screening_lader.dart';
import '../model/hh_ouder_stand.dart';

/// B3, stap "Ouder" (mockup HAanmelden, zonder code-vakjes: de OUDER vult
/// de code in op de website, K2). "We hebben je ouder een mail gestuurd.
/// Wacht op toestemming." met "Stuur opnieuw" en "E-mailadres van je ouder
/// wijzigen". Staat er nog geen mail uit en is het adres bekend, dan gaat
/// hij bij het openen meteen (eenmalig). Alleen een telefoonnummer bij
/// aanmelden (K1): eerst "Vul ook het e-mailadres van je ouder in".
/// Mag het kind zelf (opnieuw) mailen? Niet na toestemming, en niet na
/// intrekken: dan eerst de meldkamer (antwoord Ibrahim 4 okt).
bool magZelfMailen(HhOuderStand stand) =>
    stand.status != HhOuderStatus.gegeven &&
    stand.status != HhOuderStatus.ingetrokken;

class OuderScreen extends ConsumerStatefulWidget {
  const OuderScreen({super.key});

  @override
  ConsumerState<OuderScreen> createState() => _OuderScreenState();
}

class _OuderScreenState extends ConsumerState<OuderScreen> {
  final _email = TextEditingController();
  bool _isBezig = false;
  bool _isAutoGedaan = false;
  bool _wijzigt = false;
  String? _fout;
  String? _melding;
  HhMeldSoort _meldSoort = HhMeldSoort.fout;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _stuur({String? nieuwAdres}) async {
    if (nieuwAdres != null) {
      final fout = valideerEmail(nieuwAdres);
      setState(
        () => _fout = fout == null ? null : TekstenOuderNl.emailOngeldig,
      );
      if (fout != null) return;
    }
    setState(() {
      _isBezig = true;
      _melding = null;
    });
    final uitkomst = await ref
        .read(screeningControllerProvider.notifier)
        .stuurOuderMail(ouderEmail: nieuwAdres?.trim());
    if (!mounted) return;
    setState(() {
      _isBezig = false;
      switch (uitkomst) {
        case OuderVerstuurd():
          _meldSoort = HhMeldSoort.geslaagd;
          _melding = TekstenOuderNl.gelukt;
          _wijzigt = false;
          _email.clear();
        case OuderGeweigerd(:final melding):
          _meldSoort = HhMeldSoort.fout;
          _melding = melding;
        case OuderVerstuurFout(:final fout):
          _meldSoort = HhMeldSoort.fout;
          _melding = fout.melding;
      }
    });
  }

  /// Eenmalig bij het openen: nog niets verstuurd en het adres is bekend.
  void _misschienAutomatisch(HhOuderStand? stand) {
    if (_isAutoGedaan || stand == null) return;
    if (stand.status != HhOuderStatus.geen || stand.ouderEmail.isEmpty) return;
    if (!stand.kanOpnieuw) return;
    _isAutoGedaan = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _stuur();
    });
  }

  @override
  Widget build(BuildContext context) {
    return HhScherm(
      titel: TekstenOuderNl.titel,
      child: ScreeningLader(
        builder: (context, gegevens) {
          _misschienAutomatisch(gegevens.ouder);
          return _inhoud(context, gegevens);
        },
      ),
    );
  }

  Widget _inhoud(BuildContext context, ScreeningGegevens gegevens) {
    final dichtheid = HhDichtheidScope.van(context);
    final tekst = Theme.of(context).textTheme;
    final tussen = HhRuimte.voor(HhRuimte.l, dichtheid);
    final klein = HhRuimte.voor(HhRuimte.s, dichtheid);
    final stand = gegevens.ouder ?? const HhOuderStand();
    final zonderAdres =
        stand.status == HhOuderStatus.geen && stand.ouderEmail.isEmpty;
    final isNieuw = gegevens.verificatiestatus == HhScreeningStatus.nieuw;
    final toonFormulier = zonderAdres || _wijzigt;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AanmeldStappen(huidig: AanmeldStap.ouder, metOuder: true),
        SizedBox(height: tussen),
        Semantics(
          header: true,
          child: Text(TekstenOuderNl.kop, style: tekst.headlineMedium),
        ),
        SizedBox(height: klein),
        Text(TekstenOuderNl.intro, style: tekst.bodyLarge),
        SizedBox(height: tussen),
        ..._stand(context, stand, zonderAdres),
        if (toonFormulier) ...[
          SizedBox(height: tussen),
          HhInvoer(
            label: TekstenOuderNl.emailLabel,
            controller: _email,
            hulptekst: TekstenOuderNl.emailHulp,
            fouttekst: _fout,
            isVerplicht: true,
            isActief: !_isBezig,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => _stuur(nieuwAdres: _email.text),
          ),
          SizedBox(height: klein),
          HhKnop(
            label: zonderAdres
                ? TekstenOuderNl.stuur
                : TekstenOuderNl.stuurNaarNieuw,
            icoon: Icons.send_outlined,
            isBezig: _isBezig,
            onPressed: stand.kanOpnieuw
                ? () => _stuur(nieuwAdres: _email.text)
                : null,
          ),
          if (_wijzigt)
            HhKnop(
              label: TekstenOuderNl.annuleren,
              soort: HhKnopSoort.tekst,
              onPressed: _isBezig
                  ? null
                  : () => setState(() {
                      _wijzigt = false;
                      _fout = null;
                    }),
            ),
        ],
        if (!toonFormulier && magZelfMailen(stand)) ...[
          SizedBox(height: tussen),
          HhKnop(
            label: TekstenOuderNl.opnieuw,
            icoon: Icons.refresh,
            soort:
                stand.wachtOpNieuweCode ||
                    stand.status == HhOuderStatus.ingetrokken
                ? HhKnopSoort.primair
                : HhKnopSoort.tweedeKeus,
            isBezig: _isBezig,
            onPressed: stand.kanOpnieuw ? () => _stuur() : null,
          ),
          HhKnop(
            label: TekstenOuderNl.wijzig,
            icoon: Icons.edit_outlined,
            soort: HhKnopSoort.tekst,
            onPressed: _isBezig || !stand.kanOpnieuw
                ? null
                : () => setState(() => _wijzigt = true),
          ),
        ],
        if (!toonFormulier && magZelfMailen(stand)) ...[
          SizedBox(height: klein),
          Text(
            stand.kanOpnieuw
                ? TekstenOuderNl.nogVandaag(stand.nogTeSturen)
                : TekstenOuderNl.geenMeerVandaag,
            style: tekst.bodyMedium,
          ),
        ],
        if (_melding != null) ...[
          SizedBox(height: tussen),
          HhMeldBalk(soort: _meldSoort, tekst: _melding!),
        ],
        SizedBox(height: HhRuimte.voor(HhRuimte.xl, dichtheid)),
        HhKnop(
          label: isNieuw
              ? TekstenOuderNl.verderAanmelding
              : TekstenOuderNl.naarStart,
          icoon: Icons.arrow_forward,
          soort: zonderAdres ? HhKnopSoort.tekst : HhKnopSoort.primair,
          onPressed: () =>
              context.go(isNieuw ? HhPadenJongere.overzicht : HhPaden.jongere),
        ),
      ],
    );
  }

  /// De kaart met de stand: verstuurd, verlopen, gegeven of ingetrokken.
  List<Widget> _stand(
    BuildContext context,
    HhOuderStand stand,
    bool zonderAdres,
  ) {
    if (zonderAdres) {
      return [
        const HhMeldBalk(
          soort: HhMeldSoort.informatie,
          tekst:
              '${TekstenOuderNl.alleenTelefoonKop}. '
              '${TekstenOuderNl.alleenTelefoonUitleg}',
        ),
      ];
    }
    final (soort, regels) = switch (stand.status) {
      HhOuderStatus.gegeven => (
        HhMeldSoort.geslaagd,
        [TekstenOuderNl.gegevenKop, TekstenOuderNl.gegevenUitleg],
      ),
      HhOuderStatus.ingetrokken => (
        HhMeldSoort.waarschuwing,
        [TekstenOuderNl.ingetrokkenKop, TekstenOuderNl.ingetrokkenUitleg],
      ),
      _ when stand.wachtOpNieuweCode => (
        HhMeldSoort.waarschuwing,
        [TekstenOuderNl.verlopenKop, TekstenOuderNl.verlopenUitleg],
      ),
      HhOuderStatus.geen => (HhMeldSoort.informatie, [TekstenOuderNl.bezig]),
      _ => (
        HhMeldSoort.informatie,
        [
          TekstenOuderNl.verstuurdKop,
          TekstenOuderNl.verstuurdUitleg,
          if (stand.ouderEmail.isNotEmpty)
            TekstenOuderNl.naarAdres(stand.ouderEmail),
          if (stand.verstuurdOp != null)
            TekstenOuderNl.verstuurdOm(_tijd(stand.verstuurdOp!)),
        ],
      ),
    };
    return [HhMeldBalk(soort: soort, tekst: regels.join('\n'))];
  }

  static String _tijd(DateTime moment) {
    final lokaal = moment.toLocal();
    String twee(int n) => n.toString().padLeft(2, '0');
    return '${twee(lokaal.hour)}:${twee(lokaal.minute)}';
  }
}
