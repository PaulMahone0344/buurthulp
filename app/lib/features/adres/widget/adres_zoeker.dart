import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/pb/gateway_providers.dart';
import '../../../design/components/hh_invoer.dart';
import '../../../design/components/hh_meld_balk.dart';
import '../../../design/dichtheid_scope.dart';
import '../../../design/lijn.dart';
import '../../../l10n/teksten_aanmelden_nl.dart';
import '../../../l10n/teksten_adres_nl.dart';
import '../../../theme.dart';
import '../domein/adres_invoer.dart';
import '../model/hh_adres.dart';

/// Adres "zoals bol.com": Postcode | Huisnummer | Toevoeging. Zodra postcode
/// en huisnummer kloppen, zoekt hij (na [adresZoekWachttijd] rust) via de
/// server bij PDOK en toont een kaartje "Kerkstraat 1, 4001 MA Tiel" met een
/// vinkje. Meer adressen op één huisnummer: een lijstje om te kiezen. Straat
/// en plaats zijn NIET los in te typen.
///
/// [onGewijzigd] krijgt de keuze (bevestigd, of ongecontroleerd als PDOK even
/// weg is) of null zolang er nog geen bruikbaar adres is.
class AdresZoeker extends ConsumerStatefulWidget {
  const AdresZoeker({
    required this.onGewijzigd,
    this.beginPostcode = '',
    this.beginHuisnummer = '',
    this.beginToevoeging = '',
    this.beginWeergave,
    this.isActief = true,
    this.fouttekst,
    this.toonWerkgebied = true,
    this.zoekBijStart = false,
    super.key,
  });

  final ValueChanged<AdresKeuze?> onGewijzigd;
  final String beginPostcode;
  final String beginHuisnummer;
  final String beginToevoeging;

  /// Het opgeslagen adres als kaartje, zonder op te zoeken (Mijn gegevens).
  /// Verandert de gebruiker iets, dan zoekt hij opnieuw.
  final String? beginWeergave;
  final bool isActief;

  /// Fout van het formulier (bv. "Vul je postcode en huisnummer in.").
  final String? fouttekst;

  /// Toon "HeitjeHulp is nog niet in jouw buurt" bij een adres buiten het
  /// werkgebied.
  final bool toonWerkgebied;

  /// Meteen opzoeken als de beginwaarden al kloppen (Mijn adres van een
  /// helper: de sessie kent straat en plaats niet).
  final bool zoekBijStart;

  @override
  ConsumerState<AdresZoeker> createState() => _AdresZoekerState();
}

sealed class _Stand {
  const _Stand();
}

final class _Leeg extends _Stand {
  const _Leeg();
}

final class _Zoeken extends _Stand {
  const _Zoeken();
}

final class _Gekozen extends _Stand {
  const _Gekozen(this.weergave, {this.adres});
  final String weergave;
  final HhAdres? adres;
}

final class _Kiezen extends _Stand {
  const _Kiezen(this.adressen, {this.melding});
  final List<HhAdres> adressen;
  final String? melding;
}

final class _Melding extends _Stand {
  const _Melding(this.soort, this.tekst);
  final HhMeldSoort soort;
  final String tekst;
}

class _AdresZoekerState extends ConsumerState<AdresZoeker> {
  late final _postcode = TextEditingController(text: widget.beginPostcode);
  late final _huisnummer = TextEditingController(text: widget.beginHuisnummer);
  late final _toevoeging = TextEditingController(text: widget.beginToevoeging);
  Timer? _wacht;
  int _volgnummer = 0;
  late _Stand _stand = widget.beginWeergave == null
      ? const _Leeg()
      : _Gekozen(widget.beginWeergave!);

  @override
  void initState() {
    super.initState();
    if (widget.zoekBijStart &&
        widget.beginWeergave == null &&
        kanZoeken(_postcode.text, _huisnummer.text, _toevoeging.text)) {
      _stand = const _Zoeken();
      // Na de eerste build: onGewijzigd mag de ouder dan pas laten bouwen.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _zoek(bijStart: true);
      });
    }
  }

  @override
  void dispose() {
    _wacht?.cancel();
    _postcode.dispose();
    _huisnummer.dispose();
    _toevoeging.dispose();
    super.dispose();
  }

  void _invoerGewijzigd([String _ = '']) {
    _wacht?.cancel();
    _volgnummer++;
    final kan = kanZoeken(_postcode.text, _huisnummer.text, _toevoeging.text);
    setState(() => _stand = kan ? const _Zoeken() : const _Leeg());
    widget.onGewijzigd(null);
    if (kan) _wacht = Timer(adresZoekWachttijd, _zoek);
  }

  /// [bijStart]: het opgeslagen adres opnieuw bekijken; dat is geen
  /// wijziging, dus de ouder hoort er niets van.
  Future<void> _zoek({bool bijStart = false}) async {
    final nummer = ++_volgnummer;
    final postcode = normaliseerPostcode(_postcode.text);
    final huisnummer = _huisnummer.text.trim();
    final toevoeging = _toevoeging.text.trim();
    final uit = await ref
        .read(adresGatewayProvider)
        .zoek(
          postcode: postcode,
          huisnummer: huisnummer,
          toevoeging: toevoeging,
        );
    // Intussen verder getypt: dit antwoord is oud.
    if (!mounted || nummer != _volgnummer) return;
    switch (uit) {
      case AdresGevonden(:final adressen) when adressen.length == 1:
        _kies(adressen.single, melden: !bijStart);
      case AdresGevonden(:final adressen):
        setState(() => _stand = _Kiezen(adressen));
      case AdresNietGevonden(:final keuzes, :final melding)
          when keuzes.isNotEmpty:
        setState(() => _stand = _Kiezen(keuzes, melding: melding));
      case AdresNietGevonden():
        setState(
          () => _stand = const _Melding(
            HhMeldSoort.informatie,
            TekstenAdresNl.nietGevonden,
          ),
        );
      case AdresOngeldig(:final melding) || AdresLimiet(:final melding):
        setState(() => _stand = _Melding(HhMeldSoort.waarschuwing, melding));
      case AdresDienstWeg():
        setState(
          () => _stand = const _Melding(
            HhMeldSoort.waarschuwing,
            TekstenAdresNl.dienstWeg,
          ),
        );
        widget.onGewijzigd(
          AdresKeuze.ongecontroleerd(
            postcode: postcode,
            huisnummer: huisnummer,
            toevoeging: toevoeging,
          ),
        );
    }
  }

  void _kies(HhAdres adres, {bool melden = true}) {
    _wacht?.cancel();
    _volgnummer++;
    // De toevoeging zoals PDOK hem kent (zonder opnieuw te zoeken).
    _toevoeging.text = adres.toevoeging;
    _postcode.text = adres.postcode;
    setState(() => _stand = _Gekozen(adres.weergave, adres: adres));
    if (melden) widget.onGewijzigd(AdresKeuze.bevestigd(adres));
  }

  String? get _postcodeFout {
    final t = _postcode.text.trim();
    return t.length >= 7 && !isVolledigePostcode(t)
        ? TekstenAdresNl.validatiePostcode
        : null;
  }

  String? get _toevoegingFout => isGeldigeToevoeging(_toevoeging.text)
      ? null
      : TekstenAdresNl.validatieToevoeging;

  @override
  Widget build(BuildContext context) {
    final dichtheid = HhDichtheidScope.van(context);
    final tussen = HhRuimte.voor(HhRuimte.m, dichtheid);
    final actief = widget.isActief;

    final postcode = HhInvoer(
      label: TekstenAdresNl.veldPostcode,
      controller: _postcode,
      fouttekst: _postcodeFout,
      isVerplicht: true,
      isActief: actief,
      keyboardType: TextInputType.text,
      textCapitalization: TextCapitalization.characters,
      inputFormatters: const [PostcodeFormatter()],
      textInputAction: TextInputAction.next,
      autofillHints: const [AutofillHints.postalCode],
      onChanged: _invoerGewijzigd,
    );
    final huisnummer = HhInvoer(
      label: TekstenAdresNl.veldHuisnummer,
      controller: _huisnummer,
      isVerplicht: true,
      isActief: actief,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(5),
      ],
      textInputAction: TextInputAction.next,
      onChanged: _invoerGewijzigd,
    );
    final toevoeging = HhInvoer(
      label: TekstenAdresNl.veldToevoeging,
      controller: _toevoeging,
      hulptekst: TekstenAdresNl.veldToevoegingHulp,
      fouttekst: _toevoegingFout,
      isActief: actief,
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9 -]')),
        LengthLimitingTextInputFormatter(6),
      ],
      textInputAction: TextInputAction.done,
      onChanged: _invoerGewijzigd,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DrieVelden(
          postcode: postcode,
          huisnummer: huisnummer,
          toevoeging: toevoeging,
        ),
        SizedBox(height: tussen),
        Semantics(liveRegion: true, child: _uitkomst(context)),
        if (widget.fouttekst != null && _stand is! _Gekozen) ...[
          SizedBox(height: HhRuimte.voor(HhRuimte.xs, dichtheid)),
          Text(
            widget.fouttekst!,
            style: Theme.of(context).textTheme.bodyMedium!.copyWith(
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ],
      ],
    );
  }

  Widget _uitkomst(BuildContext context) {
    final dichtheid = HhDichtheidScope.van(context);
    final tekst = Theme.of(context).textTheme;
    final tussen = HhRuimte.voor(HhRuimte.s, dichtheid);
    return switch (_stand) {
      _Leeg() => Text(TekstenAdresNl.uitleg, style: tekst.bodyMedium),
      _Zoeken() => Row(
        children: [
          SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: HhLijn.dik(context)),
          ),
          SizedBox(width: tussen),
          Expanded(child: Text(TekstenAdresNl.zoeken, style: tekst.bodyMedium)),
        ],
      ),
      _Gekozen(:final weergave, :final adres) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AdresKaartje(weergave: weergave),
          if (widget.toonWerkgebied &&
              adres != null &&
              !adres.binnenWerkgebied) ...[
            SizedBox(height: tussen),
            const HhMeldBalk(
              soort: HhMeldSoort.waarschuwing,
              tekst: TekstenAanmeldenNl.nietInBuurt,
            ),
          ],
        ],
      ),
      _Kiezen(:final adressen, :final melding) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (melding != null && melding.isNotEmpty) ...[
            HhMeldBalk(soort: HhMeldSoort.informatie, tekst: melding),
            SizedBox(height: tussen),
          ],
          Text(TekstenAdresNl.kiesKop, style: tekst.bodyLarge),
          SizedBox(height: tussen),
          for (final a in adressen) ...[
            _KeuzeRij(
              adres: a,
              isActief: widget.isActief,
              onKies: () => _kies(a),
            ),
            SizedBox(height: HhRuimte.voor(HhRuimte.xs, dichtheid)),
          ],
        ],
      ),
      _Melding(:final soort, :final tekst) => HhMeldBalk(
        soort: soort,
        tekst: tekst,
      ),
    };
  }
}

/// Postcode, huisnummer en toevoeging naast elkaar; op een smal scherm (of
/// bij grote letters) de postcode boven en de twee nummers eronder.
class _DrieVelden extends StatelessWidget {
  const _DrieVelden({
    required this.postcode,
    required this.huisnummer,
    required this.toevoeging,
  });

  final Widget postcode;
  final Widget huisnummer;
  final Widget toevoeging;

  /// Minimale breedte per veld bij gewone tekstgrootte.
  static const minVeldBreedte = 104.0;

  @override
  Widget build(BuildContext context) {
    final dichtheid = HhDichtheidScope.van(context);
    final tussen = HhRuimte.voor(HhRuimte.m, dichtheid);
    final schaal = MediaQuery.textScalerOf(context).scale(1);
    return LayoutBuilder(
      builder: (context, maat) {
        final drie =
            (maat.maxWidth - 2 * tussen) / 3 >= minVeldBreedte * schaal &&
            dichtheid == HhDichtheid.normaal;
        if (drie) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 4, child: postcode),
              SizedBox(width: tussen),
              Expanded(flex: 3, child: huisnummer),
              SizedBox(width: tussen),
              Expanded(flex: 3, child: toevoeging),
            ],
          );
        }
        final twee =
            (maat.maxWidth - tussen) / 2 >= minVeldBreedte * schaal &&
            dichtheid == HhDichtheid.normaal;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            postcode,
            SizedBox(height: HhRuimte.voor(HhRuimte.l, dichtheid)),
            if (twee)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: huisnummer),
                  SizedBox(width: tussen),
                  Expanded(child: toevoeging),
                ],
              )
            else ...[
              huisnummer,
              SizedBox(height: HhRuimte.voor(HhRuimte.l, dichtheid)),
              toevoeging,
            ],
          ],
        );
      },
    );
  }
}

/// Het gevonden adres met een vinkje. Ook los te gebruiken (paneel, Mijn
/// gegevens).
class AdresKaartje extends StatelessWidget {
  const AdresKaartje({required this.weergave, super.key});

  final String weergave;

  @override
  Widget build(BuildContext context) {
    final dichtheid = HhDichtheidScope.van(context);
    final tekst = Theme.of(context).textTheme;
    return Semantics(
      container: true,
      label: '${TekstenAdresNl.gevondenSemantiek}: $weergave',
      excludeSemantics: true,
      child: Container(
        padding: EdgeInsets.all(HhRuimte.voor(HhRuimte.m, dichtheid)),
        decoration: BoxDecoration(
          color: HhKleuren.oppervlak,
          borderRadius: BorderRadius.circular(HhRadius.groot),
          border: Border.all(
            color: HhKleuren.succes,
            width: HhLijn.dik(context),
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle, color: HhKleuren.succes),
            SizedBox(width: HhRuimte.voor(HhRuimte.s, dichtheid)),
            Expanded(
              child: Text(
                weergave,
                style: tekst.bodyLarge!.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KeuzeRij extends StatelessWidget {
  const _KeuzeRij({
    required this.adres,
    required this.isActief,
    required this.onKies,
  });

  final HhAdres adres;
  final bool isActief;
  final VoidCallback onKies;

  @override
  Widget build(BuildContext context) {
    final dichtheid = HhDichtheidScope.van(context);
    final tekst = Theme.of(context).textTheme;
    return Material(
      color: HhKleuren.achtergrond,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(HhRadius.midden),
        side: BorderSide(color: HhKleuren.rand, width: HhLijn.dun(context)),
      ),
      child: InkWell(
        onTap: isActief ? onKies : null,
        borderRadius: BorderRadius.circular(HhRadius.midden),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: HhMaten.knopHoogte(dichtheid)),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: HhRuimte.voor(HhRuimte.m, dichtheid),
              vertical: HhRuimte.voor(HhRuimte.s, dichtheid),
            ),
            child: Row(
              children: [
                const Icon(Icons.radio_button_unchecked),
                SizedBox(width: HhRuimte.voor(HhRuimte.s, dichtheid)),
                Expanded(child: Text(adres.weergave, style: tekst.bodyLarge)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
