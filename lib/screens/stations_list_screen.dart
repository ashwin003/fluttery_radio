import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:fluttery_radio/controllers/settings_controller.dart';
import 'package:fluttery_radio/services/station_service.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:radio_browser_flutter/radio_browser_flutter.dart' show Station;

import '../dialogs/filter_sheet.dart' show languageLabel, showFilterSheet;
import '../dialogs/location_pickers.dart';
import '../models/location.dart';
import '../models/station_query.dart';
import '../widgets/station_items.dart';

/// Home content: collapsing location header, pinned search/sort/filter
/// toolbar, and the stations as a list or a grid of cards.
class StationsListScreen extends StatefulWidget {
  final Station? station;
  final SettingsController settingsController;
  final VoidCallback onOpenSettings;

  /// Space reserved for the collapsed player so the last items stay visible.
  final double bottomPadding;

  /// Injectable for tests; defaults to the radio-browser backed service.
  final StationService? stationService;
  const StationsListScreen(
    this.station,
    this.settingsController, {
    super.key,
    required this.onOpenSettings,
    this.bottomPadding = 0,
    this.stationService,
  });

  @override
  State<StationsListScreen> createState() => _StationsListScreenState();
}

class _StationsListScreenState extends State<StationsListScreen> {
  static const _pageSize = 30;
  late final StationService _stationService =
      widget.stationService ?? StationService();
  final _searchController = TextEditingController();
  Timer? _searchDebounce;

  SettingsController get _controller => widget.settingsController;

  late final PagingController<int, Station> _pagingController =
      PagingController(
        getNextPageKey: (state) {
          final lastPage = state.pages?.lastOrNull;
          if (lastPage != null && lastPage.length < _pageSize) return null;
          return state.nextIntPageKey;
        },
        fetchPage: _fetchStations,
      );

  bool get _hasLocation =>
      (_controller.location.value?.country ?? '').isNotEmpty;

  Future<List<Station>> _fetchStations(int pageKey) async {
    final query = _controller.query.value;
    if (query.likedOnly) {
      // Liked stations live on the device: filter, sort and page locally.
      final liked = _controller.likedStations.where(query.matches).toList()
        ..sort(query.sort.compare);
      final start = (pageKey - 1) * _pageSize;
      if (start >= liked.length) return [];
      return liked.sublist(start, math.min(start + _pageSize, liked.length));
    }
    if (!_hasLocation) return [];
    return _stationService.searchStations(
      _controller.location.value!,
      query,
      pageKey,
      _pageSize,
    );
  }

  void _refresh() => _pagingController.refresh();

  void _onSettingsChanged() {
    if (mounted) setState(() {}); // liked markers
  }

  void _onSearchChanged() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      _controller.updateQuery(
        _controller.query.value.copyWith(search: _searchController.text.trim()),
      );
    });
    setState(() {}); // clear button
  }

  @override
  void initState() {
    super.initState();
    _searchController.text = _controller.query.value.search;
    _searchController.addListener(_onSearchChanged);
    _controller.location.addListener(_refresh);
    _controller.query.addListener(_refresh);
    _controller.addListener(_onSettingsChanged);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _controller.location.removeListener(_refresh);
    _controller.query.removeListener(_refresh);
    _controller.removeListener(_onSettingsChanged);
    _pagingController.dispose();
    super.dispose();
  }

  Future<void> _openFilters() async {
    final result = await showFilterSheet(context, _controller.query.value);
    if (result != null) await _controller.updateQuery(result);
  }

  void _clearFilters() {
    _searchController.clear();
    _controller.updateQuery(_controller.query.value.cleared());
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<StationQuery>(
      valueListenable: _controller.query,
      builder: (context, query, _) => ValueListenableBuilder<StationLayout>(
        valueListenable: _controller.layout,
        builder: (context, layout, _) => RefreshIndicator(
          onRefresh: () => Future.sync(_refresh),
          edgeOffset: 200,
          child: CustomScrollView(
            slivers: [
              _buildAppBar(context, query),
              SliverPersistentHeader(
                pinned: true,
                delegate: _ToolbarDelegate(
                  child: _Toolbar(
                    query: query,
                    layout: layout,
                    searchController: _searchController,
                    onOpenFilters: _openFilters,
                    onQueryChanged: _controller.updateQuery,
                    onLayoutChanged: _controller.updateLayout,
                  ),
                ),
              ),
              if (!_hasLocation && !query.likedOnly)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _NoLocationMessage(
                    onChoose: () => chooseCountry(context, _controller),
                  ),
                )
              else
                _buildResults(context, query, layout),
              SliverToBoxAdapter(
                child: SizedBox(height: widget.bottomPadding + 16),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, StationQuery query) {
    return SliverAppBar.large(
      title: ValueListenableBuilder<Location?>(
        valueListenable: _controller.location,
        builder: (context, location, _) => _LocationTitle(
          location: location,
          likedOnly: query.likedOnly,
          onTap: () => chooseCountry(context, _controller),
        ),
      ),
      actions: [
        IconButton(
          tooltip: 'Settings',
          icon: const Icon(Icons.settings_outlined),
          onPressed: widget.onOpenSettings,
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  Widget _buildResults(
    BuildContext context,
    StationQuery query,
    StationLayout layout,
  ) {
    final delegate = PagedChildBuilderDelegate<Station>(
      animateTransitions: !MediaQuery.disableAnimationsOf(context),
      itemBuilder: (context, station, index) {
        final selected = widget.station?.stationUUID == station.stationUUID;
        final liked = _controller.isLiked(station);
        void onTap() => _controller.updateStation(station);
        return layout == StationLayout.grid
            ? StationCard(
                station: station,
                selected: selected,
                liked: liked,
                onTap: onTap,
              )
            : StationTile(
                station: station,
                selected: selected,
                liked: liked,
                onTap: onTap,
              );
      },
      noItemsFoundIndicatorBuilder: (context) => _EmptyResults(
        // "Liked only" by itself means the user simply has no likes yet.
        noLikesYet:
            query.likedOnly && query.filterCount == 1 && query.search.isEmpty,
        hasFilters: query.hasFilters,
        onClear: _clearFilters,
      ),
      firstPageErrorIndicatorBuilder: (context) =>
          _ErrorMessage(onRetry: _refresh),
    );

    return PagingListener<int, Station>(
      controller: _pagingController,
      builder: (context, state, fetchNextPage) => layout == StationLayout.grid
          ? SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              // Cards are square artwork plus a text area sized for the
              // current text scale, so names never overflow.
              sliver: SliverLayoutBuilder(
                builder: (context, constraints) {
                  const spacing = 12.0;
                  const maxCardWidth = 200.0;
                  final width = constraints.crossAxisExtent;
                  final columns = math.max(
                    1,
                    ((width + spacing) / (maxCardWidth + spacing)).ceil(),
                  );
                  final cardWidth = (width - spacing * (columns - 1)) / columns;
                  return PagedSliverGrid<int, Station>(
                    state: state,
                    fetchNextPage: fetchNextPage,
                    builderDelegate: delegate,
                    showNoMoreItemsIndicatorAsGridChild: false,
                    showNewPageProgressIndicatorAsGridChild: false,
                    showNewPageErrorIndicatorAsGridChild: false,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      mainAxisSpacing: spacing,
                      crossAxisSpacing: spacing,
                      mainAxisExtent:
                          cardWidth + StationCard.textAreaHeight(context),
                    ),
                  );
                },
              ),
            )
          : PagedSliverList<int, Station>(
              state: state,
              fetchNextPage: fetchNextPage,
              builderDelegate: delegate,
            ),
    );
  }
}

class _LocationTitle extends StatelessWidget {
  final Location? location;
  final bool likedOnly;
  final VoidCallback onTap;
  const _LocationTitle({
    required this.location,
    required this.likedOnly,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (likedOnly) return const Text('Liked stations');
    final loc = location;
    if (loc == null || loc.country.isEmpty) return const Text('Stations');
    final flag = loc.countryCode.isNotEmpty
        ? '${flagEmoji(loc.countryCode)} '
        : '';
    return Semantics(
      button: true,
      hint: 'Change location',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                '$flag${loc.asString()}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.arrow_drop_down_rounded),
          ],
        ),
      ),
    );
  }
}

class _ToolbarDelegate extends SliverPersistentHeaderDelegate {
  static const height = 124.0;
  final Widget child;
  _ToolbarDelegate({required this.child});

  @override
  double get minExtent => height;
  @override
  double get maxExtent => height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlaps) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: overlaps ? scheme.surfaceContainer : scheme.surface,
      child: child,
    );
  }

  @override
  bool shouldRebuild(_ToolbarDelegate oldDelegate) =>
      oldDelegate.child != child;
}

class _Toolbar extends StatelessWidget {
  final StationQuery query;
  final StationLayout layout;
  final TextEditingController searchController;
  final VoidCallback onOpenFilters;
  final ValueChanged<StationQuery> onQueryChanged;
  final ValueChanged<StationLayout> onLayoutChanged;
  const _Toolbar({
    required this.query,
    required this.layout,
    required this.searchController,
    required this.onOpenFilters,
    required this.onQueryChanged,
    required this.onLayoutChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: SearchBar(
            controller: searchController,
            hintText: 'Search stations',
            elevation: const WidgetStatePropertyAll(0),
            leading: const Icon(Icons.search),
            trailing: [
              if (searchController.text.isNotEmpty)
                IconButton(
                  tooltip: 'Clear search',
                  icon: const Icon(Icons.close),
                  onPressed: searchController.clear,
                ),
              IconButton(
                tooltip: 'Filters',
                onPressed: onOpenFilters,
                icon: Badge(
                  isLabelVisible: query.filterCount > 0,
                  label: Text('${query.filterCount}'),
                  child: const Icon(Icons.tune),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 48,
          child: Row(
            children: [
              Expanded(
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.only(left: 16, right: 8),
                  children: [
                    _SortMenu(
                      sort: query.sort,
                      onChanged: (s) => onQueryChanged(query.copyWith(sort: s)),
                    ),
                    ..._activeFilterChips(),
                  ].expand((w) => [w, const SizedBox(width: 8)]).toList(),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: SegmentedButton<StationLayout>(
                  showSelectedIcon: false,
                  style: const ButtonStyle(
                    visualDensity: VisualDensity.compact,
                  ),
                  segments: const [
                    ButtonSegment(
                      value: StationLayout.list,
                      icon: Icon(Icons.view_list_rounded),
                      tooltip: 'List',
                    ),
                    ButtonSegment(
                      value: StationLayout.grid,
                      icon: Icon(Icons.grid_view_rounded),
                      tooltip: 'Cards',
                    ),
                  ],
                  selected: {layout},
                  onSelectionChanged: (s) => onLayoutChanged(s.first),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _activeFilterChips() {
    Widget chip(String label, StationQuery without, {IconData? icon}) =>
        InputChip(
          avatar: icon == null ? null : Icon(icon, size: 18),
          label: Text(label),
          onDeleted: () => onQueryChanged(without),
          deleteButtonTooltipMessage: 'Remove filter',
          onPressed: onOpenFilters,
        );
    return [
      if (query.likedOnly)
        chip(
          'Liked',
          query.copyWith(likedOnly: false),
          icon: Icons.favorite_rounded,
        ),
      if (query.genre case final genre?)
        chip(genre, query.copyWith(genre: () => null)),
      if (query.codec case final codec?)
        chip(codec, query.copyWith(codec: () => null)),
      if (query.minBitrate > 0)
        chip('${query.minBitrate}+ kbps', query.copyWith(minBitrate: 0)),
      if (query.language case final language?)
        chip(
          languageLabel(language),
          query.copyWith(language: () => null),
          icon: Icons.translate,
        ),
      if (query.httpsOnly)
        chip(
          'Secure',
          query.copyWith(httpsOnly: false),
          icon: Icons.lock_outline,
        ),
    ];
  }
}

class _SortMenu extends StatelessWidget {
  final StationSort sort;
  final ValueChanged<StationSort> onChanged;
  const _SortMenu({required this.sort, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      menuChildren: [
        for (final option in StationSort.values)
          MenuItemButton(
            leadingIcon: Icon(option.icon),
            trailingIcon: option == sort ? const Icon(Icons.check) : null,
            onPressed: () => onChanged(option),
            child: Text(option.label),
          ),
      ],
      builder: (context, menu, _) => ActionChip(
        avatar: Icon(sort.icon, size: 18),
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(sort.label),
            const Icon(Icons.arrow_drop_down_rounded, size: 20),
          ],
        ),
        tooltip: 'Sort',
        onPressed: () => menu.isOpen ? menu.close() : menu.open(),
      ),
    );
  }
}

class _EmptyResults extends StatelessWidget {
  final bool noLikesYet;
  final bool hasFilters;
  final VoidCallback onClear;
  const _EmptyResults({
    required this.noLikesYet,
    required this.hasFilters,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (icon, title, body) = noLikesYet
        ? (
            Icons.favorite_border,
            'No liked stations yet',
            'Tap the heart in the player to save stations here.',
          )
        : (
            Icons.search_off_rounded,
            'No stations found',
            'Try a different search or fewer filters.',
          );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(height: 16),
          Text(title, style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            body,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (hasFilters && !noLikesYet) ...[
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: onClear,
              child: const Text('Clear filters'),
            ),
          ],
        ],
      ),
    );
  }
}

class _ErrorMessage extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorMessage({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_rounded, size: 48),
          const SizedBox(height: 16),
          const Text("Couldn't load stations. Check your connection."),
          const SizedBox(height: 16),
          FilledButton.tonal(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _NoLocationMessage extends StatelessWidget {
  final VoidCallback onChoose;
  const _NoLocationMessage({required this.onChoose});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.radio, size: 64),
            const SizedBox(height: 16),
            const Text(
              'Choose a country to see its radio stations',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              icon: const Icon(Icons.flag_outlined),
              label: const Text('Choose country'),
              onPressed: onChoose,
            ),
          ],
        ),
      ),
    );
  }
}
