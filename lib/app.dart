import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'providers/product_provider.dart';
import 'providers/sale_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/debt_provider.dart';
import 'providers/expense_provider.dart';
import 'screens/activation/activation_screen.dart';
import 'screens/home/home_screen.dart';

class ClowtheXApp extends StatelessWidget {
  const ClowtheXApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider()..load()),
        ChangeNotifierProvider(create: (_) => ProductProvider()..loadAll()),
        ChangeNotifierProvider(create: (_) => SaleProvider()..loadSales()),
        ChangeNotifierProvider(create: (_) => DebtProvider()..loadAll()),
        ChangeNotifierProvider(create: (_) => ExpenseProvider()..loadAll()),
      ],
      child: MaterialApp(
        title: 'ClowtheX',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (context, child) => Directionality(
          textDirection: TextDirection.rtl,
          child: child!,
        ),
        home: const _AppRoot(),
      ),
    );
  }
}

// ─── Root: checks activation then routes ─────────────────────────────────────

class _AppRoot extends StatefulWidget {
  const _AppRoot();

  @override
  State<_AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<_AppRoot> {
  bool? _activated;

  @override
  void initState() {
    super.initState();
    _checkActivation();
  }

  Future<void> _checkActivation() async {
    final activated = await ActivationScreen.isActivated();
    if (mounted) setState(() => _activated = activated);
  }

  void _onActivated() {
    setState(() => _activated = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_activated == null) {
      // Still loading
      return const Scaffold(
        backgroundColor: Color(0xFF0F0F0F),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('ClowtheX',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFD4A017),
                )),
              SizedBox(height: 24),
              CircularProgressIndicator(color: Color(0xFFD4A017)),
            ],
          ),
        ),
      );
    }

    if (!_activated!) {
      return ActivationScreen(onActivated: _onActivated);
    }

    return const HomeScreen();
  }
}
