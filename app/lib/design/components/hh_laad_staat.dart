import 'package:flutter/material.dart';

import '../../theme.dart';
import '../dichtheid_scope.dart';
import '../lijn.dart';

enum _HhLaadVorm { spinner, skelet }

/// Een laadvorm voor de hele app. Spinner voor een actie die even duurt,
/// skelet voor een lijst die nog komt. De schermlezer hoort alleen het
/// [label]; de grijze blokken zelf zeggen niets.
class HhLaadStaat extends StatelessWidget {
  const HhLaadStaat.spinner({this.label = 'Even geduld', super.key})
    : _vorm = _HhLaadVorm.spinner,
      regels = 0;

  const HhLaadStaat.skelet({
    this.regels = 3,
    this.label = 'Wordt geladen',
    super.key,
  }) : _vorm = _HhLaadVorm.skelet,
       assert(regels > 0, 'een skelet heeft minstens een regel');

  final _HhLaadVorm _vorm;
  final String label;

  /// Aantal skeletrijen.
  final int regels;

  bool get isSkelet => _vorm == _HhLaadVorm.skelet;

  @override
  Widget build(BuildContext context) {
    final dichtheid = HhDichtheidScope.van(context);

    final inhoud = switch (_vorm) {
      _HhLaadVorm.spinner => Center(
        child: CircularProgressIndicator(
          color: Theme.of(context).colorScheme.primary,
          strokeWidth: HhMaten.icoonLijn,
        ),
      ),
      _HhLaadVorm.skelet => _Puls(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < regels; i++) ...[
              if (i > 0) SizedBox(height: HhRuimte.voor(HhRuimte.s, dichtheid)),
              const _SkeletRij(),
            ],
          ],
        ),
      ),
    };

    return Semantics(
      container: true,
      liveRegion: true,
      label: label,
      excludeSemantics: true,
      child: inhoud,
    );
  }
}

/// Een skeletrij: cirkel voor de avatar, twee balkjes voor naam en regel.
/// De balkhoogtes volgen de lettergroottes uit theme.dart zodat het skelet
/// dezelfde ruimte inneemt als de tekst die erna komt.
class _SkeletRij extends StatelessWidget {
  const _SkeletRij();

  static const _breedteNaam = 0.6;
  static const _breedteRegel = 0.35;

  @override
  Widget build(BuildContext context) {
    final dichtheid = HhDichtheidScope.van(context);
    final tekst = Theme.of(context).textTheme;
    final schema = Theme.of(context).colorScheme;
    final avatar = HhMaten.avatar(dichtheid);

    return Container(
      padding: EdgeInsets.all(HhRuimte.voor(HhRuimte.l, dichtheid)),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(HhRadius.groot),
        border: Border.all(color: schema.outline, width: HhLijn.dun(context)),
      ),
      child: Row(
        children: [
          Container(
            width: avatar,
            height: avatar,
            decoration: const BoxDecoration(
              color: HhKleuren.oppervlakZacht,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: HhRuimte.voor(HhRuimte.m, dichtheid)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _Balk(
                  breedte: _breedteNaam,
                  hoogte: tekst.bodyLarge!.fontSize!,
                ),
                SizedBox(height: HhRuimte.voor(HhRuimte.s, dichtheid)),
                _Balk(
                  breedte: _breedteRegel,
                  hoogte: tekst.bodyMedium!.fontSize!,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Balk extends StatelessWidget {
  const _Balk({required this.breedte, required this.hoogte});

  final double breedte;
  final double hoogte;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      widthFactor: breedte,
      alignment: Alignment.centerLeft,
      child: Container(
        height: hoogte,
        decoration: BoxDecoration(
          color: HhKleuren.oppervlakZacht,
          borderRadius: BorderRadius.circular(HhRadius.midden),
        ),
      ),
    );
  }
}

/// Zachte ademhaling van het skelet, zodat het niet op een bevroren
/// scherm lijkt. theme.dart heeft nog geen bewegingstokens; de duur staat
/// daarom hier en in OPEN-PUNTEN.txt.
class _Puls extends StatefulWidget {
  const _Puls({required this.child});

  final Widget child;

  @override
  State<_Puls> createState() => _PulsState();
}

class _PulsState extends State<_Puls> with SingleTickerProviderStateMixin {
  static const _duur = Duration(milliseconds: 1400);
  static const _laagsteDekking = 0.5;

  late final AnimationController _besturing = AnimationController(
    vsync: this,
    duration: _duur,
  );

  late final Animation<double> _dekking = Tween<double>(
    begin: 1,
    end: _laagsteDekking,
  ).animate(CurvedAnimation(parent: _besturing, curve: Curves.easeInOut));

  /// "Verminder beweging" van het toestel (M12): dan staat het skelet
  /// stil op volle dekking.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _besturing
        ..stop()
        ..value = 0;
    } else if (!_besturing.isAnimating) {
      _besturing.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _besturing.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(opacity: _dekking, child: widget.child);
  }
}
