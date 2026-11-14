import 'package:material_ui/material_ui.dart';

import 'package:facturacion_ing_galia/core/company_constants.dart';
import 'package:facturacion_ing_galia/screens/budget_home_screen.dart';

void main() {
  runApp(const IngenieriaGaliaApp());
}

/// Root application widget for Ingeniería Galia, c.a. budgets and invoices.
class IngenieriaGaliaApp extends StatelessWidget {
  const IngenieriaGaliaApp({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: CompanyConstants.headerBlueColor,
      brightness: Brightness.light,
    );

    return MaterialApp(
      title: 'Ingeniería Galia, c.a. — Presupuestos',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: colorScheme,
        scaffoldBackgroundColor: const Color(0xFFF6F8FC),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: colorScheme.outlineVariant),
          ),
        ),
      ),
      home: const BudgetHomeScreen(),
    );
  }
}
