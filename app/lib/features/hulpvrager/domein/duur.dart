import '../../../l10n/teksten_hulpvrager_nl.dart';

const _minutenPerUur = 60;
const _minutenPerKwartier = 15;
const _minutenPerHalfUur = 30;
const _minutenPerAnderhalfUur = 90;

/// Richtduur in gewone taal: "ongeveer 1 uur", "ongeveer 45 minuten",
/// "ongeveer anderhalf uur". Nul of negatief: "wordt afgesproken met de
/// helper".
String duurTekst(int minuten) {
  if (minuten <= 0) return TekstenHulpvragerNl.duurOnbekend;
  final ongeveer = TekstenHulpvragerNl.ongeveer;
  final uur = TekstenHulpvragerNl.uur;
  return switch (minuten) {
    _minutenPerKwartier => '$ongeveer ${TekstenHulpvragerNl.kwartier}',
    _minutenPerHalfUur => '$ongeveer ${TekstenHulpvragerNl.halfUur}',
    _minutenPerAnderhalfUur => '$ongeveer ${TekstenHulpvragerNl.anderhalfUur}',
    _ when minuten % _minutenPerUur == 0 =>
      '$ongeveer ${minuten ~/ _minutenPerUur} $uur',
    _ when minuten < _minutenPerUur =>
      '$ongeveer $minuten ${TekstenHulpvragerNl.minuten}',
    _ =>
      '$ongeveer ${minuten ~/ _minutenPerUur} $uur en '
          '${minuten % _minutenPerUur} ${TekstenHulpvragerNl.minuten}',
  };
}
