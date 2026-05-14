-- Fix for RLS preventing users from seeing other team members
DROP POLICY IF EXISTS "users_select_team_members" ON public.profiles;

CREATE OR REPLACE FUNCTION public.get_my_team_id()
RETURNS UUID
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT team_id FROM profiles WHERE id = auth.uid();
$$;

CREATE POLICY "users_select_team_members"
ON public.profiles
FOR SELECT
TO authenticated
USING (
  team_id IS NOT NULL AND team_id = public.get_my_team_id()
);

-- Fix for Realtime filtering on team_id going NULL
ALTER TABLE public.profiles REPLICA IDENTITY FULL;
