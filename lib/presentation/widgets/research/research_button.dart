import 'package:flutter/material.dart';

import '../../../core/localization/l10n/app_localizations.dart';
import 'research_chat_dialog.dart';

/// AppBar action that opens the AI Q&A chat dialog.
class ResearchButton extends StatelessWidget {
  const ResearchButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.auto_awesome_outlined),
      tooltip: AppLocalizations.of(context).researchTitle,
      onPressed: () => ResearchChatDialog.show(context),
    );
  }
}
