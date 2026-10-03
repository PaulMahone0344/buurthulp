import 'package:flutter/material.dart';

import '../../../design/dichtheid_scope.dart';
import '../../../l10n/teksten_chat_nl.dart';
import '../../../theme.dart';
import '../model/hh_bericht.dart';

/// De onderkant van de chat als hij open is: drie snelknoppen (een gewoon
/// bericht, nooit een statuswissel) en het invoerveld met de verstuurknop.
class ChatInvoer extends StatelessWidget {
  const ChatInvoer({
    required this.controller,
    required this.snelknoppen,
    required this.isBezig,
    required this.onVerstuur,
    required this.onSnel,
    super.key,
  });

  final TextEditingController controller;
  final List<String> snelknoppen;
  final bool isBezig;
  final VoidCallback onVerstuur;
  final ValueChanged<String> onSnel;

  @override
  Widget build(BuildContext context) {
    final dichtheid = HhDichtheidScope.van(context);
    final tekst = Theme.of(context).textTheme;
    final ruimte = HhRuimte.voor(HhRuimte.s, dichtheid);
    final rand = HhRuimte.voor(HhRuimte.l, dichtheid);
    final hoogte = HhMaten.knopHoogte(dichtheid);

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: HhKleuren.achtergrond,
        border: Border(top: BorderSide(color: HhKleuren.rand)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(rand, ruimte, rand, ruimte),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (snelknoppen.isNotEmpty) ...[
                Semantics(
                  container: true,
                  label: TekstenChatNl.snelleBerichten,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final label in snelknoppen) ...[
                          OutlinedButton(
                            onPressed: isBezig ? null : () => onSnel(label),
                            style: OutlinedButton.styleFrom(
                              minimumSize: Size(hoogte, hoogte),
                              foregroundColor: HhKleuren.primair,
                              side: const BorderSide(color: HhKleuren.rand),
                              shape: const StadiumBorder(),
                              textStyle: tekst.titleSmall,
                            ),
                            child: Text(label),
                          ),
                          SizedBox(width: ruimte),
                        ],
                      ],
                    ),
                  ),
                ),
                SizedBox(height: ruimte),
              ],
              Row(
                children: [
                  Expanded(
                    child: Semantics(
                      textField: true,
                      label: TekstenChatNl.invoerLabel,
                      child: TextField(
                        controller: controller,
                        minLines: 1,
                        maxLines: 4,
                        maxLength: HhBericht.maxTekst,
                        textInputAction: TextInputAction.send,
                        textCapitalization: TextCapitalization.sentences,
                        onSubmitted: (_) => onVerstuur(),
                        style: tekst.bodyLarge,
                        decoration: InputDecoration(
                          hintText: TekstenChatNl.invoerHint,
                          hintMaxLines: 1,
                          counterText: '',
                          filled: true,
                          fillColor: HhKleuren.oppervlak,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: rand,
                            vertical: ruimte * 1.5,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(hoogte / 2),
                            borderSide: const BorderSide(color: HhKleuren.rand),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(hoogte / 2),
                            borderSide: const BorderSide(color: HhKleuren.rand),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: ruimte),
                  IconButton.filled(
                    onPressed: isBezig ? null : onVerstuur,
                    tooltip: TekstenChatNl.verstuur,
                    constraints: BoxConstraints.tightFor(
                      width: hoogte,
                      height: hoogte,
                    ),
                    style: IconButton.styleFrom(
                      backgroundColor: HhKleuren.primair,
                      foregroundColor: HhKleuren.opPrimair,
                    ),
                    icon: isBezig
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: HhKleuren.opPrimair,
                            ),
                          )
                        : const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// De onderkant als de chat dicht is: geen invoer, wel een rustige regel.
class ChatGeslotenRegel extends StatelessWidget {
  const ChatGeslotenRegel({super.key});

  @override
  Widget build(BuildContext context) {
    final dichtheid = HhDichtheidScope.van(context);
    final tekst = Theme.of(context).textTheme;
    final rand = HhRuimte.voor(HhRuimte.l, dichtheid);

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: HhKleuren.oppervlak,
        border: Border(top: BorderSide(color: HhKleuren.rand)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.all(rand),
          child: Semantics(
            liveRegion: true,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  TekstenChatNl.gesloten,
                  textAlign: TextAlign.center,
                  style: tekst.titleMedium,
                ),
                Text(
                  TekstenChatNl.geslotenUitleg,
                  textAlign: TextAlign.center,
                  style: tekst.bodyMedium?.copyWith(
                    color: HhKleuren.tekstGedempt,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
