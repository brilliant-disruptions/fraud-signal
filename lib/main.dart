import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config.dart';
import 'core/providers.dart';
import 'data/demo_repository.dart';
import 'data/repository.dart';
import 'data/supabase_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final FraudSignalRepository repository;
  if (AppConfig.useSupabase) {
    await Supabase.initialize(url: AppConfig.supabaseUrl, publishableKey: AppConfig.supabaseAnonKey);
    repository = SupabaseRepository(Supabase.instance.client);
  } else {
    final demo = DemoRepository();
    if (AppConfig.demoAutoSignIn.isNotEmpty) {
      await demo.signIn(email: AppConfig.demoAutoSignIn, password: 'demo');
    }
    repository = demo;
  }

  runApp(
    ProviderScope(
      overrides: [repositoryProvider.overrideWithValue(repository)],
      child: const FraudSignalApp(),
    ),
  );
}
