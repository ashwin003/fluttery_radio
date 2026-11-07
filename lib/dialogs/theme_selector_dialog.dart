import 'package:flutter/material.dart';
import 'package:fluttery_radio/extensions/theme_extensions.dart';

typedef ThemeSetterCallback = void Function(ThemeMode? themeMode);

/// Single-tap theme picker: choosing an option applies it and closes.
class ThemeSelectorDialog extends StatelessWidget {
  final ThemeMode _theme;
  final ThemeSetterCallback _callback;
  const ThemeSelectorDialog(this._theme, this._callback, {super.key});

  @override
  Widget build(BuildContext context) {
    return SimpleDialog(
      title: const Text('Theme'),
      children: ThemeMode.values.map((mode) {
        final selected = mode == _theme;
        return ListTile(
          leading: Icon(mode.icon),
          title: Text(mode.label),
          subtitle: Text(mode.description),
          selected: selected,
          trailing: selected ? const Icon(Icons.check) : null,
          contentPadding: const EdgeInsets.symmetric(horizontal: 24),
          onTap: () {
            _callback(mode);
            Navigator.of(context).pop();
          },
        );
      }).toList(),
    );
  }
}
