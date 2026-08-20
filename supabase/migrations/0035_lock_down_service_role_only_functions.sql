-- Security fix. `hash_pin`, `attempt_pin_login`, `finalize_team_member`,
-- and `finalize_sandbox_account` were all designed to be reachable ONLY
-- via an Edge Function's service-role client — none of them re-check the
-- caller's identity internally, because the calling Edge Function was
-- supposed to have already verified authorization first. That trust only
-- holds if nothing else can reach them.
--
-- It didn't hold: Postgres grants EXECUTE on every newly created function
-- to the special PUBLIC pseudo-role by default, and PUBLIC's grant applies
-- to every role — including `anon` (completely unauthenticated) and
-- `authenticated` — REGARDLESS of any later `grant ... to service_role`
-- statement, and regardless of revoking from `anon`/`authenticated`
-- directly (their own explicit grants, separately auto-added by this
-- project's default privileges, could be revoked, but the PUBLIC grant
-- silently kept the same access open under a different name). None of the
-- migrations that created these functions ever revoked the PUBLIC grant,
-- so every one of them was callable directly by anyone with zero
-- authentication — completely bypassing create-team-member's owner/admin
-- check, create-sandbox-account's platform-admin check, and (for
-- attempt_pin_login specifically) login-with-pin's role as the sole
-- intended entry point to the PIN-verification/lockout logic.
--
-- Discovered while debugging create-sandbox-account returning a generic
-- failure (finalize_sandbox_account's since-removed internal
-- is_platform_admin() check always failed for a service-role caller,
-- since auth.uid() is null in that context — a related but separate bug,
-- fixed directly in 0034 by removing that check now that this migration
-- makes the service_role-only grant actually hold).

revoke all on function public.hash_pin(text) from public;
grant execute on function public.hash_pin(text) to service_role;

revoke all on function public.attempt_pin_login(text, text) from public;
grant execute on function public.attempt_pin_login(text, text) to service_role;

revoke all on function public.finalize_team_member(uuid, uuid, text, text, text, text, text, uuid) from public;
grant execute on function public.finalize_team_member(uuid, uuid, text, text, text, text, text, uuid) to service_role;

revoke all on function public.finalize_sandbox_account(uuid, text, uuid) from public;
grant execute on function public.finalize_sandbox_account(uuid, text, uuid) to service_role;
