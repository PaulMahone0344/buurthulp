import 'package:flutter/material.dart';

import '../../theme.dart';
import '../dichtheid_scope.dart';
import 'hh_knop.dart';

/// Voor lege lijsten en eerste gebruik: icoon in een cirkel, titel,
/// uitleg en optioneel een knop die de gebruiker verder helpt.
class HhLegeStaat extends StatelessWidget {
  const HhLegeStaat({
    required this.icoon,
    required this.titel,
    required this.uitleg,
    this.knopLabel,
    this.onKnop,
    super.key,
  });

  final IconData icoon;
  final String titel;
  final String uitleg;
  final String? knopLabel;
  final VoidCallback? onKnop;

  bool get heeftKnop => knopLabel != null;

  @override
  Widget build(BuildContext context) {
    final dichtheid = HhDichtheidScope.van(context);
    final tekst = Theme.of(context).textTheme;
    final schema = Theme.of(context).colorScheme;
    final cirkel = HhMaten.avatar(dichtheid);

    return Semantics(
      container: true,
      child: Container(
        padding: EdgeInsets.all(HhRuimte.voor(HhRuimte.xl, dichtheid)),
        decoration: BoxDecoration(
          color: HhKleuren.oppervlak,
          borderRadius: BorderRadius.circular(HhRadius.groot),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ExcludeSemantics(
              child: Container(
                width: cirkel,
                height: cirkel,
                decoration: const BoxDecoration(
                  color: HhKleuren.oppervlakZacht,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icoon,
                  size: HhMaten.icoonKeuzerij(dichtheid),
                  color: schema.primary,
                ),
              ),
            ),
            SizedBox(height: HhRuimte.voor(HhRuimte.l, dichtheid)),
            Text(titel, style: tekst.titleLarge, textAlign: TextAlign.center),
            SizedBox(height: HhRuimte.voor(HhRuimte.s, dichtheid)),
            Text(uitleg, style: tekst.bodyMedium, textAlign: TextAlign.center),
            if (heeftKnop) ...[
              SizedBox(height: HhRuimte.voor(HhRuimte.l, dichtheid)),
              HhKnop(label: knopLabel!, onPressed: onKnop),
            ],
          ],
        ),
      ),
    );
  }
}
