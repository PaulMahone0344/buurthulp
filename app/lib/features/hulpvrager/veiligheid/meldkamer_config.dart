import '../../../core/config.dart';

/// Het nummer van de meldkamer voor O10 en O11 (M8).
///
/// PLACEHOLDER: 0800-0000000 is geen echt nummer. Mozaiek moet het echte
/// meldkamernummer nog geven (OPEN-PUNTEN-M8). Het staat nu nog op één plek
/// (HhConfig, ook gebruikt door G8, J9 en O1), zodat het bij het invullen
/// niet uit elkaar kan lopen: vul het echte nummer daar in.
abstract final class MeldkamerConfig {
  static const telefoon = HhConfig.meldkamerTelefoon;

  /// Waar in de app zichtbaar mag zijn dat het nog een voorbeeldnummer is.
  static const isPlaceholder = telefoon == '0800-0000000';
}
