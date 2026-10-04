import '../../features/jongere/xp/model/hh_xp.dart';
import '../result.dart';
import 'pocketbase_gateway.dart';

/// De routes uit backend/pb_hooks/hh_xp.pb.js (B9).
const hhXpMijnPad = '/api/hh/xp/mijn';
const hhXpVerklaringPad = '/api/hh/xp/verklaring';

/// De publieke pagina waar een verklaring met de controlecode te zien en te
/// printen is (website, #/verklaring/<code>). Werkt pas als de site online is.
Uri verklaringWebUrl(String code) => Uri.parse(
  'https://heitjehulp.nl/#/verklaring/${Uri.encodeComponent(code)}',
);

/// B9: XP, niveau, badges, verdiensten en de verklaring van inzet. Het
/// rekenen doet de server; de app leest alleen.
abstract interface class XpGateway {
  /// GET /api/hh/xp/mijn (alleen helpers).
  Future<Result<HhXpOverzicht>> mijnOverzicht();

  /// POST /api/hh/xp/verklaring: maakt een verklaring (of geeft de laatste
  /// terug als er sindsdien niets veranderde).
  Future<Result<HhVerklaring>> maakVerklaring();
}

class PocketBaseXpGateway implements XpGateway {
  const PocketBaseXpGateway(this._gateway);

  final PocketBaseGateway _gateway;

  @override
  Future<Result<HhXpOverzicht>> mijnOverzicht() {
    return _gateway.voerUit((client) async {
      final antwoord = await client.send(hhXpMijnPad, method: 'GET');
      return HhXpOverzicht.vanJson(_alsMap(antwoord));
    });
  }

  @override
  Future<Result<HhVerklaring>> maakVerklaring() {
    return _gateway.voerUit((client) async {
      final antwoord = await client.send(hhXpVerklaringPad, method: 'POST');
      return HhVerklaring.vanJson(_alsMap(antwoord));
    });
  }

  static Map<String, dynamic> _alsMap(Object? waarde) =>
      waarde is Map ? waarde.map((k, v) => MapEntry('$k', v)) : const {};
}
