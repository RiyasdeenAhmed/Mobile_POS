import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/database/app_database.dart';
import '../../core/theme/app_theme.dart';
import 'bootstrap_screen.dart';
import 'providers.dart';
import 'routes.dart';
import 'theme_controller.dart';

class QubeXCoreApp extends StatelessWidget {
  final AppDatabase database;
  final ThemeController? themeController;

  const QubeXCoreApp({
    super.key,
    required this.database,
    this.themeController,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: buildAppProviders(database, themeController: themeController),
      child: const _AppView(),
    );
  }
}

class _AppView extends StatelessWidget {
  const _AppView();

  @override
  Widget build(BuildContext context) {
    final themeMode = context.watch<ThemeController>().mode;
    return MaterialApp(
      title: 'QubeXCore',
      debugShowCheckedModeBanner: false,
      theme: QubeXCoreTheme.light(),
      darkTheme: QubeXCoreTheme.dark(),
      themeMode: themeMode,
      onGenerateRoute: AppRouter.onGenerateRoute,
      home: const BootstrapScreen(),
    );
  }
}
