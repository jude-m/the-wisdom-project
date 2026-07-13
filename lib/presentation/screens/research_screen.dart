import 'package:flutter/material.dart';

/// Placeholder for the Research section — intentionally a blank canvas.
///
/// Stage 2 replaces this with the full AI chat UI (recent searches, multiple
/// chat sessions), superseding the v1 ResearchChatDialog. The transcript
/// state already lives in the app-lifetime researchChatProvider, so the chat
/// UI can move here without a state migration.
class ResearchScreen extends StatelessWidget {
  const ResearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: SizedBox.expand());
  }
}
