import 'package:flutter/material.dart';

import '../../theme.dart';
import '../dichtheid_scope.dart';

/// De vier soorten knop. Gevaar is voor onomkeerbare acties (annuleren,
/// account wissen); tekst is voor een bijzaak naast een hoofdknop.
enum HhKnopSoort { primair, tweedeKeus, tekst, gevaar }

/// Een knop met vaste hoogte uit theme.dart: 48 in de normale dichtheid,
/// 60 in de grote. De maat volgt de [HhDichtheidScope]; [maat] kan dat
/// per knop overrulen, bijvoorbeeld een grote hoofdknop op een scherm in
/// de normale dichtheid.
///
/// Uitgeschakeld is [onPressed] null. Tijdens [isBezig] staat er een
/// spinner voor het label en reageert de knop niet op tikken.
class HhKnop extends StatelessWidget {
  const HhKnop({
    required this.label,
    required this.onPressed,
    this.soort = HhKnopSoort.primair,
    this.maat,
    this.isBezig = false,
    this.icoon,
    this.semantiekLabel,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final HhKnopSoort soort;
  final HhDichtheid? maat;
  final bool isBezig;
  final IconData? icoon;

  /// Wat de schermlezer voorleest als het label zelf niet genoeg zegt.
  final String? semantiekLabel;

  bool get isActief => onPressed != null && !isBezig;

  @override
  Widget build(BuildContext context) {
    final dichtheid = maat ?? HhDichtheidScope.van(context);
    final hoogte = HhMaten.knopHoogte(dichtheid);
    final schema = Theme.of(context).colorScheme;
    final tekstStijl = Theme.of(context).textTheme.titleLarge!;
    final icoonMaat = HhMaten.icoonKeuzerij(dichtheid);

    final stijl = ButtonStyle(
      minimumSize: WidgetStatePropertyAll(Size(hoogte, hoogte)),
      padding: WidgetStatePropertyAll(
        EdgeInsets.symmetric(
          horizontal: HhRuimte.voor(HhRuimte.l, dichtheid),
          vertical: HhRuimte.voor(HhRuimte.s, dichtheid),
        ),
      ),
      textStyle: WidgetStatePropertyAll(tekstStijl),
    );

    final inhoud = _Inhoud(
      label: label,
      icoon: icoon,
      isBezig: isBezig,
      icoonMaat: icoonMaat,
      tussenruimte: HhRuimte.voor(HhRuimte.s, dichtheid),
    );
    final actie = isActief ? onPressed : null;

    final knop = switch (soort) {
      HhKnopSoort.primair => FilledButton(
        onPressed: actie,
        style: stijl,
        child: inhoud,
      ),
      HhKnopSoort.gevaar => FilledButton(
        onPressed: actie,
        style: stijl.copyWith(
          backgroundColor: _alsActief(schema.error),
          foregroundColor: _alsActief(schema.onError),
        ),
        child: inhoud,
      ),
      HhKnopSoort.tweedeKeus => OutlinedButton(
        onPressed: actie,
        style: stijl,
        child: inhoud,
      ),
      HhKnopSoort.tekst => TextButton(
        onPressed: actie,
        style: stijl,
        child: inhoud,
      ),
    };

    final lezerLabel = semantiekLabel ?? label;
    return Semantics(
      container: true,
      button: true,
      enabled: isActief,
      label: isBezig ? '$lezerLabel, bezig' : lezerLabel,
      onTap: actie,
      // De Material-knop eronder heeft eigen semantiek; die sluiten we uit
      // zodat de schermlezer een label hoort, niet twee.
      excludeSemantics: true,
      child: knop,
    );
  }

  /// Alleen in de actieve staat een eigen kleur; uitgeschakeld valt terug
  /// op de gedempte kleur uit het thema, net als de gewone knop.
  static WidgetStateProperty<Color?> _alsActief(Color kleur) =>
      WidgetStateProperty.resolveWith(
        (staten) => staten.contains(WidgetState.disabled) ? null : kleur,
      );
}

class _Inhoud extends StatelessWidget {
  const _Inhoud({
    required this.label,
    required this.icoon,
    required this.isBezig,
    required this.icoonMaat,
    required this.tussenruimte,
  });

  final String label;
  final IconData? icoon;
  final bool isBezig;
  final double icoonMaat;
  final double tussenruimte;

  @override
  Widget build(BuildContext context) {
    final tekst = Flexible(
      child: Text(label, textAlign: TextAlign.center, softWrap: true),
    );
    if (!isBezig && icoon == null) {
      return Row(mainAxisSize: MainAxisSize.min, children: [tekst]);
    }

    final voorkant = isBezig
        ? SizedBox(
            width: icoonMaat,
            height: icoonMaat,
            child: CircularProgressIndicator(
              strokeWidth: HhMaten.icoonLijn,
              // Kleur volgt de tekstkleur van de knop, ook uitgeschakeld.
              color: DefaultTextStyle.of(context).style.color,
            ),
          )
        : Icon(icoon, size: icoonMaat);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        voorkant,
        SizedBox(width: tussenruimte),
        tekst,
      ],
    );
  }
}
