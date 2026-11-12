import 'package:flutter/material.dart';

import '../app_services.dart';
import '../l10n/app_localizations.dart';
import 'database_screen.dart';
import 'vin_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.services,
    required this.onLocaleChanged,
  });

  final AppServices services;
  final ValueChanged<Locale> onLocaleChanged;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final arabic = Localizations.localeOf(context).languageCode == 'ar';
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
        actions: <Widget>[
          TextButton(
            key: const Key('language-toggle'),
            onPressed: () => widget.onLocaleChanged(
              arabic ? const Locale('en') : const Locale('ar'),
            ),
            // Each language is named in its own script.
            child: Text(arabic ? 'English' : 'العربية'),
          ),
        ],
      ),
      body: IndexedStack(
        index: _index,
        children: <Widget>[
          DatabaseScreen(
            repository: widget.services.repository,
            onOpenVin: () => setState(() => _index = 1),
          ),
          VinScreen(
            repository: widget.services.repository,
            savedVehicles: widget.services.savedVehicles,
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) => setState(() => _index = index),
        destinations: <Widget>[
          NavigationDestination(
            key: const Key('tab-database'),
            icon: const Icon(Icons.directions_car_outlined),
            label: l10n.tabDatabase,
          ),
          NavigationDestination(
            key: const Key('tab-vin'),
            icon: const Icon(Icons.pin_outlined),
            label: l10n.tabVin,
          ),
        ],
      ),
    );
  }
}
