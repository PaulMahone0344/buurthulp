import 'package:flutter/material.dart';

import '../../../design/components/hh_invoer.dart';
import '../../../design/components/hh_knop.dart';
import '../../../design/dichtheid_scope.dart';
import '../../../l10n/teksten_aanmelden_nl.dart';
import '../../../l10n/teksten_nl.dart';
import '../../../theme.dart';

/// Twee velden naast elkaar (straat + huisnummer, postcode + plaats), zoals
/// de mockup. Is er te weinig ruimte (smal scherm, grote letters), dan
/// komen ze onder elkaar.
class NaastElkaar extends StatelessWidget {
  const NaastElkaar({
    required this.links,
    required this.rechts,
    this.linksFlex = 2,
    this.rechtsFlex = 1,
    super.key,
  });

  final Widget links;
  final Widget rechts;
  final int linksFlex;
  final int rechtsFlex;

  /// Minimale breedte van het smalste veld, bij gewone tekstgrootte.
  static const minVeldBreedte = 120.0;

  @override
  Widget build(BuildContext context) {
    final dichtheid = HhDichtheidScope.van(context);
    final tussen = HhRuimte.voor(HhRuimte.m, dichtheid);
    final schaal = MediaQuery.textScalerOf(context).scale(1);
    return LayoutBuilder(
      builder: (context, maat) {
        final smalste =
            (maat.maxWidth - tussen) *
            (rechtsFlex < linksFlex ? rechtsFlex : linksFlex) /
            (linksFlex + rechtsFlex);
        final past =
            smalste >= minVeldBreedte * schaal &&
            dichtheid == HhDichtheid.normaal;
        if (!past) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              links,
              SizedBox(height: HhRuimte.voor(HhRuimte.l, dichtheid)),
              rechts,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: linksFlex, child: links),
            SizedBox(width: tussen),
            Expanded(flex: rechtsFlex, child: rechts),
          ],
        );
      },
    );
  }
}

/// Wachtwoord met daaronder een knop "Wachtwoord tonen". Los van het veld
/// (geen oog ín het veld): zo blijft het een eigen knop voor de schermlezer.
class WachtwoordVeld extends StatefulWidget {
  const WachtwoordVeld({
    required this.controller,
    required this.isActief,
    this.fouttekst,
    this.onSubmitted,
    super.key,
  });

  final TextEditingController controller;
  final bool isActief;
  final String? fouttekst;
  final ValueChanged<String>? onSubmitted;

  @override
  State<WachtwoordVeld> createState() => _WachtwoordVeldState();
}

class _WachtwoordVeldState extends State<WachtwoordVeld> {
  bool _isZichtbaar = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HhInvoer(
          label: TekstenNl.veldWachtwoord,
          controller: widget.controller,
          hulptekst: TekstenNl.veldWachtwoordHulp,
          fouttekst: widget.fouttekst,
          isVerplicht: true,
          isActief: widget.isActief,
          obscureText: !_isZichtbaar,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.newPassword],
          onSubmitted: widget.onSubmitted,
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: HhKnop(
            label: _isZichtbaar
                ? TekstenAanmeldenNl.wachtwoordVerbergen
                : TekstenAanmeldenNl.wachtwoordTonen,
            icoon: _isZichtbaar
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            soort: HhKnopSoort.tekst,
            onPressed: () => setState(() => _isZichtbaar = !_isZichtbaar),
          ),
        ),
      ],
    );
  }
}

/// Vinkje "Ik ga akkoord met de voorwaarden en de privacyverklaring" met
/// een knop die de (placeholder-)pagina opent.
class AkkoordVinkje extends StatelessWidget {
  const AkkoordVinkje({
    required this.isAkkoord,
    required this.onGewijzigd,
    required this.onLees,
    this.fouttekst,
    super.key,
  });

  final bool isAkkoord;
  final ValueChanged<bool>? onGewijzigd;
  final VoidCallback onLees;
  final String? fouttekst;

  @override
  Widget build(BuildContext context) {
    final tekst = Theme.of(context).textTheme;
    final schema = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CheckboxListTile(
          value: isAkkoord,
          onChanged: onGewijzigd == null
              ? null
              : (waarde) => onGewijzigd!(waarde ?? false),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
          title: Text(TekstenAanmeldenNl.akkoordTekst, style: tekst.bodyLarge),
        ),
        if (fouttekst != null)
          Text(
            fouttekst!,
            style: tekst.bodyMedium!.copyWith(color: schema.error),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: HhKnop(
            label: TekstenAanmeldenNl.akkoordLinks,
            icoon: Icons.open_in_new,
            soort: HhKnopSoort.tekst,
            onPressed: onLees,
          ),
        ),
      ],
    );
  }
}
