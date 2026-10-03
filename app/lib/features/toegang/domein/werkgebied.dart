import '../../../l10n/teksten_aanmelden_nl.dart';

/// hh_users.werkgebied_status (B2, script 81). De server zet hem bij
/// aanmelden uit de postcode (Nominatim, Tiel + 20 km):
///   binnen   -> wijk "Tiel en omstreken"
///   buiten   -> geen wijk
///   onbekend -> geocoding mislukt; geen wijk, de meldkamer ziet het
/// Leeg (bestaande accounts) is [onbepaald].
enum HhWerkgebiedStatus {
  onbepaald(''),
  binnen('binnen'),
  buiten('buiten'),
  onbekend('onbekend');

  const HhWerkgebiedStatus(this.code);

  final String code;

  static HhWerkgebiedStatus vanCode(String? code) {
    for (final s in values) {
      if (s.code == code) return s;
    }
    return HhWerkgebiedStatus.onbepaald;
  }
}

/// De melding voor iemand zonder wijk, of null als er een wijk is. Zonder
/// wijk ziet een helper geen klussen en kan een bewoner geen klus plaatsen
/// (de server laat een klus zonder wijk aan niemand zien).
String? werkgebiedMelding(String wijkId, HhWerkgebiedStatus status) {
  if (wijkId.isNotEmpty) return null;
  return status == HhWerkgebiedStatus.onbekend
      ? TekstenAanmeldenNl.adresOnbekend
      : TekstenAanmeldenNl.nietInBuurt;
}
