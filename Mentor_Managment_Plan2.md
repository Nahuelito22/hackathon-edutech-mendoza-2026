# Plan de Implementación v2 — ÉPICA 16: Sistema de Mentoría Aleatoria y Tickets SOS

Este documento detalla la arquitectura completa, los pasos técnicos y las consideraciones de seguridad para implementar la asignación justa de mentores y el sistema de pedidos de ayuda (SOS) en tiempo real para el evento HEM2026.

Reemplaza y mejora al anterior `Mentor_Management_Plan.md`, corrigiendo problemas de seguridad, añadiendo validaciones del lado del servidor, y definiendo las rutas y componentes concretos.

---

## Convenciones de este documento

- Cada tarea atómica tiene un checkbox `[ ]` que se marca `[x]` al completar.
- **Regla de commits:** Se realiza un **commit por cada tarea completada** y un **commit adicional al finalizar toda la épica** con mensaje `feat(epic16): sistema de mentoría y tickets SOS completo`.
- Los mensajes de commit por tarea siguen el formato: `feat(epic16): descripción breve de la tarea`.
- Todas las tareas que involucren SQL deben empaquetarse en una **migración formal** dentro de `supabase/migrations/` con timestamp.

---

## 0. Resumen de Decisiones Arquitectónicas

| Decisión | Resolución | Justificación |
|----------|------------|---------------|
| ¿Dónde mostrar métricas de mentores? | **Pestaña "Mentoría" nueva** en `/admin` | Las métricas son operativas del evento, no configuración. Mezclarlas diluye la UX. |
| ¿Ruta dedicada para mentores? | **`/mentoria`** dedicado | Consistente con `/evaluacion` para jueces. Los mentores no necesitan ver el dashboard de participantes. |
| ¿INSERT directo en `help_requests`? | **No — usar RPC `request_help()`** | Evita inyección de `mentor_id` desde el cliente. El servidor obtiene el mentor del equipo. |
| ¿UPDATE directo en `help_requests`? | **No — usar RPC `mentor_update_ticket()`** | Valida que el caller sea el mentor asignado y que las transiciones de estado sean válidas. |
| ¿`ON DELETE CASCADE` en `help_requests.mentor_id`? | **`ON DELETE SET NULL`** | Preserva datos históricos de métricas al eliminar un perfil de mentor. |
| ¿Constraint para 1 ticket activo por equipo? | **Sí — UNIQUE parcial** | No confiar solo en el frontend. La BD debe garantizar la regla. |
| ¿Qué pasa si un mentor se da de baja? | **Alerta en Admin + reasignación manual** | No hay reasignación automática (podría romper sesiones en curso), pero el admin ve equipos huérfanos. |

---

## 1. Base de Datos — Migración SQL

### 1.1 Tabla `help_requests` (Tickets SOS)

```sql
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
```

**Cambios respecto al plan v1:**

| Aspecto | v1 | v2 | Motivo |
|---------|----|----|--------|
| `mentor_id` | `NOT NULL` + `ON DELETE CASCADE` | `NULLABLE` + `ON DELETE SET NULL` | Preservar métricas históricas si se elimina un perfil |
| Estado `expirado` | No existía | Agregado | Tickets "zombie" (pendientes que nunca se atendieron) |
| UNIQUE parcial | No existía | Agregado | Garantizar 1 ticket activo por equipo en la BD, no solo en frontend |

### 1.2 Columna `mentor_id` en `teams`

```sql
ALTER TABLE public.teams
  ADD COLUMN IF NOT EXISTS mentor_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL;
```

Se usa `ON DELETE SET NULL` para que, si se elimina un perfil de mentor, el equipo quede huérfano pero no se elimine el equipo.

### 1.3 Políticas RLS para `help_requests`

```sql
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

-- Nota: No hay políticas INSERT/UPDATE directas.
-- Toda escritura pasa por RPCs (request_help y mentor_update_ticket).
-- Esto evita que el cliente inyecte mentor_id o cambie estados inválidos.
```

**Por qué no hay RLS de INSERT/UPDATE:** Las operaciones de escritura se encapsulan en RPCs `SECURITY DEFINER` que hacen las validaciones internamente. Esto es más seguro que permitir INSERT directo donde un cliente malicioso podría enviar cualquier `mentor_id`.

### 1.4 Claves en `event_config`

```sql
INSERT INTO public.event_config (key, value, description) VALUES
  ('help_enabled',             'false', 'Habilita o deshabilita los pedidos SOS a nivel general'),
  ('mentor_session_duration',  '15',    'Tiempo en minutos por defecto para cada sesión de mentoría'),
  ('help_cooldown_minutes',    '5',     'Cooldown en minutos entre pedidos SOS del mismo equipo')
ON CONFLICT (key) DO NOTHING;
```

**Nuevo respecto a v1:** `help_cooldown_minutes` evita que un equipo pida ayuda inmediatamente después de cerrarse un ticket.

### 1.5 RPC: `request_help()`

Crea un ticket SOS. Obtiene el `mentor_id` del equipo internamente (no del cliente). Valida que `help_enabled` esté activo, que no haya tickets activos, y que el equipo tenga un mentor asignado.

```sql
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

  -- 3. Verificar que no haya un ticket activo (el UNIQUE index ya lo protege, pero damos mensaje claro)
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
```

### 1.6 RPC: `mentor_update_ticket()`

Permite al mentor cambiar el estado de un ticket. Valida transiciones de estado válidas y que el caller sea el mentor asignado.

```sql
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
  -- pendiente -> en_camino
  -- en_camino -> finalizado
  -- pendiente -> finalizado (cancelación directa)
  -- Cualquier otra transición es inválida
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
```

### 1.7 RPC: `assign_mentors_randomly()`

Asigna mentores aprobados a equipos sin mentor usando round-robin. Retorna un JSON con el resultado en vez de lanzar excepciones.

```sql
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
```

**Cambios respecto al plan v1:**

| Aspecto | v1 | v2 | Motivo |
|---------|----|----|--------|
| Manejo de error | `RAISE EXCEPTION` | Retorna JSON con `{ok: false}` | No aborta la transacción; el frontend recibe un mensaje amigable |
| Verificación de permisos | No existía | Chequea `role IN ('admin', 'superadmin')` | Seguridad: cualquier usuario autenticado podía llamar al RPC |
| Orden de equipos | `ORDER BY random()` | Sin ORDER BY | El shuffle de mentores ya garantiza aleatoriedad; ordenar equipos no tiene efecto en la distribución final round-robin |
| Retorno | `RETURNS void` | `RETURNS JSON` con métricas | El admin necesita feedback de cuántos equipos fueron actualizados |

### 1.8 Vista: `mentor_help_stats`

Agrega estadísticas de mentoría para el panel de admin, similar a `project_leaderboard`.

```sql
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
```

### 1.9 Realtime para `help_requests`

```sql
ALTER TABLE public.help_requests REPLICA IDENTITY FULL;
```

Necesario para que Supabase Realtime envíe los campos completos del registro en los eventos INSERT/UPDATE, permitiendo que el mentor y el equipo vean los cambios en tiempo real.

---

## 2. Middleware — Ruteo por Rol

### 2.1 Modificaciones en `src/middleware.ts`

Se debe agregar `/mentoria` como ruta protegida exclusiva para mentores, siguiendo el mismo patrón que `/evaluacion` para jueces.

```
Constantes nuevas:
  MENTOR_ROUTES = ['/mentoria']

Lógica nueva:
  - Si el usuario es mentor y accede a /dashboard → redirigir a /mentoria
  - Si el usuario NO es mentor y accede a /mentoria → redirigir a /dashboard
  - Admins/superadmins también pueden acceder a /mentoria (para debugging)
  - Si el usuario es mentor y accede a /login o /registro → redirigir a /mentoria

Agregar '/mentoria' al array PROTECTED_ROUTES
```

**Comportamiento completo de rutas por rol (resumen actualizado):**

| Rol | `/dashboard` | `/mentoria` | `/evaluacion` | `/admin` |
|-----|-------------|-------------|---------------|----------|
| `usuario` | Acceso | Redirige a `/dashboard` | Redirige a `/dashboard` | Redirige a `/dashboard` |
| `mentor` | Redirige a `/mentoria` | Acceso | Redirige a `/mentoria` | Redirige a `/mentoria` |
| `juez` | Redirige a `/evaluacion` | Redirige a `/evaluacion` | Acceso | Redirige a `/evaluacion` |
| `admin` | Acceso | Acceso | Acceso | Acceso |
| `superadmin` | Acceso | Acceso | Acceso | Acceso |

---

## 3. Frontend — Panel de Administración (`/admin/index.astro`)

### 3.1 Pestaña "Configuración" — Actualización

Añadir al grid de configuración existente:

- **Toggle: "Pedidos de Ayuda SOS"** — bindeado a `help_enabled` (siguiendo el patrón de `teams_enabled`, `evaluation_enabled`, etc.).
- **Input numérico: "Duración de Sesión (min)"** — bindeado a `mentor_session_duration`. Tipo `number`, min=5, max=60, step=5.
- **Input numérico: "Cooldown entre SOS (min)"** — bindeado a `help_cooldown_minutes`. Tipo `number`, min=0, max=30, step=1.

El server-side del admin debe hacer `.in('key', [...existing_keys, 'help_enabled', 'mentor_session_duration', 'help_cooldown_minutes'])` para obtener los valores al renderizar.

### 3.2 Nueva Pestaña "Mentoría"

Se agrega un cuarto botón de tab: `<button class="tab-btn" data-target="tab-mentoria">Mentoría</button>`

Contenido de la pestaña:

**Sección: Asignación de Mentores**

- Botón primario: "Asignar Mentores (Solo Nuevos)" → ejecuta `assign_mentors_randomly(false)`.
- Botón danger: "Resetear y Reasignar Todos" → requiere confirmación (dialog o doble click) → ejecuta `assign_mentors_randomly(true)`.
- Ambos botones muestran el resultado JSON del RPC en un toast.

**Sección: Equipos sin Mentor (Alerta)**

- Query: `SELECT id, name FROM teams WHERE mentor_id IS NULL`.
- Si hay equipos sin mentor, mostrar una alerta visual (card con borde warning) listando los nombres.
- Esto permite al admin detectar equipos huérfanos y reaccionar.

**Sección: Métricas de Mentoría**

- Query: `SELECT * FROM mentor_help_stats ORDER BY total_tickets DESC`.
- Tabla con columnas: Mentor, Equipos Asignados, Tickets Total, Pendientes, En Camino, Finalizados, Expirados, Prom. Respuesta (min), Prom. Sesión (min).
- Botón "Actualizar Métricas" para recargar.
- Seguir el mismo patrón de tabla responsive que usa la pestaña "Resultados" (mobile → card layout).

---

## 4. Frontend — Dashboard del Mentor (`/mentoria`)

### 4.1 Nueva Página: `src/pages/mentoria.astro`

Ruta dedicada exclusiva para mentores. Protegida por middleware (solo `mentor`, `admin`, `superadmin`).

**Estructura de la página:**

```
┌─────────────────────────────────────────────┐
│  Header: "Panel de Mentoría"                │
│  Subtítulo: "Gestioná tus pedidos de ayuda" │
├─────────────────────────────────────────────┤
│  [Cola de Ayuda]                            │
│                                             │
│  ┌─ Ticket Card ────────────────────────┐   │
│  │ Equipo: "Los Pioneros"               │   │
│  │ Proyecto: "EduApp"                   │   │
│  │ Estado: 🟡 Pendiente                 │   │
│  │ Tiempo esperando: 3 min              │   │
│  │                                      │   │
│  │ [Voy en Camino]  [Finalizar Ayuda]   │   │
│  └──────────────────────────────────────┘   │
│                                             │
│  ┌─ Ticket Card (En Camino) ────────────┐   │
│  │ Equipo: "Tech Force"                 │   │
│  │ Estado: 🔵 En Camino                 │   │
│  │ ⏱ Cronómetro: 08:32 restantes        │   │
│  │ (Se pinta rojo si llega a 0)         │   │
│  │                                      │   │
│  │ [Finalizar Ayuda]                    │   │
│  └──────────────────────────────────────┘   │
│                                             │
│  ─── Historial ───                         │
│  ┌─ Ticket Finalizado ─────────────────┐   │
│  │ Equipo: "Code Breakers"             │   │
│  │ Estado: ✅ Finalizado               │   │
│  │ Duración: 12 min                    │   │
│  └──────────────────────────────────────┘   │
└─────────────────────────────────────────────┘
```

**Server-side:**

- Verificar que el usuario tenga rol `mentor` (o `admin`/`superadmin`).
- Obtener `mentor_session_duration` desde `event_config`.
- Obtener tickets del mentor: `SELECT hr.*, t.name as team_name FROM help_requests hr JOIN teams t ON hr.team_id = t.id WHERE hr.mentor_id = $userId ORDER BY hr.created_at DESC`.
- Pasar datos al template como props.

**Client-side (script):**

1. **Realtime Subscription:**
   - Suscribirse a `postgres_changes` en `help_requests` con filtro `mentor_id = eq.${userId}`.
   - En evento INSERT: agregar tarjeta al tope de la cola con animación fadeInUp.
   - En evento UPDATE: actualizar la tarjeta existente (cambiar estado, timestamps, botones disponibles).

2. **Acciones del Mentor:**
   - Botón "Voy en Camino" → llama `mentor_update_ticket(ticketId, 'en_camino')`. Si ok, la UI se actualiza (muestra cronómetro). Si error, toast.
   - Botón "Finalizar Ayuda" → llama `mentor_update_ticket(ticketId, 'finalizado')`. Si ok, la tarjeta se mueve al historial. Si error, toast.

3. **Cronómetro:**
   - Cuando un ticket pasa a `en_camino`, se calcula: `tiempoRestante = (started_at + mentor_session_duration * 60000) - Date.now()`.
   - Se actualiza cada segundo con `setInterval`.
   - Si `tiempoRestante <= 0`, se pinta en rojo (fondo, borde, texto) para alertar tiempo excedido.
   - El cronómetro se limpia cuando el ticket pasa a `finalizado`.

4. **Notificación sonora/vibratoria:**
   - En evento INSERT de nuevo ticket, reproducir un beep corto (`new Audio('data:audio/wav;base64,...')`) si el navegador lo permite.
   - Cambiar el `document.title` a "(1) Panel de Mentoría | HEM2026" como indicador visual.

5. **Estilos:**
   - Seguir el design system de `global.css` (variables CSS, clases `.card`, `.btn`, `.btn-primary`, `.btn-outline`).
   - Cards con borde lateral de color según estado: `pendiente` = amarillo, `en_camino` = azul (`--c1`), `finalizado` = verde (`--c2`), `expirado` = rojo.
   - Responsive: en mobile, las cards se apilan verticalmente.

---

## 5. Frontend — Dashboard del Participante (`/dashboard`)

### 5.1 Integración en `src/pages/dashboard/index.astro`

Se agrega dentro de la vista "Perfil Completo" (después del `TeamManager`), solo si el usuario está en un equipo y `help_enabled` es true.

**Datos necesarios del server-side:**

- Obtener `help_enabled`, `mentor_session_duration` desde `event_config`.
- Si el usuario tiene `team_id`, obtener el mentor: `SELECT p.full_name, p.institution, p.phone_whatsapp FROM profiles p JOIN teams t ON t.mentor_id = p.id WHERE t.id = $teamId`.

**Componente: Información del Mentor (inline en dashboard)**

```
┌─ Tu Mentor ─────────────────────────┐
│ 👤 Nombre: Dra. María López         │
│ 🏫 Institución: IES Edison          │
│ 📱 WhatsApp: 2611234567             │
└─────────────────────────────────────┘
```

Mostrar solo si el equipo tiene `mentor_id` asignado. Si no, mostrar mensaje: "Tu mentor será asignado pronto por la organización."

**Componente: Botón SOS (inline en dashboard)**

```
┌─ ¿Necesitás ayuda? ────────────────┐
│                                     │
│  [🆘 Pedir Ayuda (SOS)]            │
│  Estado: 🟡 Pendiente — Esperando  │
│  al mentor...                       │
│                                     │
└─────────────────────────────────────┘
```

**Lógica del botón SOS:**

- **Deshabilitado si:**
  - `help_enabled` es `false`.
  - El equipo ya tiene un ticket activo (`pendiente` o `en_camino`).
  - El equipo no tiene `mentor_id` asignado.
  - Está en cooldown (validado server-side en el RPC).
- **Al hacer clic:** Llama al RPC `request_help()`. Si ok, muestra estado pendiente. Si error, toast con el mensaje.
- **Realtime:** Suscribirse a `postgres_changes` en `help_requests` con filtro `team_id = eq.${teamId}`.
  - Si el ticket cambia a `en_camino` → actualizar la UI para mostrar "🔵 Tu mentor está en camino".
  - Si el ticket cambia a `finalizado` → mostrar mensaje de finalización y rehabilitar el botón (sujeto a cooldown).

**Estado visual del SOS (se actualiza en tiempo real):**

| Estado del Ticket | Visualización |
|-------------------|---------------|
| Sin ticket | Botón habilitado "Pedir Ayuda (SOS)" |
| `pendiente` | Botón deshabilitado + texto "🟡 Esperando al mentor..." + tiempo transcurrido |
| `en_camino` | Botón deshabilitado + texto "🔵 ¡Tu mentor está en camino!" + cronómetro regresivo |
| `finalizado` | Mensaje "✅ Sesión finalizada" → luego de cooldown, botón se rehabilita |

### 5.2 Prop adicionales para `TeamManager.astro`

El componente `TeamManager` ya recibe props como `userId`, `teamId`, etc. Se deben agregar:

- `mentorId: string | null` — para saber si el equipo tiene mentor.
- `helpEnabled: boolean` — para controlar la visibilidad del botón SOS.
- `mentorSessionDuration: number` — para el cronómetro.

Estas props se pasan desde `dashboard/index.astro` que ya obtiene `event_config`.

---

## 6. Edge Function — Expiración de Tickets (Opcional pero Recomendado)

### 6.1 Función: `expire-stale-help-requests`

Una Supabase Edge Function (Deno) que corre periódicamente (cron o invocación manual) y marca como `expirado` los tickets `pendiente` que superen un tiempo límite (ej: 30 minutos sin respuesta).

```typescript
// supabase/functions/expire-stale-help-requests/index.ts
// Lógica: UPDATE help_requests SET status = 'expirado'
// WHERE status = 'pendiente' AND created_at < now() - interval '30 minutes'
```

Esto evita tickets "zombie" donde el mentor nunca respondió y el equipo quedó bloqueado.

**Nota:** Si no se implementa la Edge Function, el UNIQUE index parcial seguirá protegiendo contra duplicados, pero los tickets quedarán en estado `pendiente` para siempre. El admin puede marcarlos manualmente como `finalizado` desde el panel.

---

## 7. Checklist de Implementación — Tareas Atómicas

### Fase 1: Base de Datos

- [x] **T1.1** — Crear migración `supabase/migrations/<timestamp>_epic16_mentorship_schema.sql` con: tabla `help_requests`, UNIQUE index parcial, columna `mentor_id` en `teams`, todas las políticas RLS, claves `event_config`, vista `mentor_help_stats`, `REPLICA IDENTITY FULL`.
- [x] **T1.2** — Crear migración `supabase/migrations/<timestamp>_epic16_mentorship_rpcs.sql` con: RPCs `request_help()`, `mentor_update_ticket()`, `assign_mentors_randomly()`.
- [x] **T1.3** — Ejecutar ambas migraciones en Supabase local/cloud y verificar que no hay errores.

> **Commit después de T1.3:** `feat(epic16): esquema de base de datos y RPCs para mentoría`

### Fase 2: Middleware

- [x] **T2.1** — Modificar `src/middleware.ts`: agregar `MENTOR_ROUTES = ['/mentoria']`, agregar `/mentoria` a `PROTECTED_ROUTES`, agregar lógica de redirección para mentores (mentor → `/mentoria`, no-mentor → `/dashboard`), agregar lógica para auth routes (mentor logueado → `/mentoria`).

> **Commit después de T2.1:** `feat(epic16): ruteo de mentor en middleware`

### Fase 3: Panel de Administración

- [x] **T3.1** — Agregar toggle "Pedidos de Ayuda SOS" en pestaña "Configuración" de `/admin/index.astro` (seguir patrón de `teams-enabled-toggle`). Incluir inputs numéricos para `mentor_session_duration` y `help_cooldown_minutes`.
- [x] **T3.2** — Agregar pestaña "Mentoría" en `/admin/index.astro`: botones de asignación de mentores (con confirmación para reset), sección de equipos sin mentor, tabla de métricas desde `mentor_help_stats`.
- [x] **T3.3** — Agregar server-side queries: `help_enabled`, `mentor_session_duration`, `help_cooldown_minutes` en frontmatter, y query de `mentor_help_stats`.
- [x] **T3.4** — Agregar client-side JS: handlers para toggles de help, inputs de duración/cooldown, botones de asignación (con toast de resultado), y botón de actualizar métricas.

> **Commit después de T3.4:** `feat(epic16): pestaña mentoría en panel de administración`

### Fase 4: Dashboard del Mentor

- [ ] **T4.1** — Crear `src/pages/mentoria.astro`: layout base con header, sección de cola de ayuda, sección de historial.
- [ ] **T4.2** — Implementar server-side: verificación de rol, obtener `mentor_session_duration`, obtener tickets del mentor con JOIN a `teams`.
- [ ] **T4.3** — Implementar client-side: renderizado de tickets por estado, botones de acción (llamando RPCs), actualización de UI en tiempo real con Supabase Realtime.
- [ ] **T4.4** — Implementar cronómetro: cuenta regresiva cuando ticket está `en_camino`, pintar rojo al excederse, limpiar intervalos.
- [ ] **T4.5** — Implementar notificación: beep sonoro en nuevo ticket, indicador en `document.title`.
- [ ] **T4.6** — Agregar estilos: cards con borde lateral por estado, responsive, animaciones de entrada.

> **Commit después de T4.6:** `feat(epic16): dashboard de mentor con cola de ayuda en tiempo real`

### Fase 5: Dashboard del Participante

- [ ] **T5.1** — Modificar `src/pages/dashboard/index.astro`: agregar server-side queries para `help_enabled`, `mentor_session_duration`, y datos del mentor asignado.
- [ ] **T5.2** — Agregar sección "Tu Mentor" en la vista de perfil completo (datos del mentor o mensaje de "aún no asignado").
- [ ] **T5.3** — Agregar sección "Pedir Ayuda (SOS)" con botón que llama al RPC `request_help()`, estados visuales según estado del ticket, y actualización en tiempo real con Supabase Realtime.
- [ ] **T5.4** — Pasar props adicionales a `TeamManager` si es necesario (mentorId, helpEnabled) para coordinar visibilidad.

> **Commit después de T5.4:** `feat(epic16): botón SOS y datos de mentor en dashboard de participante`

### Fase 6: Edge Function (Opcional)

- [ ] **T6.1** — Crear `supabase/functions/expire-stale-help-requests/index.ts` con lógica de expiración de tickets pendientes > 30 min.
- [ ] **T6.2** — Configurar cron trigger o documentar invocación manual.

> **Commit después de T6.2:** `feat(epic16): edge function para expirar tickets pendientes`

### Fase 7: Verificación Final

- [ ] **T7.1** — Testing manual end-to-end: crear equipo, asignar mentor, pedir SOS, aceptar ticket, finalizar ticket, verificar Realtime, verificar métricas en admin, verificar cooldown.
- [ ] **T7.2** — Verificar que el middleware redirige correctamente por rol.
- [ ] **T7.3** — Verificar responsive en mobile (dashboard mentor, dashboard participante, admin).
- [ ] **T7.4** — Verificar dark mode (todos los componentes nuevos usan variables CSS del design system).

> **Commit final de épica:** `feat(epic16): sistema de mentoría y tickets SOS completo`

---

## 8. Diagrama de Flujo — Pedido de Ayuda SOS

```
Participante                    Supabase (RPC)                    Mentor
    │                               │                               │
    │  request_help()               │                               │
    │──────────────────────────────►│                               │
    │                               │  Valida: help_enabled         │
    │                               │  Valida: equipo tiene mentor  │
    │                               │  Valida: sin ticket activo    │
    │                               │  Valida: cooldown             │
    │                               │                               │
    │                               │  INSERT help_requests         │
    │                               │  (mentor_id = del equipo)     │
    │                               │                               │
    │  {ok: true, ticket_id}        │   ── Realtime INSERT ──►      │
    │◄──────────────────────────────│                               │
    │                               │                       [Card aparece]
    │  [UI: "Esperando al mentor"]  │                               │
    │                               │                               │
    │                               │    mentor_update_ticket()     │
    │                               │◄──────────────────────────────│
    │                               │  Valida: caller = mentor_id   │
    │                               │  Valida: pendiente → en_camino│
    │                               │                               │
    │                               │  UPDATE status='en_camino'    │
    │                               │  UPDATE started_at = now()    │
    │                               │                               │
    │   ── Realtime UPDATE ──►      │                               │
    │                       [UI: "¡Mentor en camino!"]              │
    │                               │                       [Cronómetro inicia]
    │                               │                               │
    │                               │    mentor_update_ticket()     │
    │                               │◄──────────────────────────────│
    │                               │  Valida: en_camino → finalizado│
    │                               │                               │
    │                               │  UPDATE status='finalizado'   │
    │                               │  UPDATE finished_at = now()   │
    │                               │                               │
    │   ── Realtime UPDATE ──►      │                               │
    │                       [UI: "Sesión finalizada"]       [Card → Historial]
    │                               │                               │
    │  [Cooldown activo]            │                               │
    │  [Botón se rehabilita tras    │                               │
    │   help_cooldown_minutes]      │                               │
```

---

## 9. Diagrama de Flujo — Asignación de Mentores

```
Admin                           Supabase (RPC)                       BD
  │                                  │                                │
  │  assign_mentors_randomly(false)  │                                │
  │─────────────────────────────────►│                                │
  │                                  │  Valida: caller es admin       │
  │                                  │                                │
  │                                  │  SELECT mentores aprobados     │
  │                                  │───────────────────────────────►│
  │                                  │◄───────────────────────────────│
  │                                  │                                │
  │                                  │  Shuffle mentores              │
  │                                  │                                │
  │                                  │  SELECT equipos sin mentor     │
  │                                  │───────────────────────────────►│
  │                                  │◄───────────────────────────────│
  │                                  │                                │
  │                                  │  UPDATE teams (round-robin)    │
  │                                  │───────────────────────────────►│
  │                                  │                                │
  │  {ok: true, teams_updated: 12,   │                                │
  │   mentors_used: 4}              │                                │
  │◄─────────────────────────────────│                                │
  │                                  │                                │
  │  [Toast: "12 equipos asignados   │                                │
  │   a 4 mentores"]                 │                                │
```

---

## 10. Consideraciones de Seguridad — Resumen

| Riesgo | Mitigación |
|--------|------------|
| Inyección de `mentor_id` desde el cliente | No hay INSERT directo; `request_help()` obtiene el mentor del equipo internamente |
| Transiciones de estado inválidas | `mentor_update_ticket()` valida `pendiente → en_camino → finalizado` |
| Múltiples tickets activos por equipo | UNIQUE index parcial en BD + validación en RPC |
| Usuario no-mentor llamando a `assign_mentors_randomly` | Validación de rol admin/superadmin dentro del RPC |
| Eliminación de mentor con tickets activos | `ON DELETE SET NULL` preserva tickets; admin ve equipos huérfanos |
| Tickets pendientes sin atención | Estado `expirado` + Edge Function (o admin manual) |
| Abuso de SOS (spam de pedidos) | `help_cooldown_minutes` configurable por admin |
| Mentor viendo tickets de otros mentores | RLS: solo puede ver tickets donde `mentor_id = auth.uid()` |
| Participante viendo tickets de otros equipos | RLS: solo puede ver tickets de su propio equipo (`get_my_team_id()`) |

---

## 11. Dependencias y Requisitos Previos

Antes de implementar la Épica 16, verificar:

- [ ] La tabla `teams` existe y tiene la estructura esperada (id, name, join_code, leader_id).
- [ ] La tabla `profiles` tiene el rol `mentor` en el enum `user_role`.
- [ ] La función `get_my_team_id()` existe y funciona (migración epic 12/13).
- [ ] La función `get_user_role()` existe y funciona (usada en RLS de evaluations).
- [ ] Supabase Realtime está habilitado para las tablas necesarias (ya está para `profiles`).
- [ ] El middleware actual maneja correctamente los roles existentes.

---

## 12. Notas para el Agente de Implementación

1. **No modificar archivos que no sean los especificados en cada tarea.** Cada tarea es atómica y no debe tener efectos colaterales fuera de su scope.
2. **Seguir el patrón existente.** Mirar cómo está implementado `/evaluacion` para jueces como referencia de cómo hacer `/mentoria` para mentores. Mirar cómo están los toggles en `/admin` para agregar los nuevos.
3. **Usar las variables CSS del design system.** Todos los colores, bordes, sombras, radios y tipografías deben usar las variables definidas en `src/styles/global.css`. No hardcodear valores.
4. **No agregar Tailwind, React, Vue ni Svelte.** El proyecto usa Astro puro con vanilla CSS y JS en `<script>` tags. Mantener esta convención.
5. **Los commits se hacen por tarea completada.** Si una tarea requiere tocar 2 archivos, ambos van en el mismo commit. Si una tarea es solo SQL, el commit es solo la migración.
6. **El commit final de la épica se hace solo después de que todas las tareas estén marcadas `[x]`.** No antes.
7. **Probar en dark mode.** Todos los componentes nuevos deben verse correctamente en ambos temas (`brand-light` y `brand-dark`).
8. **Probar en mobile.** Los componentes deben ser responsive. Seguir el patrón de tablas responsive del admin (mobile → card layout).
9. **No hardcodear el `mentor_id` en el frontend.** Siempre usar el RPC `request_help()` que lo obtiene del servidor.
10. **Todos los strings de error en español** (consistente con el resto del proyecto).
