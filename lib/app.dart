import 'package:flutter/material.dart';

import 'controllers/settings_controller.dart';
import 'screens/home_screen.dart';

class MyApp extends StatelessWidget {
  const MyApp(this._settingsController, {Key? key}) : super(key: key);

  final SettingsController _settingsController;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
        animation: _settingsController,
        builder: (context, child) {
          return MaterialApp(
            title: 'Flutter Demo',
            theme: ThemeData(
              colorScheme: ColorScheme.fromSwatch(
                primarySwatch: Colors.indigo,
                accentColor: Colors.pinkAccent,
              ),
            ),
            darkTheme: ThemeData(
              colorScheme: ColorScheme.fromSwatch(
                primarySwatch: Colors.lime,
                accentColor: Colors.pinkAccent,
                brightness: Brightness.dark,
              ),
            ),
            home: HomeScreen(_settingsController, title: 'Flutter Radio'),
            themeMode: _settingsController.themeMode,
            useInheritedMediaQuery: true,
            debugShowCheckedModeBanner: false,
          );
        });
  }
}
