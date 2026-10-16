import 'package:flutter/material.dart';

import 'app/app.dart';
import 'app/theme_controller.dart';
import 'core/database/app_database.dart';
import 'core/database/settings_repository.dart';
import 'core/theme/money_text.dart';
import 'features/customers/data/development_customer_seeder.dart';
import 'features/products/data/development_catalog_seeder.dart';
import 'features/staff/data/development_staff_seeder.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final database = await AppDatabase.open();
    final settings = SettingsRepository(database);
    await settings.ensureSeededDefaults();
    MoneyFormat.defaultSymbol =
        await settings.getStringOrDefault('currency_symbol', 'Rs');
    final themeController = ThemeController(settings);
    await themeController.load();
    await DevelopmentStaffSeeder.seed(database);
    await DevelopmentCatalogSeeder.seed(database);
    await DevelopmentCustomerSeeder.seed(database);
    runApp(
      QubeXCoreApp(database: database, themeController: themeController),
    );
  } catch (error) {
    runApp(DatabaseErrorApp(message: '$error'));
  }
}

class DatabaseErrorApp extends StatelessWidget {
  final String message;

  const DatabaseErrorApp({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'QubeXCore POS',
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 56,
                  color: Colors.redAccent,
                ),
                const SizedBox(height: 16),
                Text(
                  'Unable to open database',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
