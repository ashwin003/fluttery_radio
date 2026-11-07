import 'package:flutter/material.dart';
import 'package:radio_browser_flutter/radio_browser_flutter.dart'
    show Station, StationSortOrder;

/// How stations are ordered.
enum StationSort {
  popular('Most popular', Icons.local_fire_department_outlined),
  trending('Trending', Icons.trending_up),
  mostLiked('Most liked', Icons.favorite_border),
  name('Name (A-Z)', Icons.sort_by_alpha),
  bitrate('Highest quality', Icons.high_quality_outlined);

  const StationSort(this.label, this.icon);
  final String label;
  final IconData icon;

  StationSortOrder get apiOrder => switch (this) {
    StationSort.popular => StationSortOrder.clickcount,
    StationSort.trending => StationSortOrder.clicktrend,
    StationSort.mostLiked => StationSortOrder.votes,
    StationSort.name => StationSortOrder.name,
    StationSort.bitrate => StationSortOrder.bitrate,
  };

  /// Descending for counts and quality, ascending for names.
  bool get descending => this != StationSort.name;

  /// Sorts locally (used for liked stations, which aren't fetched).
  int compare(Station a, Station b) {
    final result = switch (this) {
      StationSort.popular => a.clickCount.compareTo(b.clickCount),
      StationSort.trending => a.clickTrend.compareTo(b.clickTrend),
      StationSort.mostLiked => a.votes.compareTo(b.votes),
      StationSort.name => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      StationSort.bitrate => a.bitrate.compareTo(b.bitrate),
    };
    return descending ? -result : result;
  }
}

/// List rows or a grid of cards.
enum StationLayout { list, grid }

/// Search text plus filters applied to the station list.
@immutable
class StationQuery {
  final StationSort sort;
  final String search;

  /// A radio-browser tag, e.g. "jazz".
  final String? genre;

  /// e.g. "MP3", "AAC".
  final String? codec;

  /// kbps; 0 = any.
  final int minBitrate;
  final bool httpsOnly;

  /// Show only liked stations (from anywhere, stored on the device).
  final bool likedOnly;

  /// A radio-browser language name, e.g. "hindi"; null = any language.
  final String? language;

  const StationQuery({
    this.sort = StationSort.popular,
    this.search = '',
    this.genre,
    this.codec,
    this.minBitrate = 0,
    this.httpsOnly = false,
    this.likedOnly = false,
    this.language,
  });

  static const genres = [
    'pop',
    'rock',
    'news',
    'talk',
    'jazz',
    'classical',
    'dance',
    'electronic',
    'hiphop',
    'country',
    'oldies',
    '80s',
    '90s',
    'chillout',
    'folk',
    'sports',
    'religious',
    'devotional',
    'bollywood',
    'latin',
  ];

  static const codecs = ['MP3', 'AAC', 'AAC+', 'OGG', 'FLAC'];
  static const bitrates = [64, 128, 192, 320];

  /// Number of filters (excluding sort and search) in effect.
  int get filterCount =>
      (genre != null ? 1 : 0) +
      (codec != null ? 1 : 0) +
      (minBitrate > 0 ? 1 : 0) +
      (httpsOnly ? 1 : 0) +
      (likedOnly ? 1 : 0) +
      (language != null ? 1 : 0);

  bool get hasFilters => filterCount > 0 || search.isNotEmpty;

  StationQuery copyWith({
    StationSort? sort,
    String? search,
    String? Function()? genre,
    String? Function()? codec,
    int? minBitrate,
    bool? httpsOnly,
    bool? likedOnly,
    String? Function()? language,
  }) => StationQuery(
    sort: sort ?? this.sort,
    search: search ?? this.search,
    genre: genre != null ? genre() : this.genre,
    codec: codec != null ? codec() : this.codec,
    minBitrate: minBitrate ?? this.minBitrate,
    httpsOnly: httpsOnly ?? this.httpsOnly,
    likedOnly: likedOnly ?? this.likedOnly,
    language: language != null ? language() : this.language,
  );

  /// Clears filters and search but keeps the sort order.
  StationQuery cleared() => StationQuery(sort: sort);

  /// Applies the filters locally (for liked stations).
  bool matches(Station s) {
    if (search.isNotEmpty &&
        !s.name.toLowerCase().contains(search.toLowerCase())) {
      return false;
    }
    if (genre != null && !s.tags.any((t) => t.toLowerCase() == genre)) {
      return false;
    }
    if (codec != null && s.codec.toUpperCase() != codec) return false;
    if (s.bitrate < minBitrate) return false;
    if (httpsOnly && !s.urlResolved.isScheme('https')) return false;
    if (language != null &&
        !s.language.any((l) => l.trim().toLowerCase() == language)) {
      return false;
    }
    return true;
  }

  @override
  bool operator ==(Object other) =>
      other is StationQuery &&
      other.sort == sort &&
      other.search == search &&
      other.genre == genre &&
      other.codec == codec &&
      other.minBitrate == minBitrate &&
      other.httpsOnly == httpsOnly &&
      other.likedOnly == likedOnly &&
      other.language == language;

  @override
  int get hashCode => Object.hash(
    sort,
    search,
    genre,
    codec,
    minBitrate,
    httpsOnly,
    likedOnly,
    language,
  );
}
