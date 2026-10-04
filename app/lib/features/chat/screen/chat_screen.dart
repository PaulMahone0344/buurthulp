import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/navigatie.dart';
import '../../../app/paden.dart';
import '../../../core/hh_fout.dart';
import '../../../core/pb/chat_gateway.dart';
import '../../../design/components/hh_laad_staat.dart';
import '../../../design/components/hh_lege_staat.dart';
import '../../../design/components/hh_meld_balk.dart';
import '../../../design/dichtheid_scope.dart';
import '../../../l10n/teksten_chat_nl.dart';
import '../../../l10n/teksten_nl.dart';
import '../../../theme.dart';
import '../../hulpvrager/provider/hulpvrager_providers.dart' show klokProvider;
import '../../hulpvrager/veiligheid/paden_veiligheid.dart';
import '../../jongere/uitvoeren/provider/uitvoeren_providers.dart';
import '../../toegang/model/hh_gebruiker.dart';
import '../../toegang/model/hh_rol.dart';
import '../../toegang/provider/sessie_providers.dart';
import '../domein/chat_regels.dart';
import '../model/hh_bericht.dart';
import '../provider/chat_providers.dart';
import '../widget/bericht_bubbel.dart';
import '../widget/chat_invoer.dart';
import '../widget/chat_kop.dart';
import '../widget/gesprek_verwijderen_dialoog.dart';

/// B6. De chat tussen bewoner en helper bij één klus (mockup Chat.dc.html).
/// De klus (en dus wie de ander is en of de chat open is) komt uit de
/// bestaande klusvolger van M6; de berichten uit [chatProvider]. Realtime;
/// valt de verbinding weg, dan ververst het scherm bij terugkomen in de
/// app. Wie mag lezen en schrijven beslist de server (rule 111, hook
/// hh_chat.pb.js); weigert hij, dan toont het scherm "Deze chat is
/// gesloten."
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({required this.klusId, super.key});

  final String klusId;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _invoer = TextEditingController();
  late final AppLifecycleListener _leven;
  bool _isBezig = false;
  bool _isGeweigerd = false;
  String? _fout;
  String? _gelukt;

  @override
  void initState() {
    super.initState();
    _leven = AppLifecycleListener(onResume: _ververs);
  }

  @override
  void dispose() {
    _leven.dispose();
    _invoer.dispose();
    super.dispose();
  }

  /// Terug in de app (of na een weigering): klus, gesprek en teller opnieuw.
  void _ververs() {
    ref.invalidate(klusVolgerProvider(widget.klusId));
    ref.invalidate(chatProvider);
    ref.invalidate(ongelezenChatProvider);
  }

  Future<void> _verstuur(
    ChatSleutel sleutel,
    String tekst, {
    HhBerichtSoort soort = HhBerichtSoort.tekst,
  }) async {
    if (tekst.trim().isEmpty || _isBezig) return;
    setState(() {
      _isBezig = true;
      _fout = null;
    });
    final uitkomst = await ref
        .read(chatProvider(sleutel).notifier)
        .verstuur(tekst, soort: soort);
    if (!mounted) return;
    setState(() {
      _isBezig = false;
      switch (uitkomst) {
        case Verstuurd():
          if (soort == HhBerichtSoort.tekst) _invoer.clear();
        case VerstuurGeweigerd():
          _isGeweigerd = true;
        case VerstuurFout(:final fout):
          _fout = fout.isGeenVerbinding
              ? fout.melding
              : TekstenChatNl.verstuurMislukt;
        case null:
          break;
      }
    });
    if (uitkomst is VerstuurGeweigerd) _ververs();
  }

  /// "Gesprek verwijderen": eerst vragen, dan alleen voor mij weg. Loopt er
  /// een melding op de klus, dan legt het scherm uit dat het later kan.
  Future<void> _verwijderGesprek(ChatSleutel sleutel, String naam) async {
    if (_isBezig) return;
    final weg = await vraagGesprekVerwijderen(context, naam);
    if (!weg || !mounted) return;
    setState(() {
      _isBezig = true;
      _fout = null;
      _gelukt = null;
    });
    final uitkomst = await ref
        .read(chatGatewayProvider)
        .verbergGesprek(sleutel.klusId);
    if (!mounted) return;
    setState(() {
      _isBezig = false;
      switch (uitkomst) {
        case GesprekVerborgen():
          _gelukt = TekstenChatNl.gesprekVerwijderd;
        case GesprekIncident():
          _fout = TekstenChatNl.verwijderIncident;
        case GesprekVerbergFout(:final fout):
          _fout = fout.isGeenVerbinding
              ? fout.melding
              : TekstenChatNl.verwijderMislukt;
      }
    });
    if (uitkomst is GesprekVerborgen) {
      ref.invalidate(chatProvider(sleutel));
      ref.invalidate(ongelezenChatProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final gebruiker = ref.watch(huidigeGebruikerProvider);
    final stand = ref.watch(klusVolgerProvider(widget.klusId));
    final terug = gebruiker?.rol == HhRol.jongere
        ? HhPaden.jongere
        : HhPaden.hulpvrager;

    void terugKnop() => terugOf(context, terug);

    if (gebruiker == null) return const Scaffold();

    return switch (stand) {
      AsyncData<KlusMetGeschiedenis>(:final value) => _gesprek(
        gebruiker,
        value,
        terugKnop,
      ),
      AsyncError<KlusMetGeschiedenis>(:final error) => _kaal(
        terugKnop,
        HhLegeStaat(
          icoon: Icons.cloud_off_outlined,
          titel: TekstenChatNl.ladenMislukt,
          uitleg: error is HhFout ? error.melding : TekstenNl.foutOnbekend,
          knopLabel: TekstenNl.opnieuwProberen,
          onKnop: _ververs,
        ),
      ),
      _ => _kaal(terugKnop, const HhLaadStaat.skelet(regels: 3)),
    };
  }

  Widget _kaal(VoidCallback onTerug, Widget inhoud) => Scaffold(
    backgroundColor: HhKleuren.achtergrond,
    body: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ChatKop(naam: '', ondertitel: '', onTerug: onTerug),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(HhRuimte.l),
            child: inhoud,
          ),
        ),
      ],
    ),
  );

  Widget _gesprek(
    HhGebruiker ik,
    KlusMetGeschiedenis kmg,
    VoidCallback onTerug,
  ) {
    final klus = kmg.klus;
    final nu = ref.watch(klokProvider)();
    final isBewoner = klus.hulpvragerId == ik.id;
    final naam = isBewoner
        ? klus.jongereVoornaam
        : chatVoornaam(klus.oudereNaam);
    final chatStand = _isGeweigerd
        ? ChatStand.dicht
        : chatStandVan(klus, kmg.logregels, nu);
    final helperId = klus.toegewezenJongereId;
    final ChatSleutel sleutel = (klusId: klus.id, helperId: helperId);

    return Scaffold(
      backgroundColor: HhKleuren.achtergrond,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ChatKop(
            naam: naam,
            ondertitel: chatOndertitel(klus.klustypeNaam, klus.wanneerVan, nu),
            onTerug: onTerug,
            onMeld: () =>
                context.push(HhPadenVeiligheid.probleemBij(widget.klusId)),
            onVerwijder: helperId.isEmpty
                ? null
                : () => _verwijderGesprek(sleutel, naam),
          ),
          if (_gelukt != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                HhRuimte.l,
                HhRuimte.s,
                HhRuimte.l,
                0,
              ),
              child: HhMeldBalk(soort: HhMeldSoort.geslaagd, tekst: _gelukt!),
            ),
          if (_fout != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                HhRuimte.l,
                HhRuimte.s,
                HhRuimte.l,
                0,
              ),
              child: HhMeldBalk(soort: HhMeldSoort.fout, tekst: _fout!),
            ),
          Expanded(
            child: helperId.isEmpty
                ? const SizedBox.shrink()
                : _Berichten(sleutel: sleutel, ik: ik, naam: naam, nu: nu),
          ),
          if (chatStand == ChatStand.open && helperId.isNotEmpty)
            ChatInvoer(
              controller: _invoer,
              snelknoppen: snelknoppenVoor(
                isBewoner ? HhRol.hulpvrager : HhRol.jongere,
              ),
              isBezig: _isBezig,
              onVerstuur: () => _verstuur(sleutel, _invoer.text),
              onSnel: (label) =>
                  _verstuur(sleutel, label, soort: HhBerichtSoort.snel),
            )
          else
            const ChatGeslotenRegel(),
        ],
      ),
    );
  }
}

/// De lijst met berichten. Zet gelezen_op zodra er iets ongelezens van de
/// ander binnen is (ook realtime).
class _Berichten extends ConsumerWidget {
  const _Berichten({
    required this.sleutel,
    required this.ik,
    required this.naam,
    required this.nu,
  });

  final ChatSleutel sleutel;
  final HhGebruiker ik;
  final String naam;
  final DateTime nu;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dichtheid = HhDichtheidScope.van(context);
    final rand = HhRuimte.voor(HhRuimte.l, dichtheid);
    final tussen = HhRuimte.voor(HhRuimte.s, dichtheid);

    ref.listen(chatProvider(sleutel), (vorige, nieuwe) {
      final lijst = nieuwe.value;
      if (lijst != null && ongelezenVoor(lijst, ik.id).isNotEmpty) {
        unawaited(ref.read(chatProvider(sleutel).notifier).markeerGelezen());
      }
    });

    return switch (ref.watch(chatProvider(sleutel))) {
      AsyncData<List<HhBericht>>(:final value) when value.isEmpty => Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(rand),
          child: Column(
            children: [
              HhLegeStaat(
                icoon: Icons.chat_bubble_outline,
                titel: TekstenChatNl.leeg,
                uitleg: TekstenChatNl.leegUitleg(naam),
              ),
              SizedBox(height: tussen),
              const _MeldkamerNotitie(),
            ],
          ),
        ),
      ),
      AsyncData<List<HhBericht>>(:final value) => () {
        final regels = chatIndeling(
          value,
          ikId: ik.id,
          nu: nu,
        ).reversed.toList();
        return ListView.separated(
          reverse: true,
          padding: EdgeInsets.all(rand),
          // B11-4: bovenaan (= laatste in een omgekeerde lijst) de notitie
          // dat de meldkamer kan meelezen; scrolt mee, past dus altijd.
          itemCount: regels.length + 1,
          separatorBuilder: (_, _) => SizedBox(height: tussen),
          itemBuilder: (context, i) => i == regels.length
              ? const _MeldkamerNotitie()
              : switch (regels[i]) {
                  ChatDagKop(:final label) => _DagKop(label: label),
                  ChatBerichtRegel(
                    :final bericht,
                    :final isVanMij,
                    :final toonGelezen,
                  ) =>
                    BerichtBubbel(
                      bericht: bericht,
                      isVanMij: isVanMij,
                      naamAfzender: naam,
                      toonGelezen: toonGelezen,
                    ),
                },
        );
      }(),
      AsyncError<List<HhBericht>>(:final error) => SingleChildScrollView(
        padding: EdgeInsets.all(rand),
        child: HhLegeStaat(
          icoon: Icons.cloud_off_outlined,
          titel: TekstenChatNl.ladenMislukt,
          uitleg: error is HhFout ? error.melding : TekstenNl.foutOnbekend,
          knopLabel: TekstenNl.opnieuwProberen,
          onKnop: () => ref.read(chatProvider(sleutel).notifier).vernieuw(),
        ),
      ),
      _ => SingleChildScrollView(
        padding: EdgeInsets.all(rand),
        child: const HhLaadStaat.skelet(regels: 3),
      ),
    };
  }
}

/// B11-4: de meldkamer leest elke chat (besluit 4 okt); dat zeggen we hier
/// eerlijk, klein en rustig.
class _MeldkamerNotitie extends StatelessWidget {
  const _MeldkamerNotitie();

  @override
  Widget build(BuildContext context) {
    final tekst = Theme.of(context).textTheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.shield_outlined, size: 16, color: HhKleuren.primair),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            TekstenChatNl.meldkamerLeestMee,
            textAlign: TextAlign.center,
            style: tekst.bodySmall?.copyWith(color: HhKleuren.tekstGedempt),
          ),
        ),
      ],
    );
  }
}

class _DagKop extends StatelessWidget {
  const _DagKop({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final tekst = Theme.of(context).textTheme;
    return Center(
      child: Semantics(
        header: true,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: HhKleuren.oppervlak,
            borderRadius: BorderRadius.circular(HhRadius.groot),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: HhRuimte.m,
              vertical: HhRuimte.xs,
            ),
            child: Text(
              label,
              style: tekst.labelLarge?.copyWith(color: HhKleuren.tekstGedempt),
            ),
          ),
        ),
      ),
    );
  }
}
