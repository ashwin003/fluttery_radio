import 'package:flutter/material.dart';

/// A single option in a [SearchablePickerPage].
class PickerOption<T> {
  final T value;
  final String label;
  final String? subtitle;
  final Widget? leading;

  /// Extra text matched by the search box (e.g. a country code).
  final String searchTerms;

  const PickerOption({
    required this.value,
    required this.label,
    this.subtitle,
    this.leading,
    this.searchTerms = '',
  });
}

/// Full-screen, searchable list for picking one value from a long list
/// loaded asynchronously. Pops with the selected value.
class SearchablePickerPage<T> extends StatefulWidget {
  final String title;
  final String searchHint;
  final Future<List<PickerOption<T>>> Function() loader;
  final bool Function(T value)? isSelected;

  /// Options pinned above the search results (e.g. "All regions").
  final List<PickerOption<T>> pinned;

  const SearchablePickerPage({
    super.key,
    required this.title,
    required this.loader,
    this.searchHint = 'Search',
    this.isSelected,
    this.pinned = const [],
  });

  static Future<T?> show<T>(
    BuildContext context, {
    required String title,
    required Future<List<PickerOption<T>>> Function() loader,
    String searchHint = 'Search',
    bool Function(T value)? isSelected,
    List<PickerOption<T>> pinned = const [],
  }) {
    return Navigator.of(context).push<T>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => SearchablePickerPage<T>(
          title: title,
          loader: loader,
          searchHint: searchHint,
          isSelected: isSelected,
          pinned: pinned,
        ),
      ),
    );
  }

  @override
  State<SearchablePickerPage<T>> createState() =>
      _SearchablePickerPageState<T>();
}

class _SearchablePickerPageState<T> extends State<SearchablePickerPage<T>> {
  late Future<List<PickerOption<T>>> _future;
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _future = widget.loader();
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _matches(PickerOption<T> o) =>
      _query.isEmpty ||
      o.label.toLowerCase().contains(_query) ||
      o.searchTerms.toLowerCase().contains(_query);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: SearchBar(
              controller: _searchController,
              hintText: widget.searchHint,
              leading: const Icon(Icons.search),
              elevation: const WidgetStatePropertyAll(0),
              trailing: [
                if (_query.isNotEmpty)
                  IconButton(
                    tooltip: 'Clear',
                    icon: const Icon(Icons.close),
                    onPressed: _searchController.clear,
                  ),
              ],
            ),
          ),
        ),
      ),
      body: FutureBuilder<List<PickerOption<T>>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _ErrorView(
              onRetry: () => setState(() => _future = widget.loader()),
            );
          }
          final pinned = widget.pinned.where(_matches).toList();
          final options = snapshot.data!.where(_matches).toList();
          if (pinned.isEmpty && options.isEmpty) {
            return Center(child: Text('No results for "$_query"'));
          }
          return ListView.builder(
            itemCount:
                pinned.length + options.length + (pinned.isEmpty ? 0 : 1),
            itemBuilder: (context, i) {
              if (i < pinned.length) return _buildTile(pinned[i]);
              if (pinned.isNotEmpty && i == pinned.length) {
                return const Divider(height: 1);
              }
              final offset = pinned.length + (pinned.isEmpty ? 0 : 1);
              return _buildTile(options[i - offset]);
            },
          );
        },
      ),
    );
  }

  Widget _buildTile(PickerOption<T> option) {
    final selected = widget.isSelected?.call(option.value) ?? false;
    return ListTile(
      leading: option.leading,
      title: Text(option.label),
      subtitle: option.subtitle == null ? null : Text(option.subtitle!),
      selected: selected,
      trailing: selected ? const Icon(Icons.check) : null,
      onTap: () => Navigator.of(context).pop(option.value),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorView({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off, size: 48),
          const SizedBox(height: 12),
          const Text("Couldn't load the list. Check your connection."),
          const SizedBox(height: 12),
          FilledButton.tonal(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
