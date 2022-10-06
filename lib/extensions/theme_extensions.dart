import 'package:flutter/material.dart';

extension ThemeStrings on ThemeMode {
  String asString() {
    switch (this) {
      case ThemeMode.dark:
        return 'Dark Theme';
      case ThemeMode.light:
        return 'Light Theme';
      case ThemeMode.system:
        return 'System Theme';
    }
  }
}
