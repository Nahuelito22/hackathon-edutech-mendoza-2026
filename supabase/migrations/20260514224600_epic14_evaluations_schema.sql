-- Epic 14: Evaluations Module Schema

DROP TABLE IF EXISTS public.evaluations CASCADE;

-- Create evaluations table
CREATE TABLE IF NOT EXISTS public.evaluations (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    project_id uuid NOT NULL REFERENCES public.projects(id) ON DELETE CASCADE,
    judge_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    score_innovation smallint NOT NULL CHECK (score_innovation BETWEEN 1 AND 10),
    score_viability smallint NOT NULL CHECK (score_viability BETWEEN 1 AND 10),
    score_ux smallint NOT NULL CHECK (score_ux BETWEEN 1 AND 10),
    score_pitch smallint NOT NULL CHECK (score_pitch BETWEEN 1 AND 10),
    feedback text,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE(project_id, judge_id)
);

-- Turn on RLS
ALTER TABLE public.evaluations ENABLE ROW LEVEL SECURITY;

-- Policy: Judges can insert their own evaluations
CREATE POLICY "Judges can insert own evaluations" ON public.evaluations
    FOR INSERT WITH CHECK (
        auth.uid() = judge_id AND 
        EXISTS (
            SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'juez'
        ) AND
        EXISTS (
            SELECT 1 FROM public.event_config WHERE key = 'evaluation_enabled' AND value = 'true'
        )
    );

-- Policy: Judges can update their own evaluations
CREATE POLICY "Judges can update own evaluations" ON public.evaluations
    FOR UPDATE USING (
        auth.uid() = judge_id AND 
        EXISTS (
            SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'juez'
        ) AND
        EXISTS (
            SELECT 1 FROM public.event_config WHERE key = 'evaluation_enabled' AND value = 'true'
        )
    );

-- Policy: Judges can read their own evaluations
CREATE POLICY "Judges can view own evaluations" ON public.evaluations
    FOR SELECT USING (auth.uid() = judge_id);

-- Policy: Admins and superadmins can read all evaluations
CREATE POLICY "Admins can view all evaluations" ON public.evaluations
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('admin', 'superadmin')
        )
    );

-- Create trigger function if it doesn't exist
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Trigger for updated_at
CREATE TRIGGER handle_updated_at BEFORE UPDATE ON public.evaluations
    FOR EACH ROW EXECUTE PROCEDURE public.handle_updated_at();

-- Insert configuration key
INSERT INTO public.event_config (key, value)
VALUES ('evaluation_enabled', 'false')
ON CONFLICT (key) DO NOTHING;

-- Create project_leaderboard view
CREATE OR REPLACE VIEW public.project_leaderboard AS
SELECT 
    p.id AS project_id,
    p.title AS project_title,
    t.name AS team_name,
    COUNT(e.id) AS evaluations_count,
    COALESCE(AVG(e.score_innovation), 0) AS avg_innovation,
    COALESCE(AVG(e.score_viability), 0) AS avg_viability,
    COALESCE(AVG(e.score_ux), 0) AS avg_ux,
    COALESCE(AVG(e.score_pitch), 0) AS avg_pitch,
    COALESCE(AVG(e.score_innovation + e.score_viability + e.score_ux + e.score_pitch), 0) AS final_score
FROM 
    public.projects p
LEFT JOIN 
    public.teams t ON p.team_id = t.id
LEFT JOIN 
    public.evaluations e ON p.id = e.project_id
GROUP BY 
    p.id, p.title, t.name
ORDER BY 
    final_score DESC;
