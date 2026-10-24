import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design/components/hh_invoer.dart';
import '../../../design/dichtheid_scope.dart';
import '../../../l10n/teksten_klus_nl.dart';
import '../../../theme.dart';
import '../provider/concept_controller.dart';

/// "Vertel wat je wilt" (B4): verplicht, hooguit 300 tekens, met een
/// teller eronder. De kop volgt de gekozen categorie (feedbackronde 1). Elke letter gaat meteen in het concept.
class KlusOmschrijvingSectie extends ConsumerStatefulWidget {
  const KlusOmschrijvingSectie({required this.toonFout, super.key});

  /// True na een tik op "Klus plaatsen" zonder (genoeg) tekst.
  final bool toonFout;

  static const regels = 4;

  @override
  ConsumerState<KlusOmschrijvingSectie> createState() =>
      _KlusOmschrijvingSectieState();
}

class _KlusOmschrijvingSectieState
    extends ConsumerState<KlusOmschrijvingSectie> {
  late final TextEditingController _tekst = TextEditingController(
    text: ref.read(conceptProvider).omschrijving,
  );

  @override
  void dispose() {
    _tekst.dispose();
    super.dispose();
  }

  void _bewaar(String tekst) {
    const max = TekstenKlusNl.omschrijvingMax;
    if (tekst.length > max) {
      // Te lang geplakt: afknippen, cursor aan het eind.
      _tekst.value = TextEditingValue(
        text: tekst.substring(0, max),
        selection: const TextSelection.collapsed(offset: max),
      );
    }
    ref.read(conceptProvider.notifier).zetOmschrijving(_tekst.text);
  }

  @override
  Widget build(BuildContext context) {
    final omschrijving = ref.watch(
      conceptProvider.select((c) => c.omschrijving),
    );
    final heeftGenoeg = ref.watch(
      conceptProvider.select((c) => c.heeftOmschrijving),
    );
    final categorie = ref.watch(
      conceptProvider.select((c) => c.klustype?.naam),
    );
    final tekst = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HhInvoer(
          label: TekstenKlusNl.omschrijvingTitelVoor(categorie),
          controller: _tekst,
          isVerplicht: true,
          hulptekst: TekstenKlusNl.omschrijvingHulp,
          fouttekst: widget.toonFout && !heeftGenoeg
              ? TekstenKlusNl.ontbreektOmschrijving
              : null,
          maxRegels: KlusOmschrijvingSectie.regels,
          onChanged: _bewaar,
        ),
        SizedBox(
          height: HhRuimte.voor(HhRuimte.xs, HhDichtheidScope.van(context)),
        ),
        Semantics(
          label: TekstenKlusNl.omschrijvingTellerSemantiek(omschrijving.length),
          excludeSemantics: true,
          child: Text(
            TekstenKlusNl.omschrijvingTeller(omschrijving.length),
            textAlign: TextAlign.end,
            style: tekst.bodyMedium?.copyWith(color: HhKleuren.tekstGedempt),
          ),
        ),
      ],
    );
  }
}
