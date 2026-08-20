// Normalizes phone input to a consistent lookup key so create-team-member
// and login-with-pin always agree on the same string regardless of how the
// user typed it (0300..., +92300..., 92300...). Assumes Pakistan when no
// country code is given, matching this app's market.
export function normalizePhone(raw: string): string {
  let digits = raw.trim().replace(/[^\d+]/g, '');
  if (digits.startsWith('0')) {
    digits = '+92' + digits.slice(1);
  } else if (!digits.startsWith('+')) {
    digits = '+' + digits;
  }
  return digits;
}
