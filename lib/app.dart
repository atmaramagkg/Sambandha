import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'data/models.dart';
import 'screens/about_screen.dart';
import 'screens/entry_screen.dart';
import 'screens/home_screen.dart';
import 'screens/list_screen.dart';
import 'screens/map_screen.dart';
import 'screens/route_detail_screen.dart';
import 'screens/routes_screen.dart';
import 'screens/saved_screen.dart';
import 'screens/search_screen.dart';
import 'widgets/common.dart';

final _router = GoRouter(
  routes: [
    GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
    GoRoute(
      path: '/list/:kind',
      builder: (context, state) {
        final kind = entityKindFromKey(state.pathParameters['kind'] ?? '');
        return ListScreen(kind: kind ?? EntityKind.story);
      },
    ),
    GoRoute(
      path: '/entry/:kind/:id',
      builder: (context, state) {
        final kind = entityKindFromKey(state.pathParameters['kind'] ?? '') ??
            EntityKind.story;
        final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
        return EntryScreen(kind: kind, id: id);
      },
    ),
    GoRoute(path: '/map', builder: (context, state) => const MapScreen()),
    GoRoute(
      path: '/routes',
      builder: (context, state) => const RoutesScreen(),
    ),
    GoRoute(
      path: '/route/:slug',
      builder: (context, state) =>
          RouteDetailScreen(slug: state.pathParameters['slug'] ?? ''),
    ),
    GoRoute(path: '/search', builder: (context, state) => const SearchScreen()),
    GoRoute(path: '/saved', builder: (context, state) => const SavedScreen()),
    GoRoute(path: '/about', builder: (context, state) => const AboutScreen()),
  ],
);

class VrajaMandalaApp extends StatelessWidget {
  const VrajaMandalaApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFFE08A1E); // warm saffron
    return MaterialApp.router(
      title: 'Vraja Mandala',
      debugShowCheckedModeBanner: false,
      routerConfig: _router,
      builder: (context, child) =>
          BottomSafeArea(child: child ?? const SizedBox.shrink()),
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: seed),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.dark,
        ),
      ),
    );
  }
}
