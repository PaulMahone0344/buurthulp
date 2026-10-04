import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/navigatie.dart';
import '../../../../app/paden.dart';
import '../../../../design/components/hh_kaart.dart';
import '../../../../design/components/hh_knop.dart';
import '../../../../design/components/hh_laad_staat.dart';
import '../../../../design/components/hh_lege_staat.dart';
import '../../../../design/components/hh_scherm.dart';
import '../../../../design/dichtheid_scope.dart';
import '../../../../l10n/teksten_klus_nl.dart';
import '../../../../l10n/teksten_klussen_nl.dart';
import '../../../../l10n/teksten_nl.dart';
import '../../../../l10n/teksten_uitvoeren_nl.dart';
import '../../../../theme.dart';
import '../../../../l10n/teksten_chat_nl.dart';
import '../../../chat/widget/chat_knop.dart';
import '../../../hulpvrager/provider/hulpvrager_providers.dart'
    show klokProvider;
import '../../../toegang/provider/sessie_providers.dart';
import '../../model/hh_profiel.dart';
import '../../uitvoeren/paden_uitvoeren.dart';
import '../../model/screening_stap.dart';
import '../../provider/screening_providers.dart';
import '../domein/afstand.dart';
import '../domein/klus_filter.dart';
import '../domein/wanneer_tekst.dart';
import '../model/hh_klus.dart';
import '../paden_klussen.dart';
import '../provider/klussen_providers.dart';
import '../../../reacties/widget/reageer_blok.dart';
import '../widget/klus_status_pil.dart';

/// J13 / HKlusBekijken. Alles van de klus; adres en naam van de bewoner pas
/// NA de match (de hh_users-rule geeft de expand dan pas mee). B5: onderaan
/// "Ik wil helpen" met een berichtje (ReageerBlok); de bewoner kiest zelf.
/// Is de klus van mij, dan gaat de hoofdknop naar J15 (uitvoeren).
class KlusDetailScreen extends ConsumerStatefulWidget {
  const KlusDetailScreen({required this.klusId, super.key});

  final String klusId;

  @override
  ConsumerState<KlusDetailScreen> createState() => _KlusDetailScreenState();
}

class _KlusDetailScreenState extends ConsumerState<KlusDetailScreen> {
  /// De naam van de eigen wijk (de klus ligt per definitie in die wijk).
  String _wijkNaam() {
    final account = switch (ref.watch(screeningControllerProvider)) {
      AsyncData<ScreeningGegevens>(:final value) => value.account,
      _ => const HhAccountGegevens(),
    };
    final wijken = switch (ref.watch(wijkenProvider)) {
      AsyncData<List<HhWijk>>(:final value) => value,
      _ => const <HhWijk>[],
    };
    for (final wijk in wijken) {
      if (wijk.id == account.wijkId) return wijk.wijk;
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final stand = ref.watch(klusDetailProvider(widget.klusId));
    final gebruiker = ref.watch(huidigeGebruikerProvider);
    final nu = ref.watch(klokProvider)();
    final middelpunt = switch (ref.watch(gefilterdeKlussenProvider)) {
      AsyncData<GefilterdeKlussen>(:final value) => value.middelpunt,
      _ => null,
    };

    return switch (stand) {
      AsyncData<HhKlus>(:final value) => _Detail(
        klus: value,
        nu: nu,
        middelpunt: middelpunt,
        wijkNaam: _wijkNaam(),
        isMijn: value.isToegewezenAan(gebruiker?.id ?? ''),
      ),
      AsyncError<HhKlus>(:final error) => HhScherm(
        titel: TekstenKlussenNl.j13Titel,
        onTerug: () => terugOf(context, HhPaden.jongere),
        child: HhLegeStaat(
          icoon: Icons.cloud_off_outlined,
          titel: TekstenKlussenNl.j13LadenMislukt,
          uitleg: meldingVanFout(error),
          knopLabel: TekstenNl.opnieuwProberen,
          onKnop: () => ref.invalidate(klusDetailProvider(widget.klusId)),
        ),
      ),
      _ => HhScherm(
        titel: TekstenKlussenNl.j13Titel,
        onTerug: () => terugOf(context, HhPaden.jongere),
        child: const HhLaadStaat.skelet(regels: 4),
      ),
    };
  }
}

class _Detail extends StatelessWidget {
  const _Detail({
    required this.klus,
    required this.nu,
    required this.middelpunt,
    required this.wijkNaam,
    required this.isMijn,
  });

  final HhKlus klus;
  final DateTime nu;
  final HhPunt? middelpunt;
  final String wijkNaam;
  final bool isMijn;

  @override
  Widget build(BuildContext context) {
    final dichtheid = HhDichtheidScope.van(context);
    final tekst = Theme.of(context).textTheme;
    final tussen = HhRuimte.voor(HhRuimte.l, dichtheid);
    final klein = HhRuimte.voor(HhRuimte.s, dichtheid);

    final wanneer = wanneerTekst(klus.wanneerVan, klus.wanneerTot, nu);
    final afstand = afstandVanKlus(klus, middelpunt);
    final toontAdres = isMijn && klus.adres.isNotEmpty;
    final toontOudere = isMijn && klus.isOudereZichtbaar;

    return HhScherm(
      titel: metHoofdletter(klus.klustypeNaam),
      onTerug: () => terugOf(context, HhPaden.jongere),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isMijn) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: KlusStatusPil(status: klus.status),
            ),
            SizedBox(height: tussen),
          ],
          HhKaart(
            kop: TekstenKlussenNl.j13WanneerKop,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(wanneer, style: tekst.bodyLarge),
                if (klus.richtduurMinuten > 0) ...[
                  SizedBox(height: klein),
                  Text(
                    TekstenKlussenNl.j13Duur(klus.richtduurMinuten),
                    style: tekst.bodyMedium,
                  ),
                ],
              ],
            ),
          ),
          SizedBox(height: tussen),
          HhKaart(
            kop: TekstenKlussenNl.j13WaarKop,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (toontAdres)
                  Text(klus.adres, style: tekst.bodyLarge)
                else ...[
                  if (wijkNaam.isNotEmpty)
                    Text(
                      TekstenKlussenNl.j13Wijk(wijkNaam),
                      style: tekst.bodyLarge,
                    ),
                  Text(
                    afstand == null
                        ? TekstenKlussenNl.zonderLocatie
                        : afstandTekst(afstand),
                    style: tekst.bodyLarge,
                  ),
                  SizedBox(height: klein),
                  Text(
                    TekstenKlussenNl.j13AdresNaAccepteren,
                    style: tekst.bodyMedium,
                  ),
                ],
              ],
            ),
          ),
          SizedBox(height: tussen),
          HhKaart(
            kop: TekstenKlussenNl.j13VoorWieKop,
            child: toontOudere
                ? _Oudere(naam: klus.oudereNaam, fotoUrl: klus.oudereFotoUrl)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        TekstenKlussenNl.buurtbewoner,
                        style: tekst.bodyLarge,
                      ),
                      SizedBox(height: klein),
                      Text(
                        TekstenKlussenNl.j13NaamNaAccepteren,
                        style: tekst.bodyMedium,
                      ),
                    ],
                  ),
          ),
          SizedBox(height: tussen),
          HhKaart(
            kop: TekstenKlussenNl.j13VergoedingKop,
            child: Text(
              vergoedingVoorHelper(klus.vergoedingJongereCenten),
              style: tekst.bodyLarge,
            ),
          ),
          SizedBox(height: tussen),
          HhKaart(
            kop: TekstenKlussenNl.j13ToelichtingKop,
            child: Text(
              klus.omschrijving.isEmpty
                  ? TekstenKlussenNl.j13GeenToelichting
                  : klus.omschrijving,
              style: tekst.bodyLarge,
            ),
          ),
          // B4: de foto die de bewoner bij de klus zette (beschermd; de
          // URL heeft een kortlevend bestandstoken).
          if (klus.klusFotoUrl.isNotEmpty) ...[
            SizedBox(height: tussen),
            HhKaart(
              kop: TekstenKlusNl.helperFotoKop,
              child: Semantics(
                image: true,
                label: TekstenKlusNl.helperFotoSemantiek,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(HhRadius.groot),
                  child: Image.network(
                    klus.klusFotoUrl,
                    fit: BoxFit.cover,
                    excludeFromSemantics: true,
                    errorBuilder: (context, error, stack) => Text(
                      TekstenKlusNl.helperFotoLuktNiet,
                      style: tekst.bodyMedium,
                    ),
                  ),
                ),
              ),
            ),
          ],
          SizedBox(height: HhRuimte.voor(HhRuimte.xl, dichtheid)),
          if (isMijn) ...[
            Text(TekstenKlussenNl.j13AangenomenUitleg, style: tekst.bodyMedium),
            SizedBox(height: tussen),
            HhKnop(
              label: TekstenUitvoerenNl.j13Uitvoeren,
              icoon: Icons.play_circle_outline,
              onPressed: () =>
                  context.push(HhPadenUitvoeren.uitvoeren(klus.id)),
            ),
            SizedBox(height: tussen),
            // B6: "Open de chat" waar de klus een helper krijgt (de echte
            // match-sheet is B5).
            ChatKnop(
              klusId: klus.id,
              naam: klus.oudereNaam.split(' ').first,
              label: TekstenChatNl.openDeChat,
            ),
            SizedBox(height: tussen),
            HhKnop(
              label: TekstenKlussenNl.j13NaarMijnKlussen,
              icoon: Icons.assignment_turned_in_outlined,
              soort: HhKnopSoort.tweedeKeus,
              onPressed: () => context.go(HhPadenKlussen.mijnKlussen),
            ),
          ] else
            // B5: niet meer aannemen maar reageren; de bewoner kiest.
            ReageerBlok(klus: klus),
        ],
      ),
    );
  }
}

/// Naam en (als die er is) de miniatuur van de oudere.
class _Oudere extends StatelessWidget {
  const _Oudere({required this.naam, required this.fotoUrl});

  final String naam;
  final String fotoUrl;

  @override
  Widget build(BuildContext context) {
    final dichtheid = HhDichtheidScope.van(context);
    final tekst = Theme.of(context).textTheme;
    final schema = Theme.of(context).colorScheme;
    final maat = HhMaten.avatar(dichtheid);

    final terugval = Container(
      width: maat,
      height: maat,
      decoration: const BoxDecoration(
        color: HhKleuren.oppervlak,
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.person_outline,
        size: HhMaten.icoonKeuzerij(dichtheid),
        color: schema.primary,
      ),
    );

    return Row(
      children: [
        ExcludeSemantics(
          child: fotoUrl.isEmpty
              ? terugval
              : ClipOval(
                  child: Image.network(
                    fotoUrl,
                    width: maat,
                    height: maat,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stack) => terugval,
                  ),
                ),
        ),
        SizedBox(width: HhRuimte.voor(HhRuimte.m, dichtheid)),
        Expanded(child: Text(naam, style: tekst.bodyLarge)),
      ],
    );
  }
}
