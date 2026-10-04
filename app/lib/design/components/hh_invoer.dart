import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme.dart';
import '../dichtheid_scope.dart';

/// Tekstinvoer met het label erboven (niet zwevend in het veld: bij grote
/// tekst raakt een zwevend label in de knel). Hulptekst onder het veld,
/// foutstaat via [fouttekst], verplicht-markering met een sterretje dat
/// de schermlezer als "verplicht" hoort.
class HhInvoer extends StatelessWidget {
  const HhInvoer({
    required this.label,
    this.controller,
    this.hulptekst,
    this.fouttekst,
    this.isVerplicht = false,
    this.isActief = true,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.onChanged,
    this.onSubmitted,
    this.maxRegels = 1,
    this.inputFormatters,
    this.textCapitalization = TextCapitalization.none,
    super.key,
  }) : assert(maxRegels >= 1, 'minstens een regel');

  final String label;
  final TextEditingController? controller;
  final String? hulptekst;
  final String? fouttekst;
  final bool isVerplicht;
  final bool isActief;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  /// Meer dan 1: een meerregelig veld (toelichting, M4) dat meegroeit tot
  /// dit aantal regels en dan scrollt.
  final int maxRegels;

  /// Vormt de invoer tijdens het typen (bv. postcode: hoofdletters en een
  /// spatie na de cijfers).
  final List<TextInputFormatter>? inputFormatters;
  final TextCapitalization textCapitalization;

  static const verplichtWoord = 'verplicht';

  @override
  Widget build(BuildContext context) {
    final dichtheid = HhDichtheidScope.van(context);
    final tekst = Theme.of(context).textTheme;
    final schema = Theme.of(context).colorScheme;
    final tussenruimte = HhRuimte.voor(HhRuimte.xs, dichtheid);
    final minHoogte = HhMaten.knopHoogte(dichtheid);

    final labelStijl = tekst.bodyLarge!.copyWith(fontWeight: FontWeight.w600);

    // Een node voor de schermlezer: label, verplicht, waarde, hulptekst
    // en fout worden als een geheel voorgelezen.
    return MergeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text.rich(
            TextSpan(
              text: label,
              children: [
                if (isVerplicht)
                  TextSpan(
                    text: ' *',
                    semanticsLabel: ', $verplichtWoord',
                    style: TextStyle(color: schema.error),
                  ),
              ],
            ),
            style: labelStijl,
          ),
          SizedBox(height: tussenruimte),
          ConstrainedBox(
            constraints: BoxConstraints(minHeight: minHoogte),
            child: TextField(
              controller: controller,
              enabled: isActief,
              obscureText: obscureText,
              keyboardType:
                  keyboardType ??
                  (maxRegels > 1 ? TextInputType.multiline : null),
              textInputAction: textInputAction,
              minLines: 1,
              maxLines: maxRegels,
              autofillHints: autofillHints,
              inputFormatters: inputFormatters,
              textCapitalization: textCapitalization,
              onChanged: onChanged,
              onSubmitted: onSubmitted,
              // Naast het veld tikken haalt het toetsenbord weg. Nodig voor
              // het cijfer- en telefoonblok van iOS: die hebben geen Klaar
              // (Ibrahim 4 okt).
              onTapOutside: (_) =>
                  FocusManager.instance.primaryFocus?.unfocus(),
              style: tekst.bodyLarge,
              decoration: InputDecoration(
                helperText: hulptekst,
                helperStyle: tekst.bodyMedium,
                helperMaxLines: null,
                errorText: fouttekst,
                errorStyle: tekst.bodyMedium!.copyWith(color: schema.error),
                errorMaxLines: null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
