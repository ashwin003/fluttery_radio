import 'package:flutter/material.dart';
import 'package:language_picker/language_picker.dart';
import 'package:language_picker/languages.dart';

typedef LanguageSetterCallback = void Function(Language language);

class LanguageSelectorDialog extends StatelessWidget {
  final LanguageSetterCallback callback;
  final Language? initialValue;
  const LanguageSelectorDialog(this.callback, this.initialValue, {Key? key})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select a Language'),
      content: LanguagePickerDropdown(
        initialValue: initialValue,
        onValuePicked: (language) {
          callback(language);
          Navigator.of(context).pop();
        },
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
