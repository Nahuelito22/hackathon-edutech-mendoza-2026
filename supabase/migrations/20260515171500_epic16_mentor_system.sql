-- 1.1 Tabla help_requests (Tickets SOS)
CREATE TABLE IF NOT EXISTS public.help_requests (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  team_id     UUID NOT NULL REFERENCES public.teams(id) ON DELETE CASCADE,
  mentor_id   UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  status      TEXT NOT NULL CHECK (status IN ('pendiente', 'en_camino', 'finalizado', 'expirado')) DEFAULT 'pendiente',
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  started_at  TIMESTAMPTZ,
  finished_at TIMESTAMPTZ
);

-- Índices para búsquedas eficientes
CREATE INDEX idx_help_requests_team    ON public.help_requests(team_id);
CREATE INDEX idx_help_requests_mentor  ON public.help_requests(mentor_id);
CREATE INDEX idx_help_requests_status  ON public.help_requests(status);

-- Constraint: un solo ticket activo por equipo (pendiente o en_camino)
CREATE UNIQUE INDEX idx_one_active_help_request
  ON public.help_requests(team_id)
  WHERE status IN ('pendiente', 'en_camino');

-- 1.2 Columna mentor_id en teams
ALTER TABLE public.teams
  ADD COLUMN IF NOT EXISTS mentor_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL;

-- 1.3 Políticas RLS para help_requests
ALTER TABLE public.help_requests ENABLE ROW LEVEL SECURITY;

-- Participantes: pueden leer los tickets de su propio equipo
CREATE POLICY "team_members_read_own_help_requests" ON public.help_requests
  FOR SELECT TO authenticated
  USING (
    team_id = public.get_my_team_id()
  );

-- Mentores: pueden leer tickets donde son el mentor asignado
CREATE POLICY "mentors_read_assigned_help_requests" ON public.help_requests
  FOR SELECT TO authenticated
  USING (
    mentor_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND role = 'mentor'
    )
  );

-- Admins: acceso total de lectura
CREATE POLICY "admins_read_all_help_requests" ON public.help_requests
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND role IN ('admin', 'superadmin')
    )
  );

-- 1.4 Claves en event_config
INSERT INTO public.event_config (key, value, description) VALUES
  ('help_enabled',             'false', 'Habilita o deshabilita los pedidos SOS a nivel general'),
  ('mentor_session_duration',  '15',    'Tiempo en minutos por defecto para cada sesión de mentoría'),
  ('help_cooldown_minutes',    '5',     'Cooldown en minutos entre pedidos SOS del mismo equipo')
ON CONFLICT (key) DO NOTHING;

-- 1.5 RPC: request_help()
CREATE OR REPLACE FUNCTION public.request_help()
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_team_id   UUID;
  v_mentor_id UUID;
  v_recent    TIMESTAMPTZ;
  v_cooldown  INT;
  v_enabled   TEXT;
  v_ticket_id UUID;
BEGIN
  -- 1. Obtener el equipo y mentor del usuario actual
  SELECT team_id INTO v_team_id FROM profiles WHERE id = auth.uid();
  IF v_team_id IS NULL THEN
    RETURN json_build_object('ok', false, 'error', 'No pertenecés a ningún equipo.');
  END IF;

  SELECT mentor_id INTO v_mentor_id FROM teams WHERE id = v_team_id;
  IF v_mentor_id IS NULL THEN
    RETURN json_build_object('ok', false, 'error', 'Tu equipo no tiene mentor asignado aún.');
  END IF;

  -- 2. Verificar que help_enabled esté activo
  SELECT value INTO v_enabled FROM event_config WHERE key = 'help_enabled';
  IF v_enabled IS NULL OR v_enabled <> 'true' THEN
    RETURN json_build_object('ok', false, 'error', 'Los pedidos de ayuda están deshabilitados.');
  END IF;

  -- 3. Verificar que no haya un ticket activo
  IF EXISTS (
    SELECT 1 FROM help_requests
    WHERE team_id = v_team_id AND status IN ('pendiente', 'en_camino')
  ) THEN
    RETURN json_build_object('ok', false, 'error', 'Tu equipo ya tiene un pedido de ayuda activo.');
  END IF;

  -- 4. Verificar cooldown
  SELECT value INTO v_cooldown FROM event_config WHERE key = 'help_cooldown_minutes';
  v_cooldown := COALESCE(v_cooldown::INT, 0);

  IF v_cooldown > 0 THEN
    SELECT MAX(finished_at) INTO v_recent
    FROM help_requests
    WHERE team_id = v_team_id AND status = 'finalizado';

    IF v_recent IS NOT NULL AND (now() - v_recent) < (v_cooldown || ' minutes')::INTERVAL THEN
      RETURN json_build_object(
        'ok', false,
        'error', 'Debés esperar ' || v_cooldown || ' minutos entre pedidos de ayuda.'
      );
    END IF;
  END IF;

  -- 5. Crear el ticket
  INSERT INTO help_requests (team_id, mentor_id, status)
  VALUES (v_team_id, v_mentor_id, 'pendiente')
  RETURNING id INTO v_ticket_id;

  RETURN json_build_object('ok', true, 'ticket_id', v_ticket_id);
END;
$$;

-- 1.6 RPC: mentor_update_ticket()
CREATE OR REPLACE FUNCTION public.mentor_update_ticket(
  p_ticket_id UUID,
  p_new_status TEXT
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_ticket RECORD;
BEGIN
  -- 1. Obtener el ticket
  SELECT * INTO v_ticket FROM help_requests WHERE id = p_ticket_id;

  IF NOT FOUND THEN
    RETURN json_build_object('ok', false, 'error', 'Ticket no encontrado.');
  END IF;

  -- 2. Verificar que el caller es el mentor asignado
  IF v_ticket.mentor_id IS NULL OR v_ticket.mentor_id <> auth.uid() THEN
    RETURN json_build_object('ok', false, 'error', 'No tenés permiso para actualizar este ticket.');
  END IF;

  -- 3. Validar transiciones de estado
  IF NOT (
    (v_ticket.status = 'pendiente' AND p_new_status IN ('en_camino', 'finalizado'))
    OR
    (v_ticket.status = 'en_camino' AND p_new_status = 'finalizado')
  ) THEN
    RETURN json_build_object(
      'ok', false,
      'error', 'Transición inválida: ' || v_ticket.status || ' -> ' || p_new_status
    );
  END IF;

  -- 4. Actualizar con timestamps correspondientes
  UPDATE help_requests
  SET
    status      = p_new_status,
    started_at  = CASE WHEN p_new_status = 'en_camino' THEN now() ELSE started_at END,
    finished_at = CASE WHEN p_new_status = 'finalizado' THEN now() ELSE finished_at END
  WHERE id = p_ticket_id;

  RETURN json_build_object('ok', true, 'new_status', p_new_status);
END;
$$;

-- 1.7 RPC: assign_mentors_randomly()
CREATE OR REPLACE FUNCTION public.assign_mentors_randomly(
  reset_current BOOLEAN DEFAULT false
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  mentors_array UUID[];
  mentor_count  INT;
  i             INT := 1;
  teams_updated INT := 0;
  v_caller_role TEXT;
  rec           RECORD;
BEGIN
  -- 0. Solo admins pueden ejecutar esto
  SELECT role INTO v_caller_role FROM profiles WHERE id = auth.uid();
  IF v_caller_role NOT IN ('admin', 'superadmin') THEN
    RETURN json_build_object('ok', false, 'error', 'Permisos insuficientes.');
  END IF;

  -- 1. Si se pide resetear, poner todos los mentor_id en NULL
  IF reset_current THEN
    UPDATE teams SET mentor_id = NULL;
  END IF;

  -- 2. Obtener mentores aprobados
  SELECT array_agg(id) INTO mentors_array
  FROM profiles
  WHERE role = 'mentor' AND registration_status = 'aprobado';

  mentor_count := array_length(mentors_array, 1);

  IF mentor_count IS NULL OR mentor_count = 0 THEN
    RETURN json_build_object(
      'ok', false,
      'error', 'No hay mentores aprobados disponibles.',
      'teams_updated', 0
    );
  END IF;

  -- 3. Shuffle de mentores para aleatoriedad inicial
  SELECT array_agg(val) INTO mentors_array
  FROM (SELECT unnest(mentors_array) AS val ORDER BY random()) s;

  -- 4. Asignar con round-robin a equipos sin mentor
  FOR rec IN SELECT id FROM teams WHERE mentor_id IS NULL
  LOOP
    UPDATE teams SET mentor_id = mentors_array[i] WHERE id = rec.id;
    teams_updated := teams_updated + 1;
    i := i + 1;
    IF i > mentor_count THEN i := 1; END IF;
  END LOOP;

  RETURN json_build_object(
    'ok', true,
    'teams_updated', teams_updated,
    'mentors_used', mentor_count
  );
END;
$$;

-- 1.8 Vista: mentor_help_stats
CREATE OR REPLACE VIEW public.mentor_help_stats AS
SELECT
  p.id                     AS mentor_id,
  p.full_name              AS mentor_name,
  COUNT(hr.id)             AS total_tickets,
  COUNT(hr.id) FILTER (WHERE hr.status = 'pendiente')  AS pending_count,
  COUNT(hr.id) FILTER (WHERE hr.status = 'en_camino')  AS in_progress_count,
  COUNT(hr.id) FILTER (WHERE hr.status = 'finalizado') AS finished_count,
  COUNT(hr.id) FILTER (WHERE hr.status = 'expirado')   AS expired_count,
  COALESCE(
    ROUND(
      AVG(
        EXTRACT(EPOCH FROM (hr.started_at - hr.created_at)) / 60
      ) FILTER (WHERE hr.started_at IS NOT NULL)
    , 1
    ), 0
  ) AS avg_response_minutes,
  COALESCE(
    ROUND(
      AVG(
        EXTRACT(EPOCH FROM (hr.finished_at - hr.started_at)) / 60
      ) FILTER (WHERE hr.finished_at IS NOT NULL AND hr.started_at IS NOT NULL)
    , 1
    ), 0
  ) AS avg_session_minutes,
  (SELECT COUNT(*) FROM teams t WHERE t.mentor_id = p.id) AS assigned_teams
FROM
  public.profiles p
LEFT JOIN
  public.help_requests hr ON hr.mentor_id = p.id
WHERE
  p.role = 'mentor' AND p.registration_status = 'aprobado'
GROUP BY
  p.id, p.full_name;

-- 1.9 Realtime para help_requests
ALTER TABLE public.help_requests REPLICA IDENTITY FULL;
