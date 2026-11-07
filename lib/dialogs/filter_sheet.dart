import 'package:flutter/material.dart';
import 'package:radio_browser_flutter/radio_browser_flutter.dart'
    show RadioBrowserClient, SortOrder;

import '../models/station_query.dart';
import '../widgets/searchable_picker_page.dart';

/// "hindi" → "Hindi", "brazilian portuguese" → "Brazilian Portuguese".
String languageLabel(String language) => language
    .split(' ')
    .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
    .join(' ');

Future<List<PickerOption<String>>>? _languagesCache;

/// Searchable list of radio-browser's languages, most used first.
/// Returns '' for "Any language", or null if dismissed.
Future<String?> pickLanguage(BuildContext context, String? current) {
  return SearchablePickerPage.show<String>(
    context,
    title: 'Language',
    searchHint: 'Search languages',
    isSelected: (l) => l == (current ?? ''),
    pinned: const [
      PickerOption(
        value: '',
        label: 'Any language',
        leading: Icon(Icons.public),
      ),
    ],
    loader: () => _languagesCache ??= RadioBrowserClient.instance.languages
        .fetch(order: SortOrder.stationcount, reverse: true, hideBroken: true)
        .then(
          (list) => [
            for (final l in list)
              if (l.name.trim().isNotEmpty && l.stationCount > 0)
                PickerOption(
                  value: l.name.trim().toLowerCase(),
                  label: languageLabel(l.name.trim()),
                  subtitle: l.stationCount == 1
                      ? '1 station'
                      : '${l.stationCount} stations',
                  leading: const Icon(Icons.translate),
                ),
          ],
        )
        .catchError((Object e) {
          _languagesCache = null; // allow retry
          throw e;
        }),
  );
}

/// Bottom sheet for editing filters. Changes are staged and applied with
/// "Show results", so the list doesn't reload on every tap.
Future<StationQuery?> showFilterSheet(
  BuildContext context,
  StationQuery query,
) {
  return showModalBottomSheet<StationQuery>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => _FilterSheet(initial: query),
  );
}

class _FilterSheet extends StatefulWidget {
  final StationQuery initial;
  const _FilterSheet({required this.initial});

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late StationQuery _query = widget.initial;

  void _update(StationQuery q) => setState(() => _query = q);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text('Filters', style: theme.textTheme.titleLarge),
                ),
                TextButton(
                  onPressed: _query.filterCount == 0
                      ? null
                      : () => _update(
                          StationQuery(
                            sort: _query.sort,
                            search: _query.search,
                          ),
                        ),
                  child: const Text('Reset'),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.favorite_border),
                  title: const Text('Liked stations only'),
                  subtitle: const Text('From any country, saved on device'),
                  value: _query.likedOnly,
                  onChanged: (v) => _update(_query.copyWith(likedOnly: v)),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.lock_outline),
                  title: const Text('Secure streams only'),
                  subtitle: const Text('HTTPS'),
                  value: _query.httpsOnly,
                  onChanged: (v) => _update(_query.copyWith(httpsOnly: v)),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.translate),
                  title: const Text('Language'),
                  subtitle: Text(
                    _query.language == null
                        ? 'Any language'
                        : languageLabel(_query.language!),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    final picked = await pickLanguage(context, _query.language);
                    if (picked == null) return;
                    _update(
                      _query.copyWith(
                        language: () => picked.isEmpty ? null : picked,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                _Section(
                  title: 'Genre',
                  children: [
                    for (final genre in StationQuery.genres)
                      ChoiceChip(
                        label: Text(genre),
                        selected: _query.genre == genre,
                        onSelected: (on) => _update(
                          _query.copyWith(genre: () => on ? genre : null),
                        ),
                      ),
                  ],
                ),
                _Section(
                  title: 'Format',
                  children: [
                    for (final codec in StationQuery.codecs)
                      ChoiceChip(
                        label: Text(codec),
                        selected: _query.codec == codec,
                        onSelected: (on) => _update(
                          _query.copyWith(codec: () => on ? codec : null),
                        ),
                      ),
                  ],
                ),
                _Section(
                  title: 'Minimum quality',
                  children: [
                    ChoiceChip(
                      label: const Text('Any'),
                      selected: _query.minBitrate == 0,
                      onSelected: (_) =>
                          _update(_query.copyWith(minBitrate: 0)),
                    ),
                    for (final kbps in StationQuery.bitrates)
                      ChoiceChip(
                        label: Text('$kbps kbps'),
                        selected: _query.minBitrate == kbps,
                        onSelected: (_) =>
                            _update(_query.copyWith(minBitrate: kbps)),
                      ),
                  ],
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(_query),
                  child: const Text('Show results'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: children),
        ],
      ),
    );
  }
}
