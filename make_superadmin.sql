-- ============================================================
-- HEM2026 - Elevación de privilegios a superadmin
-- ============================================================
-- INSTRUCCIONES: Ejecutar este script MANUALMENTE en Supabase
-- SQL Editor DESPUÉS de que el usuario se haya registrado.
-- NO ejecutar antes de que el registro exista en la tabla profiles.
-- ============================================================

UPDATE public.profiles
SET role = 'superadmin'
WHERE email = 'matiasghilardisalinas@gmail.com';
