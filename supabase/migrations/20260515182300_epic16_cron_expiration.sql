-- supabase/migrations/20260515182300_epic16_cron_expiration.sql
-- Cron job for expiring stale help requests

-- Enable pg_cron if not already enabled
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Schedule the expiration task to run every 5 minutes
-- Logic: 
-- 1. Pendiente > 30 min -> expirado
-- 2. En camino > 60 min -> expirado (limpieza de seguridad)
SELECT cron.schedule(
  'expire-stale-help-requests',
  '*/5 * * * *',
  $$
  UPDATE public.help_requests
  SET status = 'expirado'
  WHERE status = 'pendiente'
    AND created_at < now() - interval '30 minutes';

  UPDATE public.help_requests
  SET status = 'expirado'
  WHERE status = 'en_camino'
    AND started_at < now() - interval '60 minutes';
  $$
);
