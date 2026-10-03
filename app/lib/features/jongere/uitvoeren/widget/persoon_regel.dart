import 'package:flutter/material.dart';

import '../../../../design/dichtheid_scope.dart';
import '../../../../l10n/teksten_aanmelden_nl.dart';
import '../../../../theme.dart';

/// Foto en naam van een persoon op één regel. De foto is versiering (de
/// schermlezer hoort alleen de naam en de onderregel); zonder foto komt er
/// een rustige cirkel met een poppetje.
class PersoonRegel extends StatelessWidget {
  const PersoonRegel({
    required this.naam,
    this.fotoUrl = '',
    this.onderregel = '',
    this.isIdGecontroleerd = false,
    super.key,
  });

  final String naam;
  final String fotoUrl;

  /// Een regel eronder, bijvoorbeeld "Je helper".
  final String onderregel;

  /// B2: vinkje "ID gecontroleerd" bij een helper (nooit het document).
  final bool isIdGecontroleerd;

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
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(naam, style: tekst.bodyLarge),
              if (onderregel.isNotEmpty)
                Text(onderregel, style: tekst.bodyMedium),
              if (isIdGecontroleerd)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ExcludeSemantics(
                      child: Icon(
                        Icons.verified_outlined,
                        size: HhMaten.icoonKeuzerij(dichtheid) * 0.75,
                        color: HhKleuren.succes,
                      ),
                    ),
                    SizedBox(width: HhRuimte.voor(HhRuimte.xs, dichtheid)),
                    Flexible(
                      child: Text(
                        TekstenAanmeldenNl.idGecontroleerd,
                        style: tekst.bodyMedium!.copyWith(
                          color: HhKleuren.succes,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }
}
