import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../design/components/hh_invoer.dart';
import '../../../design/components/hh_kaart.dart';
import '../../../design/components/hh_keuzerij.dart';
import '../../../design/dichtheid_scope.dart';
import '../../../l10n/teksten_hulpvrager_nl.dart';
import '../../../theme.dart';
import '../model/hh_gegevens.dart';

/// Feedbackronde 1 punt F: kaart "Je woning" op Mijn gegevens. Soort
/// woning, verdieping en lift (alleen bij een appartement), trap en hoe je
/// bij de deur komt. Niets is verplicht; een lege keuze is "niet ingevuld".
/// De kaart bewaart zelf niets: [onKeuze] krijgt het veld en de waarde.
class WoningKaart extends StatelessWidget {
  const WoningKaart({
    required this.woningType,
    required this.lift,
    required this.trap,
    required this.verdieping,
    required this.bereikbaarheid,
    required this.onKeuze,
    this.isActief = true,
    super.key,
  });

  final String woningType;
  final String lift;
  final String trap;
  final TextEditingController verdieping;
  final TextEditingController bereikbaarheid;

  /// (veldnaam, waarde), met de veldnamen van [HhGegevens].
  final void Function(String veld, String waarde) onKeuze;
  final bool isActief;

  static const _woningKeuzes = [
    HhKeuze(
      waarde: HhGegevens.woningHuis,
      label: TekstenHulpvragerNl.woningHuis,
      semantiekLabel: TekstenHulpvragerNl.woningHuisSemantiek,
      icoon: Icons.house_outlined,
    ),
    HhKeuze(
      waarde: HhGegevens.woningAppartement,
      label: TekstenHulpvragerNl.woningAppartement,
      semantiekLabel: TekstenHulpvragerNl.woningAppartementSemantiek,
      icoon: Icons.apartment_outlined,
    ),
    HhKeuze(
      waarde: HhGegevens.woningAnders,
      label: TekstenHulpvragerNl.woningAnders,
      semantiekLabel: TekstenHulpvragerNl.woningAndersSemantiek,
      icoon: Icons.more_horiz,
    ),
  ];

  static List<HhKeuze<String>> _jaNee(String vraag) => [
    HhKeuze(
      waarde: HhGegevens.ja,
      label: TekstenHulpvragerNl.ja,
      icoon: Icons.check,
      semantiekLabel: TekstenHulpvragerNl.jaNeeSemantiek(
        TekstenHulpvragerNl.ja,
        vraag,
      ),
    ),
    HhKeuze(
      waarde: HhGegevens.nee,
      label: TekstenHulpvragerNl.nee,
      icoon: Icons.close,
      semantiekLabel: TekstenHulpvragerNl.jaNeeSemantiek(
        TekstenHulpvragerNl.nee,
        vraag,
      ),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final dichtheid = HhDichtheidScope.van(context);
    final tekst = Theme.of(context).textTheme;
    final tussen = HhRuimte.voor(HhRuimte.l, dichtheid);
    final klein = HhRuimte.voor(HhRuimte.s, dichtheid);
    final vraagStijl = tekst.bodyLarge?.copyWith(fontWeight: FontWeight.w600);

    List<Widget> vraag(
      String titel,
      String veld,
      String waarde,
      List<HhKeuze<String>> keuzes,
    ) => [
      Text(titel, style: vraagStijl),
      SizedBox(height: klein),
      HhKeuzerij<String>(
        semantiekLabel: titel,
        keuzes: keuzes,
        geselecteerd: {if (waarde.isNotEmpty) waarde},
        onGewijzigd: isActief ? (k) => onKeuze(veld, k.first) : null,
      ),
    ];

    return HhKaart(
      kop: TekstenHulpvragerNl.gegevensKaartWoning,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(TekstenHulpvragerNl.woningUitleg, style: tekst.bodyMedium),
          SizedBox(height: tussen),
          ...vraag(
            TekstenHulpvragerNl.woningTypeVraag,
            HhGegevens.veldWoningType,
            woningType,
            _woningKeuzes,
          ),
          if (woningType == HhGegevens.woningAppartement) ...[
            SizedBox(height: tussen),
            HhInvoer(
              label: TekstenHulpvragerNl.veldVerdieping,
              controller: verdieping,
              isActief: isActief,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(2),
              ],
              textInputAction: TextInputAction.next,
            ),
            SizedBox(height: tussen),
            ...vraag(
              TekstenHulpvragerNl.woningLiftVraag,
              HhGegevens.veldLift,
              lift,
              _jaNee(TekstenHulpvragerNl.woningLiftVraag),
            ),
          ],
          SizedBox(height: tussen),
          ...vraag(
            TekstenHulpvragerNl.woningTrapVraag,
            HhGegevens.veldTrap,
            trap,
            _jaNee(TekstenHulpvragerNl.woningTrapVraag),
          ),
          SizedBox(height: tussen),
          HhInvoer(
            label: TekstenHulpvragerNl.veldBereikbaarheid,
            hulptekst: TekstenHulpvragerNl.bereikbaarheidHint,
            controller: bereikbaarheid,
            isActief: isActief,
            maxRegels: 3,
            inputFormatters: [LengthLimitingTextInputFormatter(300)],
            textCapitalization: TextCapitalization.sentences,
          ),
        ],
      ),
    );
  }
}
