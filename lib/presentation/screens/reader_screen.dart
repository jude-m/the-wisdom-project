import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/tree_navigator_widget.dart';
import '../widgets/multi_pane_reader_widget.dart';
import '../widgets/tab_bar_widget.dart';

class ReaderScreen extends ConsumerWidget {
  const ReaderScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tipitaka'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Row(
        children: [
          // Tree Navigator (left side)
          SizedBox(
            width: 350,
            child: Container(
              decoration: BoxDecoration(
                border: Border(
                  right: BorderSide(
                    color: Theme.of(context).dividerColor,
                    width: 1,
                  ),
                ),
              ),
              child: const TreeNavigatorWidget(),
            ),
          ),

          // Reader area with tabs (right side)
          const Expanded(
            child: Column(
              children: [
                // Tab bar
                TabBarWidget(),

                // Multi-Pane Reader
                Expanded(
                  child: MultiPaneReaderWidget(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
