import '../../../../l10n/teksten_uitvoeren_nl.dart';
import '../../../jongere/klussen/domein/wanneer_tekst.dart';
import '../../../jongere/klussen/model/hh_klus.dart';
import 'afgerond_overzicht.dart';

/// Feedbackronde 1 punt E: zolang de klus niet af is, wat, wanneer, waar
/// en hoeveel in één kaart. Waar en bedrag vallen weg als ze er niet zijn;
/// zonder tijd staat er "Nog geen tijd afgesproken".
List<OverzichtRegel> klusSamenvatting(HhKlus klus, DateTime nu) {
  final wanneer = wanneerTekst(klus.wanneerVan, klus.wanneerTot, nu);
  final bedrag = klus.bedragBrutoCenten > 0
      ? klus.bedragBrutoCenten
      : klus.vergoedingJongereCenten;

  return [
    OverzichtRegel(
      TekstenUitvoerenNl.o7WatKop,
      klus.omschrijving.isEmpty
          ? metHoofdletter(klus.klustypeNaam)
          : klus.omschrijving,
    ),
    OverzichtRegel(
      TekstenUitvoerenNl.o7WanneerKop,
      wanneer.isEmpty ? TekstenUitvoerenNl.o7GeenTijd : wanneer,
    ),
    if (klus.adres.isNotEmpty)
      OverzichtRegel(TekstenUitvoerenNl.o7WaarKop, klus.adres),
    if (bedrag > 0)
      OverzichtRegel(
        TekstenUitvoerenNl.o7HoeveelKop,
        TekstenUitvoerenNl.o7BedragVoorbeeld(euroTekst(bedrag)),
      ),
  ];
}
