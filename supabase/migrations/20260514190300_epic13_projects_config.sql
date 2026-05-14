-- 1. Insert config
INSERT INTO public.event_config (key, value, description) 
VALUES ('project_submission_enabled', 'false', 'Enable project submission for teams')
ON CONFLICT (key) DO NOTHING;

-- 2. Add UNIQUE constraint to team_id if it doesn't exist
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'projects_team_id_key'
  ) THEN
    ALTER TABLE public.projects ADD CONSTRAINT projects_team_id_key UNIQUE (team_id);
  END IF;
END $$;

-- 3. Setup RLS
ALTER TABLE public.projects ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "admins_read_projects" ON public.projects;
DROP POLICY IF EXISTS "teams_insert_own_project" ON public.projects;
DROP POLICY IF EXISTS "teams_select_own_project" ON public.projects;
DROP POLICY IF EXISTS "teams_update_own_project" ON public.projects;

-- Allow superadmin/admin/juez to read all projects
CREATE POLICY "admins_read_projects" ON public.projects
FOR SELECT TO authenticated
USING (
  public.get_user_role() IN ('superadmin'::user_role, 'admin'::user_role, 'juez'::user_role)
);

-- Allow users to select their own team's project
CREATE POLICY "teams_select_own_project" ON public.projects
FOR SELECT TO authenticated
USING (
  team_id = public.get_my_team_id()
);

-- Allow users to insert their own team's project
CREATE POLICY "teams_insert_own_project" ON public.projects
FOR INSERT TO authenticated
WITH CHECK (
  team_id = public.get_my_team_id()
);

-- Allow users to update their own team's project
CREATE POLICY "teams_update_own_project" ON public.projects
FOR UPDATE TO authenticated
USING (
  team_id = public.get_my_team_id()
)
WITH CHECK (
  team_id = public.get_my_team_id()
);
