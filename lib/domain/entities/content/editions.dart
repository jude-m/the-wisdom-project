import 'edition.dart';

/// The Buddha Jayanti Tripitaka edition — bundled locally with the app.
///
/// `availableLanguages` drives the Content Language options offered to the user
/// (see `availableContentLanguagesProvider`). Phase 1 ships BJT only; a real
/// edition picker can replace the hardcoded `currentEditionProvider` later
/// without touching the Content Language plumbing.
const bjtEdition = Edition(
  editionId: 'bjt',
  displayName: 'Buddha Jayanti Tripitaka',
  abbreviation: 'BJT',
  type: EditionType.local,
  availableLanguages: ['pi', 'si'],
);
