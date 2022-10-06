import 'dart:convert';

import 'package:fluttery_radio/models/station.dart';
import 'package:fluttery_radio/services/api_constants.dart';
import 'package:http/http.dart' as http;

class StationService {
  Future<List<Station>> searchStations(String country, String state,
      String language, int pageNumber, int pageSize) async {
    final queryParameters = {
      'country': country,
      'language': language.toLowerCase(),
      'offset': ((pageNumber - 1) * pageSize).toString(),
      'limit': pageSize.toString(),
      'hidebroken': true.toString(),
      'order': 'clickcount',
      'reverse': true.toString(),
    };
    if (state != "") {
      queryParameters["state"] = state;
    }
    final response = await http.get(
      Uri.https(
        ApiConstants.baseUrl,
        ApiConstants.stationsUrl,
        queryParameters,
      ),
    );

    if (response.statusCode == 200) {
      List responseJson = json.decode(response.body);
      return responseJson.map((s) => Station.fromJson(s)).toList();
    } else {
      throw Exception('Failed to load stations');
    }
  }
}
