import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Terug als dat kan, anders naar [anders]. Zo loopt een scherm dat via
/// een diepe link of een redirect is geopend nooit dood.
void terugOf(BuildContext context, String anders) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go(anders);
  }
}
