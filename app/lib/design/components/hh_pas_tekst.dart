import 'package:flutter/material.dart';

/// Tekst voor een smal vak (een tegel in de Keuzerij). Eén lang woord dat
/// niet past wordt iets kleiner in plaats van midden in het woord af te
/// breken ("Boodschapp-en"). Een tekst van meer woorden gaat gewoon tussen
/// de woorden naar een volgende regel.
///
/// Bewust zonder LayoutBuilder: de Keuzerij meet zijn tegels met
/// IntrinsicHeight en dat kan een LayoutBuilder niet aan.
class HhPasTekst extends StatelessWidget {
  const HhPasTekst(
    this.tekst, {
    required this.stijl,
    this.textAlign,
    super.key,
  });

  final String tekst;
  final TextStyle stijl;
  final TextAlign? textAlign;

  static final _witruimte = RegExp(r'\s');

  @override
  Widget build(BuildContext context) {
    final label = tekst.trim();
    if (label.contains(_witruimte)) {
      return Text(label, textAlign: textAlign, style: stijl);
    }
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(label, maxLines: 1, softWrap: false, style: stijl),
    );
  }
}
