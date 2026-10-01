import 'package:flutter/foundation.dart';
import 'package:pocketbase/pocketbase.dart';

/// hh_koppelingen.status (M9, script 40).
enum KoppelingStatus {
  aangevraagd('aangevraagd'),
  actief('actief');

  const KoppelingStatus(this.code);

  final String code;

  /// Leeg of onbekend telt als aangevraagd: liever te weinig tonen dan te
  /// veel. (Na script 40 heeft elke koppeling een status.)
  static KoppelingStatus vanCode(String code) =>
      code == actief.code ? actief : aangevraagd;
}

/// hh_koppelingen.rechten.
enum FamilieRecht {
  meekijken('meekijken'),
  plaatsen('plaatsen');

  const FamilieRecht(this.code);

  final String code;

  static Set<FamilieRecht> uitCodes(Iterable<String> codes) => {
    for (final code in codes)
      for (final recht in values)
        if (recht.code == code) recht,
  };
}

/// Eén koppeling tussen een oudere en een familielid (M9). Onveranderlijk.
/// [oudereNaam] komt uit de expand van oudere (het familielid ziet die
/// pas bij een actieve koppeling), [familielidNaam] uit die van familielid
/// (de oudere ziet die altijd, ook bij een aanvraag).
@immutable
class HhKoppeling {
  const HhKoppeling({
    required this.id,
    required this.oudereId,
    required this.familielidId,
    required this.status,
    this.rechten = const {},
    this.oudereNaam = '',
    this.familielidNaam = '',
  });

  static const collectie = 'hh_koppelingen';

  final String id;
  final String oudereId;
  final String familielidId;
  final KoppelingStatus status;
  final Set<FamilieRecht> rechten;
  final String oudereNaam;
  final String familielidNaam;

  bool get isActief => status == KoppelingStatus.actief;

  factory HhKoppeling.vanRecord(RecordModel record) {
    final oudere = record.get<RecordModel?>('expand.oudere');
    final familielid = record.get<RecordModel?>('expand.familielid');
    return HhKoppeling(
      id: record.id,
      oudereId: record.getStringValue('oudere'),
      familielidId: record.getStringValue('familielid'),
      status: KoppelingStatus.vanCode(record.getStringValue('status')),
      rechten: FamilieRecht.uitCodes(record.getListValue<String>('rechten')),
      oudereNaam: oudere?.getStringValue('naam') ?? '',
      familielidNaam: familielid?.getStringValue('naam') ?? '',
    );
  }

  HhKoppeling metActief() => HhKoppeling(
    id: id,
    oudereId: oudereId,
    familielidId: familielidId,
    status: KoppelingStatus.actief,
    rechten: rechten.isEmpty ? FamilieRecht.values.toSet() : rechten,
    oudereNaam: oudereNaam,
    familielidNaam: familielidNaam,
  );

  @override
  bool operator ==(Object other) =>
      other is HhKoppeling &&
      other.id == id &&
      other.status == status &&
      setEquals(other.rechten, rechten) &&
      other.oudereNaam == oudereNaam &&
      other.familielidNaam == familielidNaam;

  @override
  int get hashCode =>
      Object.hash(id, status, Object.hashAllUnordered(rechten), oudereNaam);
}
