import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design/components/hh_knop.dart';
import '../../../design/dichtheid_scope.dart';
import '../../../l10n/teksten_kennismaken_nl.dart';
import '../../../theme.dart';
import 'kennismaken_controller.dart';

/// Kennismaking (24 okt): vier pagina's om door te vegen, één keer, vóór
/// het welkomscherm. "Overslaan" bovenaan, bolletjes en "Volgende" onderin;
/// de laatste pagina heeft "Aan de slag". Afronden of overslaan bewaart
/// dat hij gezien is; de guard stuurt dan door naar G2.
/// Plaatjes zijn voorwerpen (huis, gieter, schild, munt), nooit mensen of
/// dieren. Met [isOpnieuw] (vanuit Hulp): afronden of overslaan sluit het
/// scherm en gaat terug.
class KennismakenScreen extends ConsumerStatefulWidget {
  const KennismakenScreen({this.isOpnieuw = false, super.key});

  final bool isOpnieuw;

  @override
  ConsumerState<KennismakenScreen> createState() => _KennismakenScreenState();
}

class _KennismakenScreenState extends ConsumerState<KennismakenScreen> {
  static const _overgang = Duration(milliseconds: 300);
  static const _paginas = TekstenKennismakenNl.paginas;

  final _pager = PageController();
  int _pagina = 0;

  bool get _isLaatste => _pagina == _paginas.length - 1;

  @override
  void dispose() {
    _pager.dispose();
    super.dispose();
  }

  void _klaar() {
    if (widget.isOpnieuw) {
      unawaited(Navigator.of(context).maybePop());
      return;
    }
    unawaited(ref.read(kennismakingGezienProvider.notifier).markeer());
  }

  void _volgende() {
    if (_isLaatste) return _klaar();
    if (MediaQuery.disableAnimationsOf(context)) {
      _pager.jumpToPage(_pagina + 1);
      return;
    }
    unawaited(_pager.nextPage(duration: _overgang, curve: Curves.easeOutCubic));
  }

  @override
  Widget build(BuildContext context) {
    final dichtheid = HhDichtheidScope.van(context);
    final rand = HhRuimte.voor(HhRuimte.l, dichtheid);

    return Scaffold(
      backgroundColor: HhKleuren.achtergrond,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: EdgeInsets.only(right: rand, top: HhRuimte.s),
                child: Semantics(
                  label: TekstenKennismakenNl.overslaanSemantiek,
                  button: true,
                  excludeSemantics: true,
                  child: TextButton(
                    onPressed: _klaar,
                    child: const Text(TekstenKennismakenNl.overslaan),
                  ),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pager,
                itemCount: _paginas.length,
                onPageChanged: (i) => setState(() => _pagina = i),
                itemBuilder: (context, i) =>
                    _Pagina(pagina: _paginas[i], index: i),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(rand, 0, rand, rand),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Bolletjes(aantal: _paginas.length, actief: _pagina),
                  SizedBox(height: HhRuimte.voor(HhRuimte.l, dichtheid)),
                  HhKnop(
                    label: _isLaatste
                        ? TekstenKennismakenNl.aanDeSlag
                        : TekstenKennismakenNl.volgende,
                    icoon: _isLaatste ? Icons.check : Icons.arrow_forward,
                    onPressed: _volgende,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Plaatje, titel en tekst van één pagina. Scrollt als de tekst groot
/// staat (200 procent).
class _Pagina extends StatelessWidget {
  const _Pagina({required this.pagina, required this.index});

  final HhKennismaakPagina pagina;
  final int index;

  @override
  Widget build(BuildContext context) {
    final dichtheid = HhDichtheidScope.van(context);
    final tekst = Theme.of(context).textTheme;
    final rand = HhRuimte.voor(HhRuimte.xl, dichtheid);

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: rand),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: HhRuimte.voor(HhRuimte.l, dichtheid)),
          ExcludeSemantics(child: _Plaatje(index: index)),
          SizedBox(height: HhRuimte.voor(HhRuimte.xxl, dichtheid)),
          Semantics(
            header: true,
            child: Text(
              pagina.titel,
              style: tekst.headlineMedium?.copyWith(
                color: HhKleuren.primair,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(height: HhRuimte.voor(HhRuimte.m, dichtheid)),
          Text(
            pagina.tekst,
            style: tekst.bodyLarge?.copyWith(color: HhKleuren.tekstGedempt),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Eén groot voorwerp in een zachte cirkel, met twee kleine voorwerpen er
/// schuin overheen voor wat diepte. Alleen voorwerpen, geen levende wezens.
class _Plaatje extends StatelessWidget {
  const _Plaatje({required this.index});

  final int index;

  static const _maat = 220.0;
  static const _hoofdIcoon = 96.0;
  static const _kleinIcoon = 30.0;

  static const _sets = [
    (Icons.home_rounded, Icons.yard_outlined, Icons.shopping_bag_outlined),
    (Icons.assignment_outlined, Icons.forum_outlined, Icons.check_circle),
    (Icons.verified_user_outlined, Icons.lock_outline, Icons.mail_outline),
    (Icons.paid_outlined, Icons.handyman_outlined, Icons.star_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final (hoofd, links, rechts) = _sets[index % _sets.length];

    return Center(
      child: SizedBox.square(
        dimension: _maat,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              decoration: const BoxDecoration(
                color: HhKleuren.oppervlak,
                shape: BoxShape.circle,
              ),
            ),
            Container(
              width: _maat * 0.62,
              height: _maat * 0.62,
              decoration: const BoxDecoration(
                color: HhKleuren.accentZacht,
                shape: BoxShape.circle,
              ),
              child: Icon(hoofd, size: _hoofdIcoon, color: HhKleuren.primair),
            ),
            Positioned(
              left: 8,
              top: 28,
              child: _Badge(icoon: links, kleur: HhKleuren.primair),
            ),
            Positioned(
              right: 4,
              bottom: 30,
              child: _Badge(icoon: rechts, kleur: HhKleuren.accentDonker),
            ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.icoon, required this.kleur});

  final IconData icoon;
  final Color kleur;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: HhKleuren.achtergrond,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: HhKleuren.primairDonker.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(HhRuimte.m),
        child: Icon(icoon, size: _Plaatje._kleinIcoon, color: kleur),
      ),
    );
  }
}

/// Bolletjes onderaan: het actieve is breder en groen. Voor de
/// schermlezer één regel: "Pagina 2 van 4".
class _Bolletjes extends StatelessWidget {
  const _Bolletjes({required this.aantal, required this.actief});

  final int aantal;
  final int actief;

  static const _hoogte = 8.0;
  static const _breedte = 8.0;
  static const _breedteActief = 24.0;

  @override
  Widget build(BuildContext context) {
    final rustig = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      label: TekstenKennismakenNl.paginaVan(actief + 1, aantal),
      excludeSemantics: true,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < aantal; i++)
            AnimatedContainer(
              duration: rustig
                  ? Duration.zero
                  : const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: i == actief ? _breedteActief : _breedte,
              height: _hoogte,
              decoration: BoxDecoration(
                color: i == actief ? HhKleuren.primair : HhKleuren.rand,
                borderRadius: BorderRadius.circular(_hoogte),
              ),
            ),
        ],
      ),
    );
  }
}
