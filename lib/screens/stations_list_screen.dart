import 'package:flutter/material.dart';
import 'package:fluttery_radio/controllers/settings_controller.dart';
import 'package:fluttery_radio/services/station_service.dart';
import 'package:fluttery_radio/widgets/fallback_image.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import '../models/station.dart';

class StationsListScreen extends StatefulWidget {
  final Station? station;
  final SettingsController settingsController;
  const StationsListScreen(this.station, this.settingsController, {Key? key})
      : super(key: key);

  @override
  State<StationsListScreen> createState() => _StationsListScreenState();
}

class _StationsListScreenState extends State<StationsListScreen> {
  static const _pageSize = 20;
  final StationService _stationService = StationService();

  final PagingController<int, Station> _pagingController =
      PagingController(firstPageKey: 1);

  Future<void> _fetchStations(int pageKey, bool replace) async {
    try {
      final location = widget.settingsController.location.value!;
      final newItems = await _stationService.searchStations(
        location.country,
        location.state,
        widget.settingsController.language.name,
        pageKey,
        _pageSize,
      );
      final isLastPage = newItems.length < _pageSize;
      if (replace) {
        _pagingController.refresh();
      }
      if (isLastPage) {
        _pagingController.appendLastPage(newItems);
      } else {
        final nextPageKey = pageKey++;
        _pagingController.appendPage(newItems, nextPageKey);
      }
    } catch (error) {
      _pagingController.error = error;
    }
  }

  Future<void> _fetchPage(int pageKey) async {
    _fetchStations(pageKey, false);
  }

  @override
  void initState() {
    _pagingController.addPageRequestListener((pageKey) {
      _fetchPage(pageKey);
    });
    super.initState();
    widget.settingsController.location.addListener(() {
      _fetchStations(0, true);
    });
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
      selected: widget.station == item,
      leading: FallbackImage(item.favicon, width),
      onTap: () {
        widget.settingsController.updateStation(item);
      },
    );
  }
}
