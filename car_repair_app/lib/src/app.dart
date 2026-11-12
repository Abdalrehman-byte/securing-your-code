import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app_services.dart';
import 'l10n/app_localizations.dart';
import 'ui/home_screen.dart';

class CarRepairApp extends StatefulWidget {
  const CarRepairApp({super.key, required this.services, this.initialLocale});

  final AppServices services;

  /// The saved UI language, or `null` to follow the device language.
  final Locale? initialLocale;

  @override
  State<CarRepairApp> createState() => _CarRepairAppState();
}

class _CarRepairAppState extends State<CarRepairApp> {
  Locale? _locale;

  @override
  void initState() {
    super.initState();
    _locale = widget.initialLocale;
  }

  void _setLocale(Locale locale) {
    setState(() => _locale = locale);
    unawaited(
      widget.services.settings.write(localeSettingKey, locale.languageCode),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      locale: _locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const <LocalizationsDelegate<Object?>>[
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0B5CAD)),
        useMaterial3: true,
      ),
      home: HomeScreen(
        services: widget.services,
        onLocaleChanged: _setLocale,
      ),
    );
  }
}
