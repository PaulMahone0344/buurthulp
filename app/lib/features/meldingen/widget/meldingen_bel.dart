import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../design/components/hh_scherm.dart';
import '../../../design/dichtheid_scope.dart';
import '../../../l10n/teksten_meldingen_nl.dart';
import '../../../theme.dart';
import '../paden_meldingen.dart';
import '../provider/meldingen_providers.dart';

/// Het belletje met de ongelezen-teller (jongere, coordinator).
/// Tik opent het meldingen-overzicht. Raakvlak = knophoogte uit theme.dart;
/// de schermlezer hoort "Meldingen, 2 ongelezen".
class MeldingenBel extends ConsumerWidget {
  const MeldingenBel({this.kleur, super.key});

  /// Kleur van het belletje. Leeg: primair (op een lichte achtergrond).
  final Color? kleur;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final aantal = ref.watch(ongelezenAantalProvider);
    final dichtheid = HhDichtheidScope.van(context);
    final schema = Theme.of(context).colorScheme;
    final tekst = Theme.of(context).textTheme;
    final maat = HhMaten.knopHoogte(dichtheid);

    void open() => context.push(HhPadenMeldingen.overzicht);

    return Semantics(
      button: true,
      label: TekstenMeldingenNl.belSemantiek(aantal),
      onTap: open,
      excludeSemantics: true,
      child: InkWell(
        onTap: open,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: maat,
          height: maat,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(
                aantal > 0
                    ? Icons.notifications_active_outlined
                    : Icons.notifications_none_outlined,
                size: HhMaten.icoonKeuzerij(dichtheid),
                color: kleur ?? schema.primary,
              ),
              if (aantal > 0)
                Positioned(
                  top: HhRuimte.xs,
                  right: HhRuimte.xs,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: HhRuimte.xs,
                    ),
                    decoration: BoxDecoration(
                      color: schema.error,
                      borderRadius: BorderRadius.circular(HhRadius.rond),
                    ),
                    child: Text(
                      TekstenMeldingenNl.belTeller(aantal),
                      textScaler: TextScaler.noScaling,
                      style: tekst.labelSmall?.copyWith(color: schema.onError),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Zet het belletje rechts in de groene bovenbalk van een tabscherm. Het
/// kind is een gewoon scherm met eigen Scaffold (HhScherm); de bovenbalk
/// haalt het belletje zelf op ([HhKopActie]).
class MeldingenKop extends StatelessWidget {
  const MeldingenKop({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return HhKopActie(
      actie: const MeldingenBel(kleur: HhKleuren.opPrimair),
      child: child,
    );
  }
}
