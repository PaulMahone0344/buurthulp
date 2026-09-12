Router, guard, dichtheid en de opstart van de app.
main.dart verwijst hierheen voor ProviderScope en MaterialApp.router.
paden.dart          alle routepaden
router.dart         GoRouter + toegangRedirect (sessie-guard)
dichtheid_controller.dart  dichtheid afgeleid van de rol (geen handmatige zet)
navigatie.dart      terugOf(): terug als het kan, anders naar een vast pad
screens/dev_screen.dart    alleen in debug-builds, op /dev
