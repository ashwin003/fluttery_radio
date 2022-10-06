class Station {
  final String id;
  final String name;
  final String url;
  final String homePage;
  final String favicon;
  final List<String> tags;
  final String country;
  final String countryCode;
  final String state;
  final int votes;
  final String codecs;

  Station({
    required this.id,
    required this.name,
    required this.url,
    required this.homePage,
    required this.favicon,
    required this.tags,
    required this.country,
    required this.countryCode,
    required this.state,
    required this.votes,
    required this.codecs,
  });

  factory Station.fromJson(Map<String, dynamic> json) {
    return Station(
      id: json["stationuuid"],
      name: json["name"],
      url: json["url_resolved"],
      homePage: json["homepage"],
      favicon: json["favicon"],
      tags: json["tags"].toString().split(','),
      country: json["country"],
      countryCode: json["countrycode"],
      state: json["state"],
      votes: json["votes"],
      codecs: json["codec"],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'stationuuid': id,
      'name': name,
      'url_resolved': url,
      'homepage': homePage,
      'favicon': favicon,
      'country': country,
      'countrycode': countryCode,
      'state': state,
      'votes': votes,
      'codec': codecs,
      'tags': tags.join(','),
    };
  }
}
