import 'package:heitjehulp_app/features/jongere/xp/model/hh_xp.dart';

/// B9: een gevuld XP-overzicht zoals de server het voor een helper stuurt
/// (lange namen met opzet, voor de sweeps). [maand] = "2026-09" (testklok).
HhXpOverzicht testXpOverzicht({bool verlopenVog = false}) =>
    HhXpOverzicht.vanJson({
      'xp_totaal': 605,
      'niveau': {'code': 'ervaren', 'naam': 'Ervaren'},
      'volgend': {
        'code': 'top',
        'naam': 'Top',
        'xp_nodig': 395,
        'klussen_nodig': 10,
        'sterren_nodig': 4.5,
        'xp_vanaf': 300,
        'xp_tot': 1000,
      },
      'klussen_aantal': 5,
      'sterren': 4.8,
      'badges': [
        {
          'code': 'eerste_klus',
          'naam': 'Eerste klus',
          'icoon': 'flag',
          'behaald_op': '2026-09-01 08:00:00.000Z',
        },
        {
          'code': 'vijf_klussen',
          'naam': '5 klussen',
          'icoon': 'handyman',
          'behaald_op': '2026-09-12 08:00:00.000Z',
        },
        {
          'code': 'tien_klussen',
          'naam': '10 klussen',
          'icoon': 'construction',
          'behaald_op': '',
        },
        {
          'code': 'vijf_sterren_reeks',
          'naam': '5 keer 5 sterren',
          'icoon': 'star',
          'behaald_op': '',
        },
        {
          'code': 'herboekt',
          'naam': 'Weer gevraagd',
          'icoon': 'repeat',
          'behaald_op': '2026-09-05 08:00:00.000Z',
        },
        {
          'code': 'drie_buren',
          'naam': '3 buren geholpen',
          'icoon': 'home',
          'behaald_op': '',
        },
      ],
      'vertrouwen': [
        {
          'code': 'ouder_toestemming',
          'naam': 'Toestemming ouder',
          'icoon': 'verified_user',
          'datum': '2026-08-20 10:00:00.000Z',
          'geldig_tot': '',
          'verlopen': false,
        },
        {
          'code': 'vog',
          'naam': 'VOG gezien',
          'icoon': 'shield',
          'datum': '2023-09-01 10:00:00.000Z',
          'geldig_tot': verlopenVog
              ? '2026-09-01 10:00:00.000Z'
              : '2029-09-01 10:00:00.000Z',
          'verlopen': verlopenVog,
        },
      ],
      'verdiensten': {
        'maanden': [
          {'maand': '2026-09', 'bedrag': 37.5, 'klussen': 4},
          {'maand': '2026-08', 'bedrag': 10, 'klussen': 1},
        ],
        'jaren': [
          {'jaar': '2026', 'bedrag': 47.5, 'klussen': 5},
        ],
        'totaal': 47.5,
      },
      'recensies': [],
    });

const testBeloning = HhBeloning(
  xpErbij: 125,
  totaal: 605,
  niveau: HhNiveau(code: 'ervaren', naam: 'Ervaren'),
  isNiveauOmhoog: true,
  nieuweBadges: [
    HhBadge(
      code: 'vijf_klussen',
      naam: '5 klussen',
      uitleg: 'Vijf klussen gedaan.',
      icoon: 'handyman',
    ),
  ],
);

const testVerklaringJson = {
  'code': 'ABCDE-FGH23',
  'uitgegeven_op': '2026-09-15 10:00:00.000Z',
  'gegevens': {
    'voornaam': 'Daan',
    'klussen': 5,
    'uren': 6.5,
    'periode_van': '2026-08-01',
    'periode_tot': '2026-09-12',
    'niveau': 'Ervaren',
    'badges': [
      {'naam': 'Eerste klus', 'datum': '2026-08-01'},
    ],
    'vertrouwen': [
      {'naam': 'VOG gezien', 'datum': '2026-08-20'},
    ],
  },
};
