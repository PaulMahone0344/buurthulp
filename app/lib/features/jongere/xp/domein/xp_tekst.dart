import 'package:flutter/material.dart';

import '../../../../l10n/teksten_klussen_nl.dart';
import '../../klussen/domein/wanneer_tekst.dart' show euroTekst;

/// "1 oktober 2026" (lokale dag), of leeg zonder datum.
String datumTekst(DateTime? moment) {
  if (moment == null) return '';
  final d = moment.toLocal();
  return '${d.day} ${TekstenKlussenNl.maanden[d.month - DateTime.january]} ${d.year}';
}

/// "2026-10" -> "oktober 2026"; "2026" blijft "2026".
String periodeTekst(String periode) {
  final delen = periode.split('-');
  if (delen.length != 2) return periode;
  final maand = int.tryParse(delen[1]);
  if (maand == null || maand < 1 || maand > 12) return periode;
  return '${TekstenKlussenNl.maanden[maand - 1]} ${delen[0]}';
}

/// "2026-10" voor de maand van [nu] (lokaal), zoals de server hem noemt.
String maandSleutel(DateTime nu) {
  final l = nu.toLocal();
  return '${l.year}-${l.month.toString().padLeft(2, '0')}';
}

/// Euro's (zoals de server ze stuurt) -> "€ 17,50".
String euroVanBedrag(double bedrag) => euroTekst((bedrag * 100).round());

/// "1,5" uren, zonder overbodige ",0".
String urenTekst(double uren) {
  if (uren == uren.roundToDouble()) return uren.toStringAsFixed(0);
  return uren.toString().replaceAll('.', ',');
}

/// De naam die de server bij een badge meegeeft -> Material-icoon. Alleen
/// voorwerpen en vormen (geen mensen of dieren). Onbekend: een medaille.
IconData badgeIcoon(String naam) => switch (naam) {
  'flag' => Icons.flag_outlined,
  'handyman' => Icons.handyman_outlined,
  'construction' => Icons.construction_outlined,
  'workspace_premium' => Icons.workspace_premium_outlined,
  'star' => Icons.star_outline_rounded,
  'repeat' => Icons.repeat_rounded,
  'home' => Icons.home_outlined,
  'verified_user' => Icons.verified_user_outlined,
  'shield' => Icons.shield_outlined,
  'badge' => Icons.badge_outlined,
  'lock' => Icons.lock_outline_rounded,
  _ => Icons.military_tech_outlined,
};
