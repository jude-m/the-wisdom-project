import 'package:flutter/material.dart';

import '../../../core/localization/l10n/app_localizations.dart';
import 'ask_chat_dialog.dart';

/// AppBar action that opens the AI Q&A chat dialog.
class AskButton extends StatelessWidget {
  const AskButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.auto_awesome_outlined),
      tooltip: AppLocalizations.of(context).askTitle,
      onPressed: () => AskChatDialog.show(context),
    );
  }
}
