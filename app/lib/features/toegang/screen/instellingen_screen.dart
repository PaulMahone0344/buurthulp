import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/navigatie.dart';
import '../../../core/result.dart';
import '../../../design/components/hh_kaart.dart';
import '../../../design/components/hh_keuzerij.dart';
import '../../../design/components/hh_knop.dart';
import '../../../design/components/hh_meld_balk.dart';
import '../../../design/components/hh_scherm.dart';
import '../../../design/dichtheid_scope.dart';
import '../../../l10n/teksten_nl.dart';
import '../../../theme.dart';
import '../model/hh_gebruiker.dart';
import '../provider/meldingen_voorkeur.dart';
import '../provider/sessie_providers.dart';
import '../../../app/dichtheid_controller.dart';

/// G7. Taal (alleen opslaan in hh_users.taal), meldingen (alleen lokaal
/// opslaan, geen push), uitloggen en account wissen met bevestiging.
/// Bij een wijziging gaat alleen het gewijzigde veld naar de server.
class InstellingenScreen extends ConsumerStatefulWidget {
  const InstellingenScreen({super.key});

  @override
  ConsumerState<InstellingenScreen> createState() => _InstellingenScreenState();
}

class _InstellingenScreenState extends ConsumerState<InstellingenScreen> {
  static const _talen = [
    HhKeuze(
      waarde: HhTaal.nl,
      label: TekstenNl.taalNederlands,
      icoon: Icons.language,
    ),
    HhKeuze(
      waarde: HhTaal.ar,
      label: TekstenNl.taalArabisch,
      icoon: Icons.language,
    ),
    HhKeuze(
      waarde: HhTaal.tr,
      label: TekstenNl.taalTurks,
      icoon: Icons.language,
    ),
    HhKeuze(
      waarde: HhTaal.en,
      label: TekstenNl.taalEngels,
      icoon: Icons.language,
    ),
  ];

  bool _isBezig = false;
  HhMeldSoort? _meldSoort;
  String? _melding;

  Future<void> _zetTaal(HhTaal taal) async {
    setState(() {
      _isBezig = true;
      _melding = null;
    });
    final result = await ref.read(sessieControllerProvider.notifier).bijwerken({
      'taal': taal.code,
    });
    if (!mounted) return;
    setState(() {
      _isBezig = false;
      _toonResultaat(result, TekstenNl.instellingenOpgeslagen);
    });
  }

  void _toonResultaat(Result<void> result, String geslaagd) {
    switch (result) {
      case Ok<void>():
        _meldSoort = HhMeldSoort.geslaagd;
        _melding = geslaagd;
      case Err<void>(:final fout):
        _meldSoort = HhMeldSoort.fout;
        _melding = fout.melding;
    }
  }

  Future<void> _uitloggen() async {
    setState(() => _isBezig = true);
    await ref.read(sessieControllerProvider.notifier).uitloggen();
    // De router-guard brengt de gebruiker naar G2.
  }

  Future<void> _accountWissen() async {
    final bevestigd = await showDialog<bool>(
      context: context,
      builder: (context) => const _WisBevestiging(),
    );
    if (bevestigd != true || !mounted) return;

    setState(() {
      _isBezig = true;
      _melding = null;
    });
    final result = await ref
        .read(sessieControllerProvider.notifier)
        .accountWissen();
    if (!mounted) return;
    setState(() {
      _isBezig = false;
      if (result case Err<void>(:final fout)) {
        _meldSoort = HhMeldSoort.fout;
        _melding = fout.melding;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final gebruiker = ref.watch(huidigeGebruikerProvider);
    final meldingenAan = ref.watch(meldingenVoorkeurProvider);
    final groteLetters = ref.watch(groteLettersProvider);
    final dichtheid = HhDichtheidScope.van(context);
    final tekst = Theme.of(context).textTheme;
    final tussen = HhRuimte.voor(HhRuimte.l, dichtheid);

    if (gebruiker == null) return const Scaffold();

    return HhScherm(
      titel: TekstenNl.instellingenTitel,
      onTerug: () => terugOf(context, gebruiker.rol.pad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_melding != null) ...[
            HhMeldBalk(soort: _meldSoort!, tekst: _melding!),
            SizedBox(height: tussen),
          ],
          HhKaart(
            kop: TekstenNl.instellingenTaal,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                HhKeuzerij<HhTaal>(
                  semantiekLabel: TekstenNl.instellingenTaal,
                  keuzes: _talen,
                  geselecteerd: {gebruiker.taal},
                  onGewijzigd: _isBezig
                      ? null
                      : (keuze) => _zetTaal(keuze.first),
                ),
                SizedBox(height: HhRuimte.voor(HhRuimte.s, dichtheid)),
                Text(TekstenNl.instellingenTaalHulp, style: tekst.bodyMedium),
              ],
            ),
          ),
          SizedBox(height: tussen),
          HhKaart(
            kop: TekstenNl.instellingenLetters,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MergeSemantics(
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          TekstenNl.instellingenLettersSchakelaar,
                          style: tekst.bodyLarge,
                        ),
                      ),
                      Switch(
                        value: groteLetters,
                        onChanged: (aan) =>
                            ref.read(groteLettersProvider.notifier).zet(aan),
                      ),
                    ],
                  ),
                ),
                Text(
                  TekstenNl.instellingenLettersHulp,
                  style: tekst.bodyMedium,
                ),
              ],
            ),
          ),
          SizedBox(height: tussen),
          HhKaart(
            kop: TekstenNl.instellingenMeldingen,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MergeSemantics(
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          TekstenNl.instellingenMeldingenSchakelaar,
                          style: tekst.bodyLarge,
                        ),
                      ),
                      Switch(
                        value: meldingenAan,
                        onChanged: (aan) => ref
                            .read(meldingenVoorkeurProvider.notifier)
                            .zet(aan),
                      ),
                    ],
                  ),
                ),
                Text(
                  TekstenNl.instellingenMeldingenHulp,
                  style: tekst.bodyMedium,
                ),
              ],
            ),
          ),
          SizedBox(height: tussen),
          HhKaart(
            kop: TekstenNl.instellingenAccount,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                HhKnop(
                  label: TekstenNl.uitloggen,
                  icoon: Icons.logout,
                  soort: HhKnopSoort.tweedeKeus,
                  onPressed: _isBezig ? null : _uitloggen,
                ),
                SizedBox(height: HhRuimte.voor(HhRuimte.s, dichtheid)),
                HhKnop(
                  label: TekstenNl.accountWissen,
                  icoon: Icons.delete_outline,
                  soort: HhKnopSoort.gevaar,
                  onPressed: _isBezig ? null : _accountWissen,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Bevestiging voor het wissen: het is onomkeerbaar, dus een echte vraag
/// met de veilige keuze als eerste knop.
class _WisBevestiging extends StatelessWidget {
  const _WisBevestiging();

  @override
  Widget build(BuildContext context) {
    final dichtheid = HhDichtheidScope.van(context);
    final tekst = Theme.of(context).textTheme;

    return AlertDialog(
      title: Text(TekstenNl.accountWissenVraag, style: tekst.titleLarge),
      content: Text(TekstenNl.accountWissenUitleg, style: tekst.bodyLarge),
      actionsAlignment: MainAxisAlignment.start,
      actions: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            HhKnop(
              label: TekstenNl.annuleren,
              soort: HhKnopSoort.tweedeKeus,
              onPressed: () => Navigator.of(context).pop(false),
            ),
            SizedBox(height: HhRuimte.voor(HhRuimte.s, dichtheid)),
            HhKnop(
              label: TekstenNl.accountWissenBevestig,
              soort: HhKnopSoort.gevaar,
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        ),
      ],
    );
  }
}
