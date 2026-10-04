import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/result.dart';
import '../../../design/components/hh_kaart.dart';
import '../../../design/components/hh_knop.dart';
import '../../../design/components/hh_laad_staat.dart';
import '../../../design/components/hh_lege_staat.dart';
import '../../../design/components/hh_meld_balk.dart';
import '../../../design/components/hh_scherm.dart';
import '../../../design/dichtheid_scope.dart';
import '../../../l10n/teksten_meldkamer_nl.dart';
import '../../../l10n/teksten_nl.dart';
import '../../../theme.dart';
import '../../hulpvrager/provider/hulpvrager_providers.dart' show klokProvider;
import '../../jongere/klussen/domein/wanneer_tekst.dart'
    show metHoofdletter, wanneerTekst;
import '../../jongere/provider/screening_providers.dart' show meldingVanFout;
import '../../reacties/domein/reactie_regels.dart' show leeftijdOp;
import '../../toegang/screen/hulp_screen.dart' show urlOpenerProvider;
import '../model/hh_te_doen.dart';
import '../provider/te_doen_providers.dart';
import '../widget/coordinator_tabbalk.dart';
import '../widget/notitie_dialoog.dart';

/// B11: "Te doen" van de meldkamer. Alleen wat je onderweg snel doet
/// (besluit Ibrahim 4 okt): bewoners bellen voor de kennismaking, helpers
/// keuren, een ouder-toestemming vrijgeven en klussen keuren. Lijsten en
/// instellingen staan in het webpaneel.
class CoordinatorTeDoenScreen extends ConsumerStatefulWidget {
  const CoordinatorTeDoenScreen({super.key});

  @override
  ConsumerState<CoordinatorTeDoenScreen> createState() => _TeDoenState();
}

class _TeDoenState extends ConsumerState<CoordinatorTeDoenScreen> {
  String? _melding;
  HhMeldSoort _soort = HhMeldSoort.geslaagd;

  TeDoenController get _controller => ref.read(teDoenProvider.notifier);

  void _toon<T>(Result<T> result, String gelukt) {
    if (!mounted) return;
    setState(() {
      switch (result) {
        case Ok<T>():
          _melding = gelukt;
          _soort = HhMeldSoort.geslaagd;
        case Err<T>(:final fout):
          _melding = fout.melding;
          _soort = HhMeldSoort.fout;
      }
    });
  }

  Future<void> _gesproken(HhTeBellen b) async {
    final notitie = await vraagNotitie(
      context,
      titel: TekstenMeldkamerNl.gesprokenTitel(b.naam),
      bevestig: TekstenMeldkamerNl.gesproken,
      label: TekstenMeldkamerNl.notitieOptioneel,
    );
    if (notitie == null) return;
    final r = await _controller.kennismaking(
      b.id,
      KennismakingBesluit.gesproken,
      notitie,
    );
    _toon(r, TekstenMeldkamerNl.gesprokenGelukt(b.naam));
  }

  Future<void> _weigeren(HhTeBellen b) async {
    final notitie = await vraagNotitie(
      context,
      titel: TekstenMeldkamerNl.weigerenTitel(b.naam),
      bevestig: TekstenMeldkamerNl.weigeren,
      label: TekstenMeldkamerNl.notitieVerplicht,
      uitleg: TekstenMeldkamerNl.weigerenUitleg,
      isVerplicht: true,
      isGevaar: true,
    );
    if (notitie == null) return;
    final r = await _controller.kennismaking(
      b.id,
      KennismakingBesluit.geweigerd,
      notitie,
    );
    final geannuleerd = switch (r) {
      Ok<KennismakingUitkomst>(:final waarde) => waarde.geannuleerd,
      Err() => 0,
    };
    _toon(r, TekstenMeldkamerNl.geweigerdGelukt(b.naam, geannuleerd));
  }

  Future<void> _bel(HhTeBellen b) async {
    final nummer = b.telefoon.replaceAll(RegExp(r'[^\d+]'), '');
    try {
      await ref.read(urlOpenerProvider)(Uri.parse('tel:$nummer'));
    } on Exception {
      // Geen telefoon-app (tablet, simulator): het nummer staat er al.
    }
  }

  Future<void> _helper(HhTeKeurenHelper h, {required bool goedkeuren}) async {
    final notitie = await vraagNotitie(
      context,
      titel: goedkeuren
          ? TekstenMeldkamerNl.goedkeurenTitel(h.naam)
          : TekstenMeldkamerNl.afwijzenTitel(h.naam),
      bevestig: goedkeuren
          ? TekstenMeldkamerNl.goedkeuren
          : TekstenMeldkamerNl.afwijzen,
      label: TekstenMeldkamerNl.notitieVerplicht,
      uitleg: goedkeuren ? null : TekstenMeldkamerNl.afwijzenUitleg,
      beginTekst: goedkeuren
          ? TekstenMeldkamerNl.goedkeurenStandaardNotitie
          : '',
      isVerplicht: true,
      isGevaar: !goedkeuren,
    );
    if (notitie == null) return;
    final r = await _controller.beoordeelHelper(
      h.profielId,
      goedkeuren: goedkeuren,
      notitie: notitie,
    );
    _toon(r, TekstenMeldkamerNl.helperGelukt(h.naam, goedgekeurd: goedkeuren));
  }

  Future<void> _ouder(HhOuderIngetrokken o) async {
    final ok = await vraagBevestiging(
      context,
      titel: TekstenMeldkamerNl.vrijgevenTitel(o.naam),
      uitleg: TekstenMeldkamerNl.oudersUitleg,
      bevestig: TekstenMeldkamerNl.vrijgeven,
    );
    if (!ok) return;
    final r = await _controller.ouderVrijgeven(o.helperId);
    _toon(r, TekstenMeldkamerNl.vrijgevenGelukt(o.naam));
  }

  Future<void> _goedkeurenKlus(HhTeKeurenKlus k) async {
    final r = await _controller.keurKlus(k.id, goedkeuren: true);
    _toon(r, TekstenMeldkamerNl.klusGoedgekeurd);
  }

  Future<void> _afkeurenKlus(HhTeKeurenKlus k) async {
    final reden = await vraagNotitie(
      context,
      titel: TekstenMeldkamerNl.afkeurenTitel(metHoofdletter(k.soort)),
      bevestig: TekstenMeldkamerNl.afkeuren,
      label: TekstenMeldkamerNl.reden,
      uitleg: TekstenMeldkamerNl.afkeurenUitleg,
      isVerplicht: true,
      minLengte: 5,
      maxLengte: 300,
      isGevaar: true,
    );
    if (reden == null) return;
    final r = await _controller.keurKlus(k.id, goedkeuren: false, reden: reden);
    _toon(r, TekstenMeldkamerNl.klusAfgekeurd);
  }

  @override
  Widget build(BuildContext context) {
    final stand = ref.watch(teDoenProvider);
    final nu = ref.watch(klokProvider)();
    final dichtheid = HhDichtheidScope.van(context);
    final rand = HhRuimte.voor(HhRuimte.l, dichtheid);
    final tussen = HhRuimte.voor(HhRuimte.m, dichtheid);

    final inhoud = switch (stand) {
      AsyncData<HhTeDoen>(:final value) when value.isLeeg => const [
        HhLegeStaat(
          icoon: Icons.task_alt_outlined,
          titel: TekstenMeldkamerNl.legeTitel,
          uitleg: TekstenMeldkamerNl.legeUitleg,
        ),
      ],
      AsyncData<HhTeDoen>(:final value) => _lijsten(value, nu, tussen),
      AsyncError<HhTeDoen>(:final error) => [
        HhLegeStaat(
          icoon: Icons.cloud_off_outlined,
          titel: TekstenMeldkamerNl.ladenMislukt,
          uitleg: meldingVanFout(error),
          knopLabel: TekstenNl.opnieuwProberen,
          onKnop: _controller.vernieuw,
        ),
      ],
      _ => const [HhLaadStaat.skelet(regels: 3)],
    };

    return CoordinatorTabScherm(
      actief: CoordinatorTab.teDoen,
      child: HhScherm(
        titel: TekstenMeldkamerNl.titel,
        toonTerug: false,
        scrollbaar: false,
        child: RefreshIndicator(
          onRefresh: _controller.vernieuw,
          color: Theme.of(context).colorScheme.primary,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              rand,
              0,
              rand,
              HhRuimte.voor(HhRuimte.xl, dichtheid),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_melding != null) ...[
                  HhMeldBalk(soort: _soort, tekst: _melding!),
                  SizedBox(height: tussen),
                ],
                ...inhoud,
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _lijsten(HhTeDoen t, DateTime nu, double tussen) {
    return [
      if (t.bellen.isNotEmpty)
        ..._sectie(
          TekstenMeldkamerNl.bellenKop,
          TekstenMeldkamerNl.bellenUitleg,
          [
            for (final b in t.bellen)
              _BelKaart(
                b: b,
                opBel: _bel,
                opGesproken: _gesproken,
                opWeigeren: _weigeren,
              ),
          ],
          tussen,
        ),
      if (t.helpers.isNotEmpty)
        ..._sectie(TekstenMeldkamerNl.helpersKop, null, [
          for (final h in t.helpers)
            _HelperKaart(h: h, nu: nu, opBesluit: _helper),
        ], tussen),
      if (t.ouders.isNotEmpty)
        ..._sectie(
          TekstenMeldkamerNl.oudersKop,
          TekstenMeldkamerNl.oudersUitleg,
          [
            for (final o in t.ouders)
              HhKaart(
                kop: o.naam,
                child: HhKnop(
                  label: TekstenMeldkamerNl.vrijgeven,
                  soort: HhKnopSoort.tweedeKeus,
                  onPressed: () => _ouder(o),
                ),
              ),
          ],
          tussen,
        ),
      if (t.klussen.isNotEmpty)
        ..._sectie(
          TekstenMeldkamerNl.klussenKop,
          TekstenMeldkamerNl.klussenUitleg,
          [
            for (final k in t.klussen)
              _KlusKaart(
                k: k,
                nu: nu,
                opGoedkeuren: _goedkeurenKlus,
                opAfkeuren: _afkeurenKlus,
              ),
          ],
          tussen,
        ),
    ];
  }

  List<Widget> _sectie(
    String kop,
    String? uitleg,
    List<Widget> kaarten,
    double tussen,
  ) {
    final tekst = Theme.of(context).textTheme;
    return [
      Semantics(header: true, child: Text(kop, style: tekst.titleLarge)),
      if (uitleg != null) ...[
        SizedBox(height: tussen / 2),
        Text(uitleg, style: tekst.bodyMedium),
      ],
      SizedBox(height: tussen),
      for (final kaart in kaarten) ...[kaart, SizedBox(height: tussen)],
      SizedBox(height: tussen),
    ];
  }
}

class _BelKaart extends StatelessWidget {
  const _BelKaart({
    required this.b,
    required this.opBel,
    required this.opGesproken,
    required this.opWeigeren,
  });

  final HhTeBellen b;
  final Future<void> Function(HhTeBellen) opBel;
  final Future<void> Function(HhTeBellen) opGesproken;
  final Future<void> Function(HhTeBellen) opWeigeren;

  @override
  Widget build(BuildContext context) {
    final tekst = Theme.of(context).textTheme;
    final klein = HhRuimte.voor(HhRuimte.s, HhDichtheidScope.van(context));
    return HhKaart(
      kop: b.naam,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            [
              if (b.telefoon.isEmpty)
                TekstenMeldkamerNl.geenTelefoon
              else
                b.telefoon,
              if (b.plaats.isNotEmpty) b.plaats,
            ].join(' · '),
            style: tekst.bodyLarge,
          ),
          SizedBox(height: klein),
          if (b.telefoon.isNotEmpty) ...[
            HhKnop(
              label: TekstenMeldkamerNl.bel,
              icoon: Icons.phone_outlined,
              semantiekLabel: TekstenMeldkamerNl.belSemantiek(b.naam),
              onPressed: () => opBel(b),
            ),
            SizedBox(height: klein),
          ],
          HhKnop(
            label: TekstenMeldkamerNl.gesproken,
            soort: HhKnopSoort.tweedeKeus,
            onPressed: () => opGesproken(b),
          ),
          SizedBox(height: klein),
          HhKnop(
            label: TekstenMeldkamerNl.weigeren,
            soort: HhKnopSoort.tekst,
            onPressed: () => opWeigeren(b),
          ),
        ],
      ),
    );
  }
}

class _HelperKaart extends StatelessWidget {
  const _HelperKaart({
    required this.h,
    required this.nu,
    required this.opBesluit,
  });

  final HhTeKeurenHelper h;
  final DateTime nu;
  final Future<void> Function(HhTeKeurenHelper, {required bool goedkeuren})
  opBesluit;

  @override
  Widget build(BuildContext context) {
    final tekst = Theme.of(context).textTheme;
    final klein = HhRuimte.voor(HhRuimte.s, HhDichtheidScope.van(context));
    final jaren = leeftijdOp(h.geboortedatum, nu);
    return HhKaart(
      kop: h.naam,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (jaren != null)
            Text(
              TekstenMeldkamerNl.helperLeeftijd(jaren),
              style: tekst.bodyLarge,
            ),
          SizedBox(height: klein),
          HhKnop(
            label: TekstenMeldkamerNl.goedkeuren,
            onPressed: () => opBesluit(h, goedkeuren: true),
          ),
          SizedBox(height: klein),
          HhKnop(
            label: TekstenMeldkamerNl.afwijzen,
            soort: HhKnopSoort.tekst,
            onPressed: () => opBesluit(h, goedkeuren: false),
          ),
        ],
      ),
    );
  }
}

class _KlusKaart extends StatelessWidget {
  const _KlusKaart({
    required this.k,
    required this.nu,
    required this.opGoedkeuren,
    required this.opAfkeuren,
  });

  final HhTeKeurenKlus k;
  final DateTime nu;
  final Future<void> Function(HhTeKeurenKlus) opGoedkeuren;
  final Future<void> Function(HhTeKeurenKlus) opAfkeuren;

  @override
  Widget build(BuildContext context) {
    final tekst = Theme.of(context).textTheme;
    final klein = HhRuimte.voor(HhRuimte.s, HhDichtheidScope.van(context));
    final wanneer = wanneerTekst(k.wanneerVan, k.wanneerTot, nu);
    return HhKaart(
      kop: metHoofdletter(k.soort),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(k.bewonerNaam, style: tekst.bodyLarge),
          if (wanneer.isNotEmpty) Text(wanneer, style: tekst.bodyMedium),
          if (k.omschrijving.isNotEmpty) ...[
            SizedBox(height: klein),
            Text(k.omschrijving, style: tekst.bodyMedium),
          ],
          if (k.wachtOpBelletje) ...[
            SizedBox(height: klein),
            const HhMeldBalk(
              soort: HhMeldSoort.waarschuwing,
              tekst: TekstenMeldkamerNl.eerstBellen,
            ),
          ],
          SizedBox(height: klein),
          HhKnop(
            label: TekstenMeldkamerNl.goedkeuren,
            onPressed: k.wachtOpBelletje ? null : () => opGoedkeuren(k),
          ),
          SizedBox(height: klein),
          HhKnop(
            label: TekstenMeldkamerNl.afkeuren,
            soort: HhKnopSoort.tekst,
            onPressed: () => opAfkeuren(k),
          ),
        ],
      ),
    );
  }
}
