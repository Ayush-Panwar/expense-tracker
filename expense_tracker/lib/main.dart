import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'presentation/screens/login_screen.dart';
import 'presentation/screens/home_screen.dart';
import 'presentation/providers/auth_provider.dart';
import 'core/theme.dart';
import 'core/di.dart';

void main() {
  DI().init();
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  @override
  void initState() {
    super.initState();
    ref.read(authProvider.notifier).checkAuth();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);

    return MaterialApp(
      title: 'Expense Tracker',
      theme: AppTheme.lightTheme,
      debugShowCheckedModeBanner: false,
      home: auth.isAuthenticated ? const HomeScreen() : const LoginScreen(),
    );
  }
}
