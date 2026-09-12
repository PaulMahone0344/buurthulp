import 'package:flutter_test/flutter_test.dart';
import 'package:heitjehulp_app/features/hulpvrager/model/hulpvraag_concept.dart';
import 'package:heitjehulp_app/features/jongere/klussen/domein/dagdeel.dart';
import 'package:heitjehulp_app/l10n/teksten_klussen_nl.dart';

void main() {
  group('dagdeelVan', () {
    test('null zonder begintijd', () {
      expect(dagdeelVan(null), isNull);
    });

    test('voor 12 uur is ochtend, 12 tot 18 middag, daarna avond', () {
      expect(dagdeelVan(DateTime(2026, 9, 16, 0)), HhDagdeel.ochtend);
      expect(dagdeelVan(DateTime(2026, 9, 16, 9)), HhDagdeel.ochtend);
      expect(dagdeelVan(DateTime(2026, 9, 16, 11, 59)), HhDagdeel.ochtend);
      expect(dagdeelVan(DateTime(2026, 9, 16, 12)), HhDagdeel.middag);
      expect(dagdeelVan(DateTime(2026, 9, 16, 17, 59)), HhDagdeel.middag);
      expect(dagdeelVan(DateTime(2026, 9, 16, 18)), HhDagdeel.avond);
      expect(dagdeelVan(DateTime(2026, 9, 16, 23)), HhDagdeel.avond);
    });

    test(
      'rekent met de LOKALE tijd van een UTC-moment (server bewaart UTC)',
      () {
        // 14:00 lokaal, wat de tijdzone van de testmachine ook is.
        final lokaal = DateTime(2026, 9, 16, 14);
        expect(dagdeelVan(lokaal.toUtc()), HhDagdeel.middag);
        final avond = DateTime(2026, 9, 16, 19);
        expect(dagdeelVan(avond.toUtc()), HhDagdeel.avond);
      },
    );
  });

  test('dagdeelNaam geeft de Nederlandse naam', () {
    expect(dagdeelNaam(HhDagdeel.ochtend), TekstenKlussenNl.dagdeelOchtend);
    expect(dagdeelNaam(HhDagdeel.middag), TekstenKlussenNl.dagdeelMiddag);
    expect(dagdeelNaam(HhDagdeel.avond), TekstenKlussenNl.dagdeelAvond);
  });
}
