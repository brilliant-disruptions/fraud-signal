import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/config.dart';
import 'core/providers.dart';
import 'core/theme.dart';
import 'features/account/account_screen.dart';
import 'features/audit/bias_audit_screen.dart';
import 'features/auth/sign_in_screen.dart';
import 'features/backtest/backtest_screen.dart';
import 'features/heatmap/heatmap_screen.dart';
import 'features/home/home_screen.dart';
import 'features/leads/lead_detail_screen.dart';
import 'features/leads/leads_screen.dart';
import 'features/rules/rules_screen.dart';
import 'features/screens/screens_screen.dart';
import 'widgets/common.dart';

/// Bridges the auth stream into a [Listenable] so go_router re-evaluates
/// redirects when the user signs in or out.
class _AuthNotifier extends ChangeNotifier {
  _AuthNotifier(Ref ref) {
    ref.listen(currentUserProvider, (_, _) => notifyListeners());
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = _AuthNotifier(ref);
  ref.onDispose(notifier.dispose);
  return GoRouter(
    initialLocation: '/home',
    refreshListenable: notifier,
    redirect: (context, state) {
      final auth = ref.read(currentUserProvider);
      if (auth.isLoading) return null;
      final signedIn = auth.value != null;
      final onSignIn = state.matchedLocation == '/sign-in';
      if (!signedIn && !onSignIn) return '/sign-in';
      if (signedIn && onSignIn) return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/sign-in', builder: (_, _) => const SignInScreen()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => _Shell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: '/home', builder: (_, _) => const HomeScreen())]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/leads',
              builder: (_, _) => const LeadsScreen(),
              routes: [
                GoRoute(path: ':id', builder: (_, s) => LeadDetailScreen(leadId: s.pathParameters['id']!)),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/screens',
              builder: (_, _) => const ScreensScreen(),
              routes: [
                GoRoute(path: 'new', builder: (_, _) => const NewScreenScreen()),
                GoRoute(path: ':id', builder: (_, s) => ScreenDetailScreen(screenId: s.pathParameters['id']!)),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/rules',
              builder: (_, _) => const RulesScreen(),
              routes: [
                GoRoute(path: 'backtest', builder: (_, _) => const BacktestScreen()),
                GoRoute(path: 'bias-audit', builder: (_, _) => const BiasAuditScreen()),
                GoRoute(path: 'heatmap', builder: (_, _) => const HeatmapScreen()),
                GoRoute(path: ':id', builder: (_, s) => RuleDetailScreen(ruleId: s.pathParameters['id']!)),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [GoRoute(path: '/account', builder: (_, _) => const AccountScreen())]),
        ],
      ),
    ],
  );
});

class _Shell extends StatelessWidget {
  const _Shell({required this.shell});
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(children: [
        if (!AppConfig.useSupabase) const DemoBanner(),
        Expanded(child: shell),
      ]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: (i) => shell.goBranch(i, initialLocation: i == shell.currentIndex),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.flag_outlined), selectedIcon: Icon(Icons.flag), label: 'Leads'),
          NavigationDestination(icon: Icon(Icons.fact_check_outlined), selectedIcon: Icon(Icons.fact_check), label: 'Screens'),
          NavigationDestination(icon: Icon(Icons.rule_folder_outlined), selectedIcon: Icon(Icons.rule_folder), label: 'Method'),
          NavigationDestination(icon: Icon(Icons.account_circle_outlined), selectedIcon: Icon(Icons.account_circle), label: 'Account'),
        ],
      ),
    );
  }
}

class FraudSignalApp extends ConsumerWidget {
  const FraudSignalApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      routerConfig: router,
    );
  }
}
