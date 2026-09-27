import 'dart:async';

import '../../features/meldingen/model/hh_melding.dart';
import '../hh_fout.dart';
import '../result.dart';
import 'meldingen_gateway.dart';

/// Fake voor tests: nooit een verzoek naar de server. [zendUit] speelt een
/// melding na die de hook op de server maakt en die realtime binnenkomt.
/// Stuurbaar met [isOffline] en [volgendeFout].
class FakeMeldingenGateway implements MeldingenGateway {
  FakeMeldingenGateway({List<HhMelding> meldingen = const []})
    : _meldingen = [...meldingen];

  final List<HhMelding> _meldingen;
  final Map<String, StreamController<HhMelding>> _stromen = {};

  bool isOffline = false;
  HhFout? volgendeFout;
  int aantalLaadacties = 0;
  final List<String> gelezenGezet = [];

  List<HhMelding> get alleMeldingen => List.unmodifiable(_meldingen);

  HhFout? _neemFout() {
    if (isOffline) return const HhFout(HhFoutSoort.geenVerbinding);
    final fout = volgendeFout;
    volgendeFout = null;
    return fout;
  }

  /// Een melding die "op de server" ontstaat of wijzigt.
  void zendUit(HhMelding melding) {
    _meldingen
      ..removeWhere((m) => m.id == melding.id)
      ..add(melding);
    _stromen[melding.ontvangerId]?.add(melding);
  }

  @override
  Future<Result<List<HhMelding>>> meldingen(
    String ontvangerId, {
    int limiet = 50,
  }) async {
    aantalLaadacties++;
    final fout = _neemFout();
    if (fout != null) return Result.err(fout);
    final mijn =
        [
          for (final m in _meldingen)
            if (m.ontvangerId == ontvangerId) m,
        ]..sort(
          (a, b) =>
              (b.gemaakt ?? DateTime(0)).compareTo(a.gemaakt ?? DateTime(0)),
        );
    return Result.ok(mijn.take(limiet).toList());
  }

  @override
  Future<Result<HhMelding>> markeerGelezen(
    String meldingId,
    DateTime moment,
  ) async {
    final fout = _neemFout();
    if (fout != null) return Result.err(fout);
    final index = _meldingen.indexWhere((m) => m.id == meldingId);
    if (index == -1) return Result.err(const HhFout(HhFoutSoort.nietGevonden));
    final nieuw = _meldingen[index].gelezenOpMoment(moment);
    _meldingen[index] = nieuw;
    gelezenGezet.add(meldingId);
    return Result.ok(nieuw);
  }

  @override
  Stream<HhMelding> volg(String ontvangerId) {
    final bestaand = _stromen[ontvangerId];
    if (bestaand != null && !bestaand.isClosed) return bestaand.stream;
    final stroom = StreamController<HhMelding>.broadcast();
    _stromen[ontvangerId] = stroom;
    return stroom.stream;
  }

  /// Sluit de open stromen; tests roepen dit aan in addTearDown.
  Future<void> sluit() async {
    for (final stroom in _stromen.values) {
      if (!stroom.isClosed) await stroom.close();
    }
    _stromen.clear();
  }
}
