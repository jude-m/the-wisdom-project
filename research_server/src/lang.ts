// Language detection by Unicode block (Sinhala U+0D80–U+0DFF) — no model call.
const SINHALA = /[඀-෿]/;

export const isSinhala = (text: string): boolean => SINHALA.test(text);

export const detectLang = (text: string): 'si' | 'en' =>
  isSinhala(text) ? 'si' : 'en';
