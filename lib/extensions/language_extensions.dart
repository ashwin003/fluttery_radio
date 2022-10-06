import 'package:language_picker/languages.dart';

extension LanguageJson on Language {
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'isoCode': isoCode,
    };
  }
}
