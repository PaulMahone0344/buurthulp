import 'package:flutter/material.dart';

import '../../theme.dart';
import '../dichtheid_scope.dart';
import '../lijn.dart';

/// Eén regel op een Meer-scherm (3 okt, indeling naar BuurtHeld): witte
/// kaart met vette titel, korte uitleg eronder en een pijltje rechts. De
/// hele kaart is de knop.
class HhMeerRij extends StatelessWidget {
  const HhMeerRij({
    required this.titel,
    required this.uitleg,
    required this.onTik,
    super.key,
  });

  final String titel;
  final String uitleg;
  final VoidCallback onTik;

  @override
  Widget build(BuildContext context) {
    final dichtheid = HhDichtheidScope.van(context);
    final tekst = Theme.of(context).textTheme;
    final binnen = HhRuimte.voor(HhRuimte.l, dichtheid);
    final vorm = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(HhRadius.groot),
      side: BorderSide(color: HhKleuren.rand, width: HhLijn.dun(context)),
    );

    return Semantics(
      button: true,
      label: '$titel. $uitleg',
      onTap: onTik,
      excludeSemantics: true,
      child: Material(
        color: HhKleuren.achtergrond,
        shape: vorm,
        child: InkWell(
          onTap: onTik,
          customBorder: vorm,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: HhMaten.knopHoogte(dichtheid),
            ),
            child: Padding(
              padding: EdgeInsets.all(binnen),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          titel,
                          style: tekst.bodyLarge?.copyWith(
                            color: HhKleuren.primair,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: HhRuimte.voor(HhRuimte.xs, dichtheid)),
                        Text(
                          uitleg,
                          style: tekst.bodyMedium?.copyWith(
                            color: HhKleuren.tekstGedempt,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: HhRuimte.voor(HhRuimte.s, dichtheid)),
                  Icon(
                    Icons.chevron_right,
                    size: HhMaten.icoonKeuzerij(dichtheid),
                    color: HhKleuren.tekstGedempt,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
