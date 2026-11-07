class Location {
  final String country;

  /// ISO 3166-1 alpha-2 code. Empty for locations saved by older versions.
  final String countryCode;
  final String state;

  Location({this.country = "", this.countryCode = "", this.state = ""});

  factory Location.fromJson(Map<String, dynamic> json) {
    return Location(
      country: json["country"] ?? "",
      countryCode: json["countryCode"] ?? "",
      state: json["state"] ?? "",
    );
  }

  Map<String, dynamic> toJson() {
    return {'country': country, 'countryCode': countryCode, 'state': state};
  }

  String asString() {
    if (state == "" && country == "") return "";
    if (state == "" && country != "") return country;
    return "$state, $country";
  }
}
