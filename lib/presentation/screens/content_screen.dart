import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/tree_navigator_widget.dart';
import '../widgets/dual_pane_reader_widget.dart';
import '../widgets/tab_bar_widget.dart';

class ContentScreen extends ConsumerWidget {
  const ContentScreen({super.key});

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
          Expanded(
            child: Column(
              children: [
                // Tab bar
                const TabBarWidget(),

                // Dual Pane Reader
                const Expanded(
                  child: DualPaneReaderWidget(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
