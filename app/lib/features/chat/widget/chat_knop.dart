import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../design/components/hh_knop.dart';
import '../../../l10n/teksten_chat_nl.dart';
import '../../../theme.dart';
import '../paden_chat.dart';
import '../provider/chat_providers.dart';

/// De knop naar de chat van een klus, met de ongelezen-teller als stip
/// rechtsboven. Voor "Chat" in Mijn klussen (helper), bij de hulpvraag van
/// de bewoner (O7) en "Open de chat" na het aannemen (J13).
class ChatKnop extends ConsumerWidget {
  const ChatKnop({
    required this.klusId,
    this.naam = '',
    this.label,
    this.soort = HhKnopSoort.tweedeKeus,
    super.key,
  });

  final String klusId;

  /// Voornaam van de ander, voor de voorleestekst.
  final String naam;

  /// Leeg: "Chat met" plus de naam (of alleen "Chat").
  final String? label;
  final HhKnopSoort soort;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ongelezen = ref.watch(ongelezenVoorKlusProvider(klusId));
    final tekst = Theme.of(context).textTheme;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        HhKnop(
          label: label ?? TekstenChatNl.chatMet(naam),
          semantiekLabel: TekstenChatNl.knopSemantiek(naam, ongelezen),
          icoon: Icons.chat_bubble_outline,
          soort: soort,
          onPressed: () => context.push(HhPadenChat.chat(klusId)),
        ),
        if (ongelezen > 0)
          Positioned(
            top: -6,
            right: -4,
            child: ExcludeSemantics(
              child: Container(
                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                padding: const EdgeInsets.symmetric(horizontal: 6),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: HhKleuren.accent,
                  borderRadius: BorderRadius.circular(HhRadius.rond),
                  border: Border.all(color: HhKleuren.achtergrond, width: 2),
                ),
                child: Text(
                  TekstenChatNl.teller(ongelezen),
                  style: tekst.labelLarge?.copyWith(
                    color: HhKleuren.primairDonker,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
