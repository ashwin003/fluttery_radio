class Location {
  final String country;
  final String state;

  Location({
    this.country = "",
    this.state = "",
  });

  factory Location.fromJson(Map<String, dynamic> json) {
    return Location(
      country: json["country"],
      state: json["state"],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'country': country,
      'state': state,
    };
  }

  String asString() {
    if (state == "" && country == "") return "";
    if (state == "" && country != "") return country;
    return "$state, $country";
  }
}
