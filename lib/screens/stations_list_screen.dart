import 'package:flutter/material.dart';
import 'package:fluttery_radio/services/station_service.dart';
import 'package:fluttery_radio/widgets/fallback_image.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import '../controllers/settings_controller.dart';
import '../models/station.dart';

class StationsListScreen extends StatefulWidget {
  final SettingsController settingsController;
  const StationsListScreen(this.settingsController, {Key? key})
      : super(key: key);

  @override
  State<StationsListScreen> createState() => _StationsListScreenState();
}

class _StationsListScreenState extends State<StationsListScreen> {
  static const _pageSize = 20;
  final StationService _stationService = StationService();

  final PagingController<int, Station> _pagingController =
      PagingController(firstPageKey: 1);

  Future<void> _fetchPage(int pageKey) async {
    try {
      final newItems = await _stationService.searchStations(
        widget.settingsController.location.country,
        widget.settingsController.location.state,
        widget.settingsController.language.name,
        pageKey,
        _pageSize,
      );
      final isLastPage = newItems.length < _pageSize;
      if (isLastPage) {
        _pagingController.appendLastPage(newItems);
      } else {
        final nextPageKey = pageKey + newItems.length;
        _pagingController.appendPage(newItems, nextPageKey);
      }
    } catch (error) {
      _pagingController.error = error;
    }
  }

  @override
  void initState() {
    _pagingController.addPageRequestListener((pageKey) {
      _fetchPage(pageKey);
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    const double width = 50;
    return _buildRefreshableListView(width);
  }

  Widget _buildRefreshableListView(double width) {
    return RefreshIndicator(
      onRefresh: () => Future.sync(
        () => _pagingController.refresh(),
      ),
      child: _buildListView(width),
    );
  }

  PagedListView<int, Station> _buildListView(double width) {
    return PagedListView<int, Station>(
      pagingController: _pagingController,
      builderDelegate: PagedChildBuilderDelegate<Station>(
        animateTransitions: true,
        transitionDuration: const Duration(milliseconds: 500),
        itemBuilder: (context, item, index) => _buildListTile(item, width),
      ),
    );
  }

  ListTile _buildListTile(Station item, double width) {
    return ListTile(
      title: Text(item.name),
      selected: widget.settingsController.station == item,
      leading: FallbackImage(item.favicon, width),
      onTap: () {
        widget.settingsController.updateStation(item);
      },
    );
  }
}
