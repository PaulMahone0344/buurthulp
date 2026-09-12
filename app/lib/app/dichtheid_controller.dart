import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme.dart';

/// Bewaart welke dichtheid de app toont. Normaal voor jongere, familie en
/// coordinator; groot voor de hulpvrager. Wordt in M0 alleen vanuit het
/// tijdelijke rolwisselscherm gezet; later volgt hij de ingelogde rol.
class DichtheidController extends Notifier<HhDichtheid> {
  @override
  HhDichtheid build() => HhDichtheid.normaal;

  void zet(HhDichtheid dichtheid) => state = dichtheid;
}

final dichtheidControllerProvider =
    NotifierProvider<DichtheidController, HhDichtheid>(DichtheidController.new);
