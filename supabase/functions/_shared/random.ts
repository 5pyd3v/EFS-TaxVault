// Shared credential-generation helpers. Used wherever a Supabase Auth user
// is created server-side with a randomly generated secret (create-team-member,
// create-sandbox-account) — kept in one place so the encoding/alphabet
// choices stay consistent rather than drifting per-function.

export function base64UrlEncode(bytes: Uint8Array): string {
  let binary = '';
  for (const b of bytes) binary += String.fromCharCode(b);
  return btoa(binary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

// Excludes visually ambiguous characters (0/O, 1/l/I) — this password gets
// read off a screen and typed on a phone keyboard by a human, unlike
// create-team-member's auth_secret which a person never sees or types.
const _PASSWORD_ALPHABET = 'ABCDEFGHJKMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz23456789';

export function randomPassword(length = 12): string {
  const bytes = crypto.getRandomValues(new Uint8Array(length));
  let password = '';
  for (const b of bytes) {
    password += _PASSWORD_ALPHABET[b % _PASSWORD_ALPHABET.length];
  }
  return password;
}
