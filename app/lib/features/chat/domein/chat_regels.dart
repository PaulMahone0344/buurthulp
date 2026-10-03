import 'package:flutter/foundation.dart';

import '../../../l10n/teksten_chat_nl.dart';
import '../../../l10n/teksten_klussen_nl.dart';
import '../../../theme.dart';
import '../../jongere/klussen/domein/wanneer_tekst.dart'
    show metHoofdletter, tijdTekst;
import '../../jongere/klussen/model/hh_klus.dart';
import '../../jongere/uitvoeren/model/hh_klus_logregel.dart';
import '../../toegang/model/hh_rol.dart';
import '../model/hh_bericht.dart';

/// Na afgerond of geannuleerd blijft de chat nog zo lang open om te
/// schrijven. Gelijk aan CHAT_DICHT_NA_UREN in de hook (hh_chat_hulp.js);
/// de server beslist, de app toont alleen vast de juiste stand.
const chatDichtNa = Duration(hours: 72);

enum ChatStand {
  /// Schrijven mag.
  open,

  /// Afgelopen en langer dan [chatDichtNa] geleden: alleen lezen.
  dicht,

  /// Geen helper (of de klus staat op concept/open): geen gesprek.
  geenHelper,
}

const _looptStatussen = {
  HhKlusStatus.geaccepteerd,
  HhKlusStatus.onderweg,
  HhKlusStatus.bezig,
  HhKlusStatus.probleem,
};
const _afgelopenStatussen = {HhKlusStatus.afgerond, HhKlusStatus.geannuleerd};

/// De stand van de chat, gespiegeld aan chatStand() in hh_chat_hulp.js. Het
/// moment van afloop komt uit de LAATSTE logregel naar de huidige status;
/// zonder logregel: dicht (liever dicht dan open, zoals de server).
ChatStand chatStandVan(
  HhKlus klus,
  List<HhKlusLogregel> logregels,
  DateTime nu,
) {
  if (klus.toegewezenJongereId.isEmpty) return ChatStand.geenHelper;
  if (_looptStatussen.contains(klus.status)) return ChatStand.open;
  if (!_afgelopenStatussen.contains(klus.status)) return ChatStand.geenHelper;
  DateTime? sinds;
  for (final regel in logregels) {
    final wanneer = regel.wanneer;
    if (regel.naar != klus.status || wanneer == null) continue;
    if (sinds == null || wanneer.isAfter(sinds)) sinds = wanneer;
  }
  if (sinds == null) return ChatStand.dicht;
  return nu.difference(sinds) <= chatDichtNa ? ChatStand.open : ChatStand.dicht;
}

/// Hoort er een Chat-knop bij deze klus? Bij elke klus met een helper die
/// loopt of afgelopen is (na afloop om terug te lezen).
bool heeftChat(HhKlus klus) =>
    klus.toegewezenJongereId.isNotEmpty &&
    (_looptStatussen.contains(klus.status) ||
        _afgelopenStatussen.contains(klus.status));

/// Drie snelle berichten per kant. Een snelknop is een gewoon bericht; de
/// status wisselt alleen via de knoppen van M6.
List<String> snelknoppenVoor(HhRol rol) => switch (rol) {
  HhRol.jongere => TekstenChatNl.snelHelper,
  HhRol.hulpvrager => TekstenChatNl.snelBewoner,
  _ => const [],
};

/// Een bericht (uit realtime of na versturen) in de lijst: een bestaande
/// (zelfde id) wordt vervangen, een nieuwe erbij; oudste boven.
List<HhBericht> voegBerichtIn(List<HhBericht> lijst, HhBericht bericht) {
  final nieuw = [
    for (final b in lijst)
      if (b.id != bericht.id) b,
    bericht,
  ];
  nieuw.sort((a, b) {
    final ta = a.gemaakt;
    final tb = b.gemaakt;
    if (ta == null && tb == null) return a.id.compareTo(b.id);
    if (ta == null) return 1;
    if (tb == null) return -1;
    final c = ta.compareTo(tb);
    return c != 0 ? c : a.id.compareTo(b.id);
  });
  return List.unmodifiable(nieuw);
}

/// De berichten van de ander die ik nog niet gelezen heb.
List<HhBericht> ongelezenVoor(List<HhBericht> lijst, String ikId) => [
  for (final b in lijst)
    if (!b.isVan(ikId) && !b.isGelezen) b,
];

/// Een regel in de chatlijst: een dagkop of een bericht.
@immutable
sealed class ChatRegel {
  const ChatRegel();
}

final class ChatDagKop extends ChatRegel {
  const ChatDagKop(this.label);
  final String label;
}

final class ChatBerichtRegel extends ChatRegel {
  const ChatBerichtRegel({
    required this.bericht,
    required this.isVanMij,
    required this.toonGelezen,
  });

  final HhBericht bericht;
  final bool isVanMij;

  /// "Gelezen" onder mijn LAATSTE bericht dat de ander las (zoals de mockup).
  final bool toonGelezen;
}

/// Berichten (oudste eerst) met een dagkop bij elke nieuwe lokale dag.
List<ChatRegel> chatIndeling(
  List<HhBericht> berichten, {
  required String ikId,
  required DateTime nu,
}) {
  String? laatsteGelezenVanMij;
  for (final b in berichten) {
    if (b.isVan(ikId) && b.isGelezen) laatsteGelezenVanMij = b.id;
  }
  final regels = <ChatRegel>[];
  DateTime? vorigeDag;
  for (final b in berichten) {
    final moment = b.gemaakt;
    if (moment != null) {
      final dag = _dag(moment.toLocal());
      if (vorigeDag == null || dag != vorigeDag) {
        regels.add(ChatDagKop(chatDagLabel(moment, nu)));
        vorigeDag = dag;
      }
    }
    regels.add(
      ChatBerichtRegel(
        bericht: b,
        isVanMij: b.isVan(ikId),
        toonGelezen: b.id == laatsteGelezenVanMij,
      ),
    );
  }
  return List.unmodifiable(regels);
}

DateTime _dag(DateTime t) => DateTime(t.year, t.month, t.day);

/// "Vandaag", "Gisteren" of "Vrijdag 2 oktober" (lokale dag).
String chatDagLabel(DateTime moment, DateTime nu) {
  final dag = _dag(moment.toLocal());
  final vandaag = _dag(nu.toLocal());
  if (dag == vandaag) return TekstenChatNl.vandaag;
  if (dag == DateTime(vandaag.year, vandaag.month, vandaag.day - 1)) {
    return TekstenChatNl.gisteren;
  }
  return metHoofdletter(_datum(dag));
}

String _datum(DateTime dag) {
  final weekdag = TekstenKlussenNl.weekdagen[dag.weekday - DateTime.monday];
  final maand = TekstenKlussenNl.maanden[dag.month - DateTime.january];
  return '$weekdag ${dag.day} $maand';
}

String chatVoornaam(String naam) {
  final delen = naam.trim().split(RegExp(r'\s+'));
  return delen.isEmpty ? '' : delen.first;
}

/// "Tuin · zaterdag 10 oktober 10:00", zonder tijd alleen "Tuin".
String chatOndertitel(String klussoort, DateTime? wanneer, DateTime nu) {
  final soort = metHoofdletter(klussoort);
  if (wanneer == null) return soort;
  final moment = '${_datum(_dag(wanneer.toLocal()))} ${tijdTekst(wanneer)}';
  return soort.isEmpty ? moment : '$soort · $moment';
}
