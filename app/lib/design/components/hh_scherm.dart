import 'package:flutter/material.dart';

import '../../l10n/teksten_nl.dart';
import '../../theme.dart';
import '../dichtheid_scope.dart';

/// Schermsteiger (app OPEN-PUNT 11, opgelost in M2), zoals ObyScreen:
/// veilige randen, een terugknop, de titel als kop en de inhoud eronder.
/// Geen Material-AppBar: die zet een tweede kop in het standaardfont en
/// past zijn maat niet aan de dichtheid aan.
///
/// De terugknop verschijnt vanzelf zodra er iets is om naar terug te
/// keren, of altijd als [onTerug] is gezet. Ouderenschermen geven altijd
/// een [onTerug] mee: de veegbeweging van iOS is geen uitweg voor wie hem
/// niet kent, en Android heeft hem niet.
///
/// [scrollbaar] true (standaard): kop en inhoud scrollen samen. False: het
/// kind krijgt de resterende hoogte en scrollt zelf (voor een ListView).
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
    final tekst = Theme.of(context).textTheme;
    final rand = HhRuimte.voor(HhRuimte.l, dichtheid);
    final bovenrand = HhRuimte.voor(HhRuimte.xl, dichtheid);
    final tussenruimte = HhRuimte.voor(HhRuimte.s, dichtheid);
    final kopruimte = HhRuimte.voor(HhRuimte.xl, dichtheid);

    final kanTerug =
        toonTerug ?? (onTerug != null || Navigator.of(context).canPop());

    final kop = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (kanTerug) ...[
          HhTerugKnop(
            onTerug: onTerug ?? () => Navigator.of(context).maybePop(),
          ),
          SizedBox(height: tussenruimte),
        ],
        Semantics(
          header: true,
          child: Text(titel, style: tekst.headlineMedium),
        ),
      ],
    );

    if (!scrollbaar) {
      return Scaffold(
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(rand, bovenrand, rand, 0),
                child: kop,
              ),
              SizedBox(height: kopruimte),
              Expanded(child: child),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(rand, bovenrand, rand, bovenrand),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              kop,
              SizedBox(height: kopruimte),
              child,
            ],
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
  const HhTerugKnop({required this.onTerug, super.key});

  final VoidCallback onTerug;

  @override
  Widget build(BuildContext context) {
    final dichtheid = HhDichtheidScope.van(context);
    final schema = Theme.of(context).colorScheme;
    final stijl = Theme.of(context).textTheme.titleLarge!;
    final hoogte = HhMaten.knopHoogte(dichtheid);

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
          child: ConstrainedBox(
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
                    color: schema.primary,
                  ),
                  SizedBox(width: HhRuimte.voor(HhRuimte.s, dichtheid)),
                  Text(
                    TekstenNl.terug,
                    style: stijl.copyWith(color: schema.primary),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
