import 'package:flutter/material.dart';

import '../../../design/dichtheid_scope.dart';
import '../../../theme.dart';
import '../domein/reactie_regels.dart';

/// Een cirkel met de eerste letter van de voornaam (geen foto's of beelden
/// van mensen). De kleur hangt vast aan de naam. Versiering: de schermlezer
/// hoort de naam in de tekst ernaast.
class InitialenAvatar extends StatelessWidget {
  const InitialenAvatar({
    required this.voornaam,
    this.groot = false,
    super.key,
  });

  final String voornaam;

  /// Groter op het match-scherm.
  final bool groot;

  @override
  Widget build(BuildContext context) {
    final dichtheid = HhDichtheidScope.van(context);
    final maat = HhMaten.avatar(dichtheid) * (groot ? 1.6 : 1);
    final kleur =
        avatarKleuren[avatarKleurIndex(voornaam, avatarKleuren.length)];
    final stijl = Theme.of(context).textTheme.titleLarge!;
    return ExcludeSemantics(
      child: Container(
        width: maat,
        height: maat,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: kleur, shape: BoxShape.circle),
        child: Text(
          initialen(voornaam),
          textScaler: TextScaler.noScaling,
          style: stijl.copyWith(
            color: HhKleuren.opPrimair,
            fontSize: maat * 0.42,
            height: 1,
          ),
        ),
      ),
    );
  }
}
