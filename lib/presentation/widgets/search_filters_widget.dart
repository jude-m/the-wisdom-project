import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/search_provider.dart';

/// Expandable filter panel for search
class SearchFiltersWidget extends ConsumerWidget {
  const SearchFiltersWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filtersVisible = ref.watch(
      searchStateProvider.select((s) => s.filtersVisible),
    );

    if (!filtersVisible) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Filters',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                TextButton(
                  onPressed: () {
                    ref.read(searchStateProvider.notifier).clearFilters();
                  },
                  child: const Text('Clear All'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Language toggles
            _buildSection(
              context,
              'Languages',
              _LanguageToggles(),
            ),

            const SizedBox(height: 16),

            // Nikaya filters
            _buildSection(
              context,
              'Filter by Nikaya',
              _NikayaFilterChips(),
            ),

            const SizedBox(height: 8),

            // Edition checkboxes (future: when multiple editions available)
            // _buildSection(context, 'Editions', _EditionCheckboxes()),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title, Widget content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        content,
      ],
    );
  }
}

/// Language toggle chips
class _LanguageToggles extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchInPali = ref.watch(
      searchStateProvider.select((s) => s.searchInPali),
    );
    final searchInSinhala = ref.watch(
      searchStateProvider.select((s) => s.searchInSinhala),
    );

    return Wrap(
      spacing: 8,
      children: [
        FilterChip(
          label: const Text('Pali'),
          selected: searchInPali,
          onSelected: (selected) {
            ref.read(searchStateProvider.notifier).setLanguageFilter(pali: selected);
          },
        ),
        FilterChip(
          label: const Text('Sinhala'),
          selected: searchInSinhala,
          onSelected: (selected) {
            ref.read(searchStateProvider.notifier).setLanguageFilter(sinhala: selected);
          },
        ),
      ],
    );
  }
}

/// Nikaya filter chips
class _NikayaFilterChips extends ConsumerWidget {
  static const nikayas = [
    {'id': 'dn', 'name': 'Dīgha Nikāya'},
    {'id': 'mn', 'name': 'Majjhima Nikāya'},
    {'id': 'sn', 'name': 'Saṃyutta Nikāya'},
    {'id': 'an', 'name': 'Aṅguttara Nikāya'},
    {'id': 'kn', 'name': 'Khuddaka Nikāya'},
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedNikayas = ref.watch(
      searchStateProvider.select((s) => s.nikayaFilters),
    );

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: nikayas.map((nikaya) {
        final isSelected = selectedNikayas.contains(nikaya['id']);
        return FilterChip(
          label: Text(nikaya['name']!),
          selected: isSelected,
          onSelected: (selected) {
            if (selected) {
              ref.read(searchStateProvider.notifier).addNikayaFilter(nikaya['id']!);
            } else {
              ref.read(searchStateProvider.notifier).removeNikayaFilter(nikaya['id']!);
            }
          },
        );
      }).toList(),
    );
  }
}
