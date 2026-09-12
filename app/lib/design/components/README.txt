De acht bouwstenen van HeitjeHulp, allemaal met Hh-prefix.

hh_knop.dart        HhKnop       primair / tweedeKeus / tekst / gevaar,
                                 maat normaal of groot, isBezig, uitgeschakeld
hh_kaart.dart       HhKaart      oppervlak met rand, optionele kop en actie
hh_invoer.dart      HhInvoer     label, hulptekst, fouttekst, verplicht
hh_keuzerij.dart    HhKeuzerij   keuzeknoppen met icoon, een of meer
hh_stapbalk.dart    HhStapbalk   "Stap 2 van 4" met voortgang
hh_lege_staat.dart  HhLegeStaat  icoon, titel, uitleg, optionele knop
hh_laad_staat.dart  HhLaadStaat  .spinner() en .skelet()
hh_meld_balk.dart   HhMeldBalk   informatie / geslaagd / waarschuwing / fout

Regels:
- geen kleur of maat hier; alles via ../../theme.dart
- dichtheid via HhDichtheidScope.van(context)
- elke widget heeft een Semantics-label of neemt er een aan
- tekst wikkelt bij 200 procent, nooit kleiner maken
