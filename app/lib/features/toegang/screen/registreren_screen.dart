import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/navigatie.dart';
import '../../../app/paden.dart';
import '../../../core/result.dart';
import '../../../design/components/hh_invoer.dart';
import '../../../design/components/hh_knop.dart';
import '../../../design/components/hh_lege_staat.dart';
import '../../../design/components/hh_meld_balk.dart';
import '../../../design/components/hh_scherm.dart';
import '../../../design/dichtheid_scope.dart';
import '../../../l10n/teksten_nl.dart';
import '../../../theme.dart';
import '../model/hh_rol.dart';
import '../provider/sessie_providers.dart';
import '../validatie.dart';

/// G4. Naam, e-mail, telefoon (niet verplicht) en wachtwoord. De rol komt
/// van G2 en gaat verplicht mee naar de server, samen met taal = nl. Na
/// succes stuurt de router-guard door naar G5 (bevestig je e-mailadres).
class RegistrerenScreen extends ConsumerStatefulWidget {
  const RegistrerenScreen({super.key});

  @override
  ConsumerState<RegistrerenScreen> createState() => _RegistrerenScreenState();
}

class _RegistrerenScreenState extends ConsumerState<RegistrerenScreen> {
  final _naam = TextEditingController();
  final _email = TextEditingController();
  final _telefoon = TextEditingController();
  final _wachtwoord = TextEditingController();
  String? _naamFout;
  String? _emailFout;
  String? _wachtwoordFout;
  String? _melding;
  bool _isBezig = false;

  @override
  void dispose() {
    _naam.dispose();
    _email.dispose();
    _telefoon.dispose();
    _wachtwoord.dispose();
    super.dispose();
  }

  Future<void> _registreren(HhRol rol) async {
    final naamFout = valideerNaam(_naam.text);
    final emailFout = valideerEmail(_email.text);
    final wachtwoordFout = valideerWachtwoord(_wachtwoord.text);
    setState(() {
      _naamFout = naamFout;
      _emailFout = emailFout;
      _wachtwoordFout = wachtwoordFout;
      _melding = null;
    });
    if (naamFout != null || emailFout != null || wachtwoordFout != null) {
      return;
    }

    setState(() => _isBezig = true);
    final result = await ref
        .read(sessieControllerProvider.notifier)
        .registreren(
          naam: _naam.text.trim(),
          email: _email.text.trim(),
          wachtwoord: _wachtwoord.text,
          rol: rol,
          telefoon: _telefoon.text.trim(),
        );
    if (!mounted) return;
    setState(() {
      _isBezig = false;
      _melding = switch (result) {
        Ok<void>() => null,
        Err<void>(:final fout) => fout.melding,
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final rol = ref.watch(gekozenRolProvider);
    final dichtheid = HhDichtheidScope.van(context);
    final tekst = Theme.of(context).textTheme;
    final tussen = HhRuimte.voor(HhRuimte.l, dichtheid);

    if (rol == null || !rol.kanZelfRegistreren) {
      return HhScherm(
        titel: TekstenNl.registrerenTitel,
        onTerug: () => terugOf(context, HhPaden.welkom),
        child: HhLegeStaat(
          icoon: Icons.person_add_alt_outlined,
          titel: TekstenNl.registrerenTitel,
          uitleg: TekstenNl.registrerenOnbekendeRol,
          knopLabel: TekstenNl.terug,
          onKnop: () => context.go(HhPaden.welkom),
        ),
      );
    }

    return HhScherm(
      titel: TekstenNl.registrerenTitel,
      onTerug: () => terugOf(context, HhPaden.welkom),
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${TekstenNl.registrerenAlsUitleg} ${rol.naam.toLowerCase()}.',
              style: tekst.bodyMedium,
            ),
            SizedBox(height: tussen),
            HhInvoer(
              label: TekstenNl.veldNaam,
              controller: _naam,
              hulptekst: TekstenNl.veldNaamHulp,
              fouttekst: _naamFout,
              isVerplicht: true,
              isActief: !_isBezig,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.name],
            ),
            SizedBox(height: tussen),
            HhInvoer(
              label: TekstenNl.veldEmail,
              controller: _email,
              hulptekst: TekstenNl.veldEmailHulp,
              fouttekst: _emailFout,
              isVerplicht: true,
              isActief: !_isBezig,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
            ),
            SizedBox(height: tussen),
            HhInvoer(
              label: TekstenNl.veldTelefoon,
              controller: _telefoon,
              hulptekst: TekstenNl.veldTelefoonHulp,
              isActief: !_isBezig,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.telephoneNumber],
            ),
            SizedBox(height: tussen),
            HhInvoer(
              label: TekstenNl.veldWachtwoord,
              controller: _wachtwoord,
              hulptekst: TekstenNl.veldWachtwoordHulp,
              fouttekst: _wachtwoordFout,
              isVerplicht: true,
              isActief: !_isBezig,
              obscureText: true,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.newPassword],
              onSubmitted: (_) => _registreren(rol),
            ),
            if (_melding != null) ...[
              SizedBox(height: tussen),
              HhMeldBalk(soort: HhMeldSoort.fout, tekst: _melding!),
            ],
            SizedBox(height: HhRuimte.voor(HhRuimte.xl, dichtheid)),
            HhKnop(
              label: TekstenNl.registrerenKnop,
              isBezig: _isBezig,
              onPressed: () => _registreren(rol),
            ),
          ],
        ),
      ),
    );
  }
}
