import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/teksten_nl.dart';
import '../../theme.dart';
import '../dichtheid_scope.dart';
import 'hh_tabbalk.dart';

/// Schermsteiger (app OPEN-PUNT 11, opgelost in M2): groene bovenbalk
/// met terugknop en titel ([HhBovenbalk]), de inhoud eronder.
/// Geen Material-AppBar: die zet een tweede kop in het standaardfont en
/// past zijn maat niet aan de dichtheid aan.
///
/// De terugknop verschijnt vanzelf zodra er iets is om naar terug te
/// keren, of altijd als [onTerug] is gezet. Ouderenschermen geven altijd
/// een [onTerug] mee: de veegbeweging van iOS is geen uitweg voor wie hem
/// niet kent, en Android heeft hem niet.
///
/// [scrollbaar] true (standaard): de inhoud scrollt onder de vaste balk.
/// False: het kind krijgt de resterende hoogte en scrollt zelf.
class HhScherm extends StatelessWidget {
  const HhScherm({
    required this.titel,
    required this.child,
    this.onTerug,
    this.toonTerug,
    this.scrollbaar = true,
    super.key,
  });

  final String titel;
  final Widget child;

  /// Wat de terugknop doet. Leeg: Navigator.maybePop.
  final VoidCallback? onTerug;

  /// Overschrijft de automatische keuze. Leeg: tonen als er een [onTerug]
  /// is of als de Navigator terug kan.
  final bool? toonTerug;

  final bool scrollbaar;

  @override
  Widget build(BuildContext context) {
    final dichtheid = HhDichtheidScope.van(context);
    final rand = HhRuimte.voor(HhRuimte.l, dichtheid);
    final bovenrand = HhRuimte.voor(HhRuimte.xl, dichtheid);

    // Een tab (HhTabScherm) heeft nooit een terugknop: daar is de balk.
    final kanTerug =
        !HhTabScope.isInTab(context) &&
        (toonTerug ?? (onTerug != null || Navigator.of(context).canPop()));

    final balk = HhBovenbalk(
      titel: titel,
      onTerug: kanTerug
          ? (onTerug ?? () => Navigator.of(context).maybePop())
          : null,
    );

    final inhoud = scrollbaar
        ? SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(rand, bovenrand, rand, bovenrand),
            child: child,
          )
        : Padding(
            padding: EdgeInsets.only(top: bovenrand),
            child: child,
          );

    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          balk,
          Expanded(child: SafeArea(top: false, child: inhoud)),
        ],
      ),
    );
  }
}

/// Vanaf deze tekstschaal staat de terugknop boven de titel.
const _grootTekstGrens = 1.3;

/// Bovenbalk (3 okt, indeling naar BuurtHeld): primair groen tot boven in
/// het scherm, titel wit en gecentreerd, terugknop links. Rechts staat een
/// onzichtbare kopie van de terugknop zodat de titel echt in het midden
/// staat en bij grote tekst nooit onder de knop schuift.
class HhBovenbalk extends StatelessWidget {
  const HhBovenbalk({required this.titel, this.onTerug, super.key});

  final String titel;

  /// Leeg: geen terugknop.
  final VoidCallback? onTerug;

  @override
  Widget build(BuildContext context) {
    final dichtheid = HhDichtheidScope.van(context);
    final tekst = Theme.of(context).textTheme;
    final ruimte = HhRuimte.voor(HhRuimte.s, dichtheid);
    final terug = onTerug;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: ColoredBox(
        color: HhKleuren.primair,
        child: SafeArea(
          bottom: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: HhMaten.knopHoogte(dichtheid) + 2 * ruimte,
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: ruimte,
                vertical: ruimte,
              ),
              child: LayoutBuilder(
                builder: (context, maten) {
                  final titelTekst = Semantics(
                    header: true,
                    child: Text(
                      titel,
                      textAlign: TextAlign.center,
                      style: tekst.titleLarge?.copyWith(
                        color: HhKleuren.opPrimair,
                      ),
                    ),
                  );
                  if (terug == null) {
                    return Center(child: titelTekst);
                  }
                  final knop = HhTerugKnop(
                    onTerug: terug,
                    kleur: HhKleuren.opPrimair,
                  );
                  // Grote tekst: knop op eigen regel, titel volle breedte.
                  // Naast elkaar wordt een lange titel dan te hoog (M12).
                  if (MediaQuery.textScalerOf(context).scale(1) >=
                      _grootTekstGrens) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [knop, titelTekst],
                    );
                  }
                  final zijkant = BoxConstraints(maxWidth: maten.maxWidth / 3);
                  return Row(
                    children: [
                      ConstrainedBox(constraints: zijkant, child: knop),
                      Expanded(child: titelTekst),
                      ConstrainedBox(
                        constraints: zijkant,
                        child: const _TerugPlaatshouder(),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// De terugknop van de steiger, los bruikbaar. Raakvlak is de knophoogte
/// uit theme.dart (48 normaal, 60 groot), met het woord erbij zodat hij
/// ook zonder kennis van het pijltje te begrijpen is.
class HhTerugKnop extends StatelessWidget {
  const HhTerugKnop({required this.onTerug, this.kleur, super.key});

  final VoidCallback onTerug;

  /// Kleur van pijl en woord. Leeg: primair (op lichte achtergrond).
  final Color? kleur;

  @override
  Widget build(BuildContext context) {
    final schema = Theme.of(context).colorScheme;

    return Semantics(
      button: true,
      label: TekstenNl.terug,
      onTap: onTerug,
      excludeSemantics: true,
      child: Align(
        alignment: Alignment.centerLeft,
        child: InkWell(
          onTap: onTerug,
          borderRadius: BorderRadius.circular(HhRadius.midden),
          child: _TerugInhoud(kleur: kleur ?? schema.primary),
        ),
      ),
    );
  }
}

/// Pijl + woord van de terugknop. [alleenMaat]: tekst als RichText, zodat
/// de plaatshouder dezelfde maat heeft maar niet als "Terug" gevonden wordt.
class _TerugInhoud extends StatelessWidget {
  const _TerugInhoud({required this.kleur, this.alleenMaat = false});

  final Color kleur;
  final bool alleenMaat;

  @override
  Widget build(BuildContext context) {
    final dichtheid = HhDichtheidScope.van(context);
    final stijl = Theme.of(
      context,
    ).textTheme.titleLarge!.copyWith(color: kleur);
    final hoogte = HhMaten.knopHoogte(dichtheid);

    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: hoogte, minWidth: hoogte),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: HhRuimte.voor(HhRuimte.s, dichtheid),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.arrow_back,
              size: HhMaten.icoonKeuzerij(dichtheid),
              color: kleur,
            ),
            SizedBox(width: HhRuimte.voor(HhRuimte.s, dichtheid)),
            // Flexible: bij 200% tekst op 320 breed past pijl + woord
            // niet meer op één regel (M12).
            Flexible(
              child: alleenMaat
                  ? RichText(
                      text: TextSpan(text: TekstenNl.terug, style: stijl),
                      textScaler: MediaQuery.textScalerOf(context),
                    )
                  : Text(TekstenNl.terug, style: stijl),
            ),
          ],
        ),
      ),
    );
  }
}

/// Onzichtbare ruimte rechts in de bovenbalk, even breed als de terugknop,
/// zodat de titel in het midden staat.
class _TerugPlaatshouder extends StatelessWidget {
  const _TerugPlaatshouder();

  @override
  Widget build(BuildContext context) {
    return const ExcludeSemantics(
      child: IgnorePointer(
        child: Opacity(
          opacity: 0,
          child: _TerugInhoud(kleur: HhKleuren.opPrimair, alleenMaat: true),
        ),
      ),
    );
  }
}
