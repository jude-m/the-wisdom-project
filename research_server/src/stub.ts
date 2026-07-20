// Canned answer — the keyless bridge. Mirrors the live shape: inline
// [[cite:uid]] markers, one resolvable uid (sn15.3) and one unresolved (mn10).

import { ResearchResponse } from './contracts.js';
import { detectLang } from './lang.js';

const REPLY = {
  en:
    '[stub] research_server received your question:\n\n' +
    '  “{q}”\n\n' +
    'The canon addresses this in the Anamatagga Saṁyutta[[cite:sn15.3]] and ' +
    'in the discourse on mindfulness meditation[[cite:mn10]]. This is a canned ' +
    'reply — no Gemini call yet (detected language: English). ' +
    'Set RESEARCH_STUB=0 with GEMINI_API_KEY + RESEARCH_STORE for real answers.',
  si:
    '[stub] ඔබගේ ප්‍රශ්නය research_server වෙත ලැබුණා:\n\n' +
    '  “{q}”\n\n' +
    'මෙය අනමතග්ග සංයුත්තයේ[[cite:sn15.3]] සහ සතිපට්ඨාන සූත්‍රයේ[[cite:mn10]] ' +
    'සඳහන් වේ. මෙය පූර්ව-සැකසූ පිළිතුරකි — තවම Gemini ඇමතුමක් නැත (හඳුනාගත් භාෂාව: ' +
    'සිංහල). සැබෑ පිළිතුරු සඳහා RESEARCH_STUB=0, GEMINI_API_KEY සහ RESEARCH_STORE සකසන්න.',
};

export function cannedAnswer(question: string): ResearchResponse {
  const lang = detectLang(question);
  return {
    answer: REPLY[lang].replace('{q}', question),
    lang,
    model: 'stub',
    citations: [
      {
        uid: 'sn15.3',
        ref: 'SN 15.3',
        title: 'Tears',
        kind: 'canon',
        snippet:
          'The stream of **tears** you have shed… is more than the water ' +
          'in the four **oceans**.',      },
      {
        uid: 'mn10',
        ref: 'MN 10',
        title: 'Satipaṭṭhāna',
        kind: 'canon',
        snippet: 'The four kinds of **mindfulness** meditation.',      },
    ],
  };
}
