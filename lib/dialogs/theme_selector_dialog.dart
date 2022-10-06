import 'package:flutter/material.dart';
import 'package:fluttery_radio/extensions/theme_extensions.dart';

typedef ThemeSetterCallback = void Function(ThemeMode? themeMode);

class ThemeSelectorDialog extends StatelessWidget {
  final ThemeMode _theme;
  final ThemeSetterCallback _callback;
  const ThemeSelectorDialog(this._theme, this._callback, {Key? key})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Theme'),
      content: DropdownButton<ThemeMode>(
        // Read the selected themeMode from the controller
        value: _theme,
        // Call the updateThemeMode method any time the user selects a theme.
        onChanged: _callback,
        items: ThemeMode.values
            .map(
              (theme) => DropdownMenuItem(
                value: theme,
                child: Text(theme.asString()),
              ),
            )
            .toList(),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Close'),
        ),
      ],
    );
  }
}
