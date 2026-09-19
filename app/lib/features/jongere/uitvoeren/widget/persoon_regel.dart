import 'package:flutter/material.dart';

import '../../../../design/dichtheid_scope.dart';
import '../../../../theme.dart';

/// Foto en naam van een persoon op één regel. De foto is versiering (de
/// schermlezer hoort alleen de naam en de onderregel); zonder foto komt er
/// een rustige cirkel met een poppetje.
class PersoonRegel extends StatelessWidget {
  const PersoonRegel({
    required this.naam,
    this.fotoUrl = '',
    this.onderregel = '',
    super.key,
  });

  final String naam;
  final String fotoUrl;

  /// Een regel eronder, bijvoorbeeld "Uw helper".
  final String onderregel;

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
            ],
          ),
        ),
      ],
    );
  }
}
