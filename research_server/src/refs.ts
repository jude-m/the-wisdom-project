// Canonical-reference helpers: uid → display ref ("sn15.3" → "SN 15.3") and
// back, plus the prose-ref matcher the linkifier uses. knownUid is a shape
// check (no manifest yet) — it drops refs that can't be real corpus ids.

const NIKAYAS = ['SN', 'MN', 'DN', 'AN', 'KN', 'Snp', 'Dhp', 'Ud', 'Iti', 'Thag', 'Thig'];

export const REF_IN_PROSE = new RegExp(
  `\\b(?:${NIKAYAS.join('|')})\\s?\\d+(?:\\.\\d+)?\\b`,
  'g',
);

const UID_SUTTA = /^([a-z]+)(\d.*)$/;

export function refFromUid(uid: string): string {
  if (uid.startsWith('pli-tv-')) return uid;
  const m = UID_SUTTA.exec(uid);
  return m ? `${m[1]!.toUpperCase()} ${m[2]}` : uid;
}

export function uidFromRef(ref: string): string | null {
  const s = ref.trim().toLowerCase().replace(/ /g, '');
  return /^[a-z]+\d/.test(s) ? s : null;
}

export const knownUid = (uid: string): boolean =>
  UID_SUTTA.test(uid) || uid.startsWith('pli-tv-');
