import '../../features/coordinator/model/hh_te_doen.dart';
import '../hh_fout.dart';
import '../result.dart';
import 'meldkamer_gateway.dart';

/// Fake voor tests (B11): nooit een verzoek naar de server. Houdt "Te doen"
/// in het geheugen; elke handeling haalt het item uit de lijst en wordt in
/// [aanroepen] bewaard. Stuurbaar met [volgendeFout] (de eerstvolgende
/// handeling of het laden geeft deze fout) en [geannuleerdBijWeigeren].
class FakeMeldkamerGateway implements MeldkamerGateway {
  FakeMeldkamerGateway({HhTeDoen stand = const HhTeDoen()}) : _stand = stand;

  HhTeDoen _stand;
  HhFout? volgendeFout;
  int geannuleerdBijWeigeren = 0;
  int aantalLaden = 0;
  final List<String> aanroepen = [];

  HhTeDoen get stand => _stand;

  Result<T>? _fout<T>() {
    final fout = volgendeFout;
    if (fout == null) return null;
    volgendeFout = null;
    return Err(fout);
  }

  @override
  Future<Result<HhTeDoen>> teDoen() async {
    aantalLaden++;
    return _fout() ?? Ok(_stand);
  }

  @override
  Future<Result<KennismakingUitkomst>> kennismaking(
    String bewonerId,
    KennismakingBesluit besluit,
    String notitie,
  ) async {
    aanroepen.add('kennismaking $bewonerId ${besluit.name} $notitie');
    final fout = _fout<KennismakingUitkomst>();
    if (fout != null) return fout;
    _stand = HhTeDoen(
      bellen: [..._stand.bellen.where((b) => b.id != bewonerId)],
      helpers: _stand.helpers,
      ouders: _stand.ouders,
      klussen: _stand.klussen,
    );
    return Ok(
      KennismakingUitkomst(
        geannuleerd: besluit == KennismakingBesluit.geweigerd
            ? geannuleerdBijWeigeren
            : 0,
      ),
    );
  }

  @override
  Future<Result<void>> beoordeelHelper(
    String profielId, {
    required bool goedkeuren,
    required String notitie,
  }) async {
    aanroepen.add(
      'helper $profielId ${goedkeuren ? 'goedgekeurd' : 'afgewezen'} $notitie',
    );
    final fout = _fout<void>();
    if (fout != null) return fout;
    _stand = HhTeDoen(
      bellen: _stand.bellen,
      helpers: [..._stand.helpers.where((h) => h.profielId != profielId)],
      ouders: _stand.ouders,
      klussen: _stand.klussen,
    );
    return const Ok(null);
  }

  @override
  Future<Result<void>> ouderVrijgeven(String helperId) async {
    aanroepen.add('ouder $helperId');
    final fout = _fout<void>();
    if (fout != null) return fout;
    _stand = HhTeDoen(
      bellen: _stand.bellen,
      helpers: _stand.helpers,
      ouders: [..._stand.ouders.where((o) => o.helperId != helperId)],
      klussen: _stand.klussen,
    );
    return const Ok(null);
  }

  @override
  Future<Result<void>> keurKlus(
    String klusId, {
    required bool goedkeuren,
    String reden = '',
  }) async {
    aanroepen.add(
      'klus $klusId ${goedkeuren ? 'goedkeuren' : 'afkeuren'} $reden'.trim(),
    );
    final fout = _fout<void>();
    if (fout != null) return fout;
    _stand = HhTeDoen(
      bellen: _stand.bellen,
      helpers: _stand.helpers,
      ouders: _stand.ouders,
      klussen: [..._stand.klussen.where((k) => k.id != klusId)],
    );
    return const Ok(null);
  }
}
