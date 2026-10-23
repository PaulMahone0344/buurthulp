// DEMO — de schakelaar. Aan met:
//   flutter run --dart-define=HH_DEMO=true
// Dan praat de app nergens met de server: alle gateways zijn fakes met
// nepgegevens, en G2 toont een knop per rol om meteen in te loggen.
// Een gewone build (zonder de vlag) kent de demo niet.

const isDemoModus = bool.fromEnvironment('HH_DEMO');
