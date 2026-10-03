import 'package:go_router/go_router.dart';

import 'paden_chat.dart';
import 'screen/chat_screen.dart';

/// De route van B6. Wordt in lib/app/router.dart met een spread toegevoegd;
/// de sessie-guard daar geldt ook hier. Wie mag lezen beslist de server.
List<RouteBase> chatRoutes() => [
  GoRoute(
    path: HhPadenChat.patroon,
    builder: (context, state) =>
        ChatScreen(klusId: state.pathParameters['id'] ?? ''),
  ),
];
