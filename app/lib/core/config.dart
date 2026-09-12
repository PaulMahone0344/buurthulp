/// Vaste configuratie voor de backend en de meldkamer. Geen enkele andere
/// plek in de app kent het serveradres of het telefoonnummer.
abstract final class HhConfig {
  /// Gedeelde productie-PocketBase; de auth-collectie is hh_users.
  static const baseUrl = 'https://api.qawayahbase.com';

  /// Placeholder tot de meldkamer een echt nummer heeft (app-plan, G8).
  static const meldkamerTelefoon = '0800-0000000';

  /// Minimale wachtwoordlengte, gelijk aan de PocketBase-standaard.
  static const wachtwoordMinLengte = 8;
}
