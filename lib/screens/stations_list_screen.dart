import 'package:flutter/material.dart';
import 'package:fluttery_radio/controllers/settings_controller.dart';
import 'package:fluttery_radio/services/station_service.dart';
import 'package:fluttery_radio/widgets/fallback_image.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:radio_browser_flutter/radio_browser_flutter.dart' show Station;

class StationsListScreen extends StatefulWidget {
  final Station? station;
  final SettingsController settingsController;
  const StationsListScreen(this.station, this.settingsController, {super.key});

  @override
  State<StationsListScreen> createState() => _StationsListScreenState();
}

class _StationsListScreenState extends State<StationsListScreen> {
  static const _pageSize = 20;
  final StationService _stationService = StationService();

  late final PagingController<int, Station> _pagingController =
      PagingController(
        getNextPageKey: (state) {
          final lastPage = state.pages?.lastOrNull;
          if (lastPage != null && lastPage.length < _pageSize) return null;
          return state.nextIntPageKey;
        },
        fetchPage: _fetchStations,
      );

  Future<List<Station>> _fetchStations(int pageKey) {
    final location = widget.settingsController.location.value!;
    return _stationService.searchStations(
      location,
      widget.settingsController.language.name,
      pageKey,
      _pageSize,
    );
  }

  void _onLocationChanged() => _pagingController.refresh();

  @override
  void initState() {
    super.initState();
    widget.settingsController.location.addListener(_onLocationChanged);
  }

  @override
  void dispose() {
    widget.settingsController.location.removeListener(_onLocationChanged);
    _pagingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const double width = 50;
    return _buildRefreshableListView(width);
  }

  Widget _buildRefreshableListView(double width) {
    return RefreshIndicator(
      onRefresh: () => Future.sync(() => _pagingController.refresh()),
      child: _buildListView(width),
    );
  }

  Widget _buildListView(double width) {
    return PagingListener<int, Station>(
      controller: _pagingController,
      builder: (context, state, fetchNextPage) => PagedListView<int, Station>(
        state: state,
        fetchNextPage: fetchNextPage,
        builderDelegate: PagedChildBuilderDelegate<Station>(
          animateTransitions: true,
          transitionDuration: const Duration(milliseconds: 500),
          itemBuilder: (context, item, index) => _buildListTile(item, width),
        ),
      ),
    );
  }

  ListTile _buildListTile(Station item, double width) {
    return ListTile(
      title: Text(item.name),
      selected: widget.station == item,
      leading: FallbackImage(item.favicon.toString(), width),
      onTap: () {
        widget.settingsController.updateStation(item);
      },
    );
  }
}
