-- Notifications had no delete path at all, DB or client — add the missing
-- RLS policy so a user can dismiss their own notifications.
create policy "notifications_delete_own" on public.notifications
  for delete using (user_id = auth.uid());
