import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:heitjehulp_app/core/hh_fout.dart';
import 'package:heitjehulp_app/core/pb/auth_gateway.dart';
import 'package:heitjehulp_app/core/pb/pocketbase_gateway.dart';
import 'package:heitjehulp_app/core/result.dart';
import 'package:heitjehulp_app/features/toegang/domein/aanmelding.dart';
import 'package:heitjehulp_app/features/toegang/model/hh_gebruiker.dart';
import 'package:heitjehulp_app/features/toegang/model/hh_rol.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pocketbase/pocketbase.dart';

/// Een opgenomen verzoek: methode, pad en JSON-body.
class _Verzoek {
  _Verzoek(this.methode, this.pad, this.body);

  final String methode;
  final String pad;
  final Map<String, dynamic> body;
}

/// Bouwt een gateway op een nep-http-client. [antwoorden] geeft per
/// (methode, pad) het antwoord; alles wat niet is ingesteld geeft 404.
class _NepServer {
  final List<_Verzoek> verzoeken = [];
  final Map<String, http.Response> antwoorden = {};
  Exception? gooi;

  void zet(String methode, String pad, int status, Map<String, dynamic> body) {
    antwoorden['$methode $pad'] = http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json'},
    );
  }

  PocketBaseAuthGateway gateway() {
    final client = PocketBase(
      'https://nep.test',
      httpClientFactory: () => MockClient((verzoek) async {
        if (gooi != null) throw gooi!;
        final body = verzoek.body.isEmpty
            ? <String, dynamic>{}
            : jsonDecode(verzoek.body) as Map<String, dynamic>;
        verzoeken.add(_Verzoek(verzoek.method, verzoek.url.path, body));
        return antwoorden['${verzoek.method} ${verzoek.url.path}'] ??
            http.Response('{"status":404,"message":"x","data":{}}', 404);
      }),
    );
    return PocketBaseAuthGateway(PocketBaseClientGateway(client: client));
  }
}

Map<String, dynamic> _record(HhRol rol) => {
  'id': 'abc123',
  'collectionName': hhUsersCollectie,
  'email': 'iemand@voorbeeld.nl',
  'naam': 'Iemand',
  'rol': rol.code,
  'taal': 'nl',
  'verified': false,
};

Map<String, dynamic> _auth(HhRol rol) => {
  'token': 'nep-token',
  'record': _record(rol),
};

const _basis = '/api/collections/hh_users';

const _bewoner = BewonerAanmelding(
  naam: 'Iemand',
  email: 'iemand@voorbeeld.nl',
  wachtwoord: 'wachtwoord1',
  straat: 'Dorpsstraat',
  huisnummer: '1',
  postcode: '4003 AB',
  plaats: 'Tiel',
);

void main() {
  group('PocketBaseAuthGateway.registreren', () {
    test('stuurt rol, taal nl en passwordConfirm mee en logt in', () async {
      final server = _NepServer()
        ..zet('POST', '$_basis/records', 200, _record(HhRol.jongere))
        ..zet('POST', '$_basis/auth-with-password', 200, _auth(HhRol.jongere))
        ..zet('POST', '$_basis/request-verification', 204, {});

      final result = await server.gateway().registreren(
        HelperAanmelding(
          voornaam: 'Iemand',
          email: 'iemand@voorbeeld.nl',
          wachtwoord: 'wachtwoord1',
          geboortedatum: DateTime.utc(2012, 5, 14),
          postcode: '4003ab',
          huisnummer: '7',
          ouderEmail: 'ouder@voorbeeld.nl',
        ),
      );

      expect(result, isA<Ok<HhGebruiker>>());
      final create = server.verzoeken.firstWhere(
        (v) => v.pad == '$_basis/records',
      );
      expect(create.body['rol'], 'jongere');
      expect(create.body['taal'], 'nl');
      expect(create.body['passwordConfirm'], 'wachtwoord1');
      expect(create.body.containsKey('telefoon'), isFalse);
      expect(create.body['naam'], 'Iemand');
      expect(create.body['geboortedatum'], '2012-05-14T00:00:00.000Z');
      expect(create.body['postcode'], '4003 AB');
      expect(create.body['huisnummer'], '7');
      expect(create.body['ouder_email'], 'ouder@voorbeeld.nl');
      expect(
        server.verzoeken.map((v) => v.pad),
        contains('$_basis/request-verification'),
      );
      final gebruiker = (result as Ok<HhGebruiker>).waarde;
      expect(gebruiker.rol, HhRol.jongere);
      expect(gebruiker.taal, HhTaal.nl);
    });

    test('e-mail bestaat al wordt vertaald', () async {
      final server = _NepServer()
        ..zet('POST', '$_basis/records', 400, {
          'data': {
            'email': {'code': 'validation_not_unique', 'message': 'x'},
          },
          'message': 'Failed to create record.',
          'status': 400,
        });

      final result = await server.gateway().registreren(_bewoner);

      expect(
        (result as Err<HhGebruiker>).fout.soort,
        HhFoutSoort.emailBestaatAl,
      );
    });

    test('mislukte verificatiemail laat de registratie slagen', () async {
      final server = _NepServer()
        ..zet('POST', '$_basis/records', 200, _record(HhRol.hulpvrager))
        ..zet(
          'POST',
          '$_basis/auth-with-password',
          200,
          _auth(HhRol.hulpvrager),
        )
        ..zet('POST', '$_basis/request-verification', 500, {
          'data': {},
          'message': 'mail kapot',
          'status': 500,
        });

      final result = await server.gateway().registreren(_bewoner);

      expect(result, isA<Ok<HhGebruiker>>());
    });
  });

  group('PocketBaseAuthGateway.inloggen', () {
    test('Failed to authenticate wordt ongeldige inlog', () async {
      final server = _NepServer()
        ..zet('POST', '$_basis/auth-with-password', 400, {
          'data': {},
          'message': 'Failed to authenticate.',
          'status': 400,
        });

      final result = await server.gateway().inloggen(
        email: 'iemand@voorbeeld.nl',
        wachtwoord: 'fout',
      );

      expect(
        (result as Err<HhGebruiker>).fout.soort,
        HhFoutSoort.ongeldigeInlog,
      );
    });

    test('403 wordt e-mail nog niet bevestigd', () async {
      final server = _NepServer()
        ..zet('POST', '$_basis/auth-with-password', 403, {
          'data': {},
          'message': 'verified = true',
          'status': 403,
        });

      final result = await server.gateway().inloggen(
        email: 'iemand@voorbeeld.nl',
        wachtwoord: 'wachtwoord1',
      );

      expect(
        (result as Err<HhGebruiker>).fout.soort,
        HhFoutSoort.emailNietBevestigd,
      );
    });

    test('SocketException wordt geen verbinding', () async {
      final server = _NepServer()..gooi = const SocketException('offline');

      final result = await server.gateway().inloggen(
        email: 'iemand@voorbeeld.nl',
        wachtwoord: 'wachtwoord1',
      );

      expect(
        (result as Err<HhGebruiker>).fout.soort,
        HhFoutSoort.geenVerbinding,
      );
    });

    test('onbekende rol in het record is een nette fout, geen crash', () async {
      final server = _NepServer()
        ..zet('POST', '$_basis/auth-with-password', 200, {
          'token': 't',
          'record': {..._record(HhRol.jongere), 'rol': 'beheerder'},
        });

      final result = await server.gateway().inloggen(
        email: 'iemand@voorbeeld.nl',
        wachtwoord: 'wachtwoord1',
      );

      expect((result as Err<HhGebruiker>).fout.soort, HhFoutSoort.onbekend);
    });
  });

  group('PocketBaseAuthGateway.sessieHerstellen', () {
    test('401 bij verversen wordt niet ingelogd', () async {
      final server = _NepServer()
        ..zet('POST', '$_basis/auth-refresh', 401, {
          'data': {},
          'message': 'The request requires valid record authorization token.',
          'status': 401,
        });

      final result = await server.gateway().sessieHerstellen('oud-token');

      expect((result as Err<HhGebruiker>).fout.soort, HhFoutSoort.nietIngelogd);
    });

    test('geslaagd verversen levert de gebruiker en een token', () async {
      final server = _NepServer()
        ..zet('POST', '$_basis/auth-refresh', 200, _auth(HhRol.coordinator));
      final gateway = server.gateway();

      final result = await gateway.sessieHerstellen('oud-token');
      final token = await gateway.huidigToken();

      expect((result as Ok<HhGebruiker>).waarde.rol, HhRol.coordinator);
      expect((token as Ok<String>).waarde, 'nep-token');
    });
  });

  group('PocketBaseAuthGateway.bijwerken en accountWissen', () {
    test('bijwerken stuurt alleen de gegeven velden (PATCH)', () async {
      final server = _NepServer()
        ..zet('PATCH', '$_basis/records/abc123', 200, {
          ..._record(HhRol.jongere),
          'taal': 'tr',
        });

      final result = await server.gateway().bijwerken('abc123', {'taal': 'tr'});

      expect((result as Ok<HhGebruiker>).waarde.taal, HhTaal.tr);
      final patch = server.verzoeken.single;
      expect(patch.methode, 'PATCH');
      expect(patch.body, {'taal': 'tr'});
    });

    test('accountWissen stuurt DELETE en leegt de authStore', () async {
      final server = _NepServer()
        ..zet('DELETE', '$_basis/records/abc123', 204, {});
      final gateway = server.gateway();

      final result = await gateway.accountWissen('abc123');
      final token = await gateway.huidigToken();

      expect(result, isA<Ok<void>>());
      expect(server.verzoeken.single.methode, 'DELETE');
      expect((token as Ok<String>).waarde, isEmpty);
    });
  });
}
