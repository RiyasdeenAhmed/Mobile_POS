import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/database/app_database.dart';
import '../../core/theme/app_theme.dart';
import 'bootstrap_screen.dart';
import 'providers.dart';
import 'routes.dart';

class QubeXCoreApp extends StatelessWidget {
  final AppDatabase database;

  const QubeXCoreApp({super.key, required this.database});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: buildAppProviders(database),
      child: MaterialApp(
        title: 'QubeXCore POS',
        debugShowCheckedModeBanner: false,
        theme: QubeXCoreTheme.light(),
        darkTheme: QubeXCoreTheme.dark(),
        themeMode: ThemeMode.light,
        onGenerateRoute: AppRouter.onGenerateRoute,
        home: const BootstrapScreen(),
      ),
    );
  }
}
