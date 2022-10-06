import 'dart:convert';

import 'package:fluttery_radio/models/country.dart';
import 'package:http/http.dart' as http;

import 'api_constants.dart';

class CountryService {
  Future<List<Country>> loadCountries() async {
    final response = await http.get(
      Uri.https(
        ApiConstants.baseUrl,
        ApiConstants.stationsUrl,
      ),
    );

    if (response.statusCode == 200) {
      List responseJson = json.decode(response.body);
      return responseJson.map((s) => Country.fromJson(s)).toList();
    } else {
      throw Exception('Failed to load stations');
    }
  }
}
