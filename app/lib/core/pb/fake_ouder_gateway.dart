import '../../features/jongere/ouder/model/hh_ouder_stand.dart';
import '../hh_fout.dart';
import '../result.dart';
import 'ouder_gateway.dart';

/// Nep voor tests: doet wat de hook doet (max 3 mails per dag, nieuw adres
/// bewaren), zonder server en zonder mail.
class FakeOuderGateway implements OuderGateway {
  FakeOuderGateway({HhOuderStand stand = const HhOuderStand()})
    : _stand = stand;

  HhOuderStand _stand;
  final List<String?> verstuurd = [];

  /// Zet [faalt] om de server onbereikbaar te maken.
  bool faalt = false;

  /// Zet om de hook een keer te laten weigeren (bv. eigenadres).
  OuderGeweigerd? weigerMet;

  HhOuderStand get stand => _stand;

  /// Doet alsof de ouder iets deed op de website.
  void zetStand(HhOuderStand stand) => _stand = stand;

  @override
  Future<Result<HhOuderStand>> haalStand() async => faalt
      ? Result.err(const HhFout(HhFoutSoort.geenVerbinding))
      : Result.ok(_stand);

  @override
  Future<OuderVerstuurUitkomst> verstuur({String? ouderEmail}) async {
    if (faalt) {
      return const OuderVerstuurFout(HhFout(HhFoutSoort.geenVerbinding));
    }
    final weiger = weigerMet;
    if (weiger != null) {
      weigerMet = null;
      return weiger;
    }
    final email = (ouderEmail ?? '').trim().isNotEmpty
        ? ouderEmail!.trim().toLowerCase()
        : _stand.ouderEmail;
    if (email.isEmpty) {
      return const OuderGeweigerd(
        'email',
        'Vul het e-mailadres van je ouder in.',
      );
    }
    if (!_stand.kanOpnieuw) {
      return const OuderGeweigerd(
        'limiet',
        'Je hebt vandaag al 3 keer een mail gestuurd. Probeer het morgen opnieuw.',
      );
    }
    verstuurd.add(ouderEmail);
    _stand = HhOuderStand(
      status: HhOuderStatus.verstuurd,
      ouderEmail: email,
      verstuurdOp: DateTime.utc(2026, 10, 4, 10),
      nogTeSturen: _stand.nogTeSturen - 1,
    );
    return OuderVerstuurd(_stand);
  }
}
