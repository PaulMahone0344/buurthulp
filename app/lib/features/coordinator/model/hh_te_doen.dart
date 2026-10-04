import 'package:flutter/foundation.dart';
import 'package:pocketbase/pocketbase.dart';

/// B11: wat de meldkamer in de app snel afhandelt (tab "Te doen"). De
/// lange lijsten en instellingen staan in het webpaneel (#/beheer).

/// Een helper die wacht op goedkeuring (hh_profielen, verificatiestatus
/// in_behandeling).
@immutable
class HhTeKeurenHelper {
  const HhTeKeurenHelper({
    required this.profielId,
    required this.gebruikerId,
    required this.naam,
    required this.geboortedatum,
    required this.aangemeldOp,
  });

  final String profielId;
  final String gebruikerId;
  final String naam;

  /// Null als de server geen datum kent.
  final DateTime? geboortedatum;
  final DateTime? aangemeldOp;

  static const expand = 'gebruiker';

  static HhTeKeurenHelper vanProfielRecord(RecordModel r) {
    final gebruiker = r.get<RecordModel?>('expand.gebruiker');
    return HhTeKeurenHelper(
      profielId: r.id,
      gebruikerId: r.getStringValue('gebruiker'),
      naam: gebruiker?.getStringValue('naam') ?? '',
      geboortedatum: _datum(gebruiker?.getStringValue('geboortedatum')),
      aangemeldOp: _datum(gebruiker?.getStringValue('created')),
    );
  }
}

/// Een ouder trok de toestemming in; de meldkamer geeft vrij zodat het kind
/// de ouder opnieuw kan mailen (B3).
@immutable
class HhOuderIngetrokken {
  const HhOuderIngetrokken({required this.helperId, required this.naam});

  final String helperId;
  final String naam;

  static const expand = 'helper';

  static HhOuderIngetrokken vanRecord(RecordModel r) {
    final helper = r.get<RecordModel?>('expand.helper');
    return HhOuderIngetrokken(
      helperId: r.getStringValue('helper'),
      naam: helper?.getStringValue('naam') ?? '',
    );
  }
}

/// Een open klus die de meldkamer nog niet keurde (B4).
@immutable
class HhTeKeurenKlus {
  const HhTeKeurenKlus({
    required this.id,
    required this.bewonerNaam,
    required this.soort,
    required this.omschrijving,
    required this.wanneerVan,
    required this.wanneerTot,
    required this.wachtOpBelletje,
  });

  final String id;
  final String bewonerNaam;
  final String soort;
  final String omschrijving;
  final DateTime? wanneerVan;
  final DateTime? wanneerTot;

  /// B11: eerst de kennismaking met de bewoner (goedkeuren kan dan niet).
  final bool wachtOpBelletje;

  static const expand = 'hulpvrager,klustype';

  /// Open, nog niet goed- of afgekeurd.
  static const filter =
      'status = "open" && klus_goedgekeurd_op = "" && klus_afgekeurd_op = ""';

  static HhTeKeurenKlus vanRecord(RecordModel r) {
    return HhTeKeurenKlus(
      id: r.id,
      bewonerNaam:
          r.get<RecordModel?>('expand.hulpvrager')?.getStringValue('naam') ??
          '',
      soort:
          r.get<RecordModel?>('expand.klustype')?.getStringValue('naam') ?? '',
      omschrijving: r.getStringValue('omschrijving'),
      wanneerVan: _datum(r.getStringValue('wanneer_van')),
      wanneerTot: _datum(r.getStringValue('wanneer_tot')),
      wachtOpBelletje: r.data['wacht_op_kennismaking'] == true,
    );
  }
}

/// Een nieuwe bewoner om te bellen voor de kennismaking (B11).
@immutable
class HhTeBellen {
  const HhTeBellen({
    required this.id,
    required this.naam,
    required this.telefoon,
    required this.plaats,
  });

  final String id;
  final String naam;
  final String telefoon;
  final String plaats;

  static const filter =
      'rol = "hulpvrager" && kennismaking_status = "nog" && geblokkeerd = false';

  static HhTeBellen vanRecord(RecordModel r) {
    return HhTeBellen(
      id: r.id,
      naam: r.getStringValue('naam'),
      telefoon: r.getStringValue('telefoon'),
      plaats: r.getStringValue('plaats'),
    );
  }
}

/// Alles van het tabblad "Te doen" in één keer.
@immutable
class HhTeDoen {
  const HhTeDoen({
    this.bellen = const [],
    this.helpers = const [],
    this.ouders = const [],
    this.klussen = const [],
  });

  final List<HhTeBellen> bellen;
  final List<HhTeKeurenHelper> helpers;
  final List<HhOuderIngetrokken> ouders;
  final List<HhTeKeurenKlus> klussen;

  /// Voor de teller op de tab.
  int get totaal =>
      bellen.length + helpers.length + ouders.length + klussen.length;

  bool get isLeeg => totaal == 0;
}

/// Gesproken of geweigerd na het kennismakingsbelletje.
enum KennismakingBesluit { gesproken, geweigerd }

/// Wat de server meldt na een kennismaking.
@immutable
class KennismakingUitkomst {
  const KennismakingUitkomst({this.geannuleerd = 0, this.lopend = 0});

  /// Open klussen zonder helper die (bij geweigerd) geannuleerd zijn.
  final int geannuleerd;

  /// Klussen met een helper die nog lopen; die kijkt de meldkamer zelf na.
  final int lopend;
}

DateTime? _datum(String? waarde) {
  final tekst = (waarde ?? '').trim();
  if (tekst.isEmpty) return null;
  return DateTime.tryParse(tekst.replaceFirst(' ', 'T'));
}
