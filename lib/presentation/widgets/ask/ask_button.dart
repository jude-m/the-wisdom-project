import 'package:flutter/material.dart';

import 'ask_chat_dialog.dart';

/// AppBar action that opens the AI Q&A chat dialog.
///
/// TODO(i18n): localize the tooltip via ARB once the feature graduates from a
/// stub (kept hard-coded for now per "make it work first").
class AskButton extends StatelessWidget {
  const AskButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.auto_awesome_outlined),
      tooltip: 'Ask the Canon',
      onPressed: () => AskChatDialog.show(context),
    );
  }
}
