/// Het routepad van de chat (B6). Niet onder /jongere of /hulpvrager: de
/// bewoner en de helper komen op hetzelfde scherm.
abstract final class HhPadenChat {
  static const _basis = '/chat';
  static const patroon = '$_basis/:id';

  static String chat(String klusId) => '$_basis/$klusId';
}
