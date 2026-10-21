import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fraud_signal/app.dart';
import 'package:fraud_signal/core/providers.dart';
import 'package:fraud_signal/data/demo_repository.dart';
import 'package:fraud_signal/features/leads/lead_detail_screen.dart';
import 'package:fraud_signal/features/screens/screens_screen.dart';

Widget _app(DemoRepository repo) => ProviderScope(
      overrides: [repositoryProvider.overrideWithValue(repo)],
      child: const FraudSignalApp(),
    );

Future<void> settle(WidgetTester tester) =>
    tester.pumpAndSettle(const Duration(milliseconds: 100), EnginePhase.sendSemanticsUpdate, const Duration(seconds: 5));

void main() {
  testWidgets('invite-only sign-in rejects unknown accounts and admits demo reviewer', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final repo = DemoRepository(latency: Duration.zero);
    await tester.pumpWidget(_app(repo));
    await settle(tester);

    expect(find.text('Sign in'), findsWidgets);

    await tester.enterText(find.byType(TextFormField).at(0), 'stranger@example.com');
    await tester.enterText(find.byType(TextFormField).at(1), 'demo');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await settle(tester);
    expect(find.textContaining('Invite-only'), findsWidgets);

    await tester.enterText(find.byType(TextFormField).at(0), 'reviewer@demo.fraudsignal');
    await tester.enterText(find.byType(TextFormField).at(1), 'demo');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await settle(tester);

    expect(find.text('Brilliant Disruptions'), findsOneWidget);
    expect(find.textContaining('Risk indicators with evidence'), findsOneWidget);
  });

  testWidgets('opening a lead logs the view and shows the evidence card', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final repo = DemoRepository(latency: Duration.zero);
    await tester.pumpWidget(_app(repo));
    await settle(tester);
    final user = await repo.signIn(email: 'reviewer@demo.fraudsignal', password: 'demo');
    await settle(tester);

    final before = (await repo.accessLog(user)).length;

    await tester.tap(find.text('Leads'));
    await settle(tester);
    await tester.tap(find.textContaining('L-2026-0003').first);
    await settle(tester);

    expect(find.text('Lead gate'), findsOneWidget);
    final list = find.descendant(of: find.byType(LeadDetailScreen), matching: find.byType(Scrollable)).first;
    await tester.scrollUntilVisible(find.text('Innocent-explanation checklist'), 300, scrollable: list);
    expect(find.text('Innocent-explanation checklist'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Audit trail'), 300, scrollable: list);
    expect(find.text('Audit trail'), findsOneWidget);

    final after = await repo.accessLog(user);
    expect(after.length, before + 1);
    expect(after.first.leadId, 'L-2026-0003');
  });

  testWidgets('case-package buyer sees only leads licensed to their firm', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final repo = DemoRepository(latency: Duration.zero);
    await tester.pumpWidget(_app(repo));
    await settle(tester);
    await repo.signIn(email: 'counsel@demo.fraudsignal', password: 'demo');
    await settle(tester);

    await tester.tap(find.text('Leads'));
    await settle(tester);
    expect(find.textContaining('L-2026-0005'), findsOneWidget);
    expect(find.textContaining('L-2026-0001'), findsNothing);
    // Buyers cannot run screens: no Screens tab action.
    await tester.tap(find.text('Screens'));
    await settle(tester);
    expect(find.byType(FloatingActionButton), findsNothing);
  });

  test('NPI check digit', () {
    expect(isValidNpi('1234567893'), isTrue); // canonical CMS example
    expect(isValidNpi('1234567890'), isFalse);
    expect(isValidNpi('199999'), isFalse);
    expect(isValidNpi('1999990001'), isTrue); // demo prefix
  });
}
