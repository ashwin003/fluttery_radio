import 'package:country_state_city_picker/country_state_city_picker.dart';
import 'package:flutter/material.dart';

import '../models/location.dart';

typedef LocationSetterCallback = void Function(String country, String? state);

class LocationSelectorDialog extends StatefulWidget {
  final LocationSetterCallback callback;
  final Location? location;
  const LocationSelectorDialog(this.location, this.callback, {super.key});

  @override
  State<LocationSelectorDialog> createState() => _LocationSelectorDialogState();
}

class _LocationSelectorDialogState extends State<LocationSelectorDialog> {
  String countryValue = "";
  String? stateValue = "";

  @override
  void initState() {
    super.initState();
    countryValue = widget.location?.country ?? "";
    stateValue = widget.location?.state;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Location'),
      scrollable: true,
      content: _buildPicker(),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            widget.callback(countryValue, stateValue);
            Navigator.of(context).pop();
          },
          child: const Text('Save'),
        )
      ],
    );
  }

  Widget _buildPicker() {
    return SelectState(
      defaultValue: countryValue.isEmpty ? null : countryValue,
      defaultState: stateValue,
      hideCity: true,
      onCountrySelected: (country) {
        setState(() {
          countryValue = country.name ?? "";
        });
      },
      onStateChanged: (v) {
        setState(() {
          stateValue = v;
        });
      },
    );
  }
}
