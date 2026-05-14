# Gestión de Equipos — ÉPICA 12: Sistema de Equipos y Lógica de Competencia

> **Objetivo:** Permitir que los participantes aprobados formen equipos de forma autónoma bajo reglas estrictas de negocio, controlados por un switch administrativo.
>
> **Documento de referencia obligatorio para cada tarea:**
> - [`GEMINI.md`](./GEMINI.md) — Contexto del proyecto, stack y estructura
> - [`GIT_GUIDELINES.md`](./GIT_GUIDELINES.md) — Convención de commits, ramas y PRs
> - [`BEST_PRACTICES.md`](./BEST_PRACTICES.md) — Estándares de calidad, testing y seguridad

---

## Reglas Generales de Ejecución

1. **Cada tarea completada = 1 commit atómico** siguiendo la convención de `GIT_GUIDELINES.md`
2. **Prefijos de commit:** `feat:`, `fix:`, `refactor:`, `style:`, `docs:` según corresponda
3. **Idioma de código:** inglés (variables, funciones, componentes, commits)
4. **Idioma de UI:** español (textos visibles al usuario)
5. **Testear en local** (`npm run dev`) antes de cada commit, como indica `BEST_PRACTICES.md`
6. **RLS obligatorio** en toda tabla nueva o modificada, como indica `BEST_PRACTICES.md` §4
7. **No romper la estética de marca** — Respetar la paleta (Fucsia `--c1`, Lima `--c2`) y tipografía (Lexend)

---

## Estado Actual de la Base de Datos

### ✅ Lo que YA existe

| Recurso | Detalle |
|---|---|
| Tabla `teams` | `id`, `name`, `is_finalist`, `final_position`, `created_at`, `updated_at` |
| Columna `profiles.team_id` | FK a `teams.id`, nullable |
| `event_config` | Claves: `max_team_size=5`, `min_team_size=3`, `max_egresados_per_team=1` |
| RLS `teams` | Policies: `admin_all`, `superadmin_all`, `judge_select`, `mentor_select`, `user_select_own_team`, `user_update_own_team` |
| RLS `profiles` | Policies: CRUD por rol, `user_select_own`, `user_update_own` |
| Funciones helper | `get_user_role()`, `get_user_team_id()` |
| Tipo en `env.d.ts` | `UserProfile` ya tiene `team_id: string | null` |

### ❌ Lo que FALTA

| Recurso | Acción |
|---|---|
| `teams.join_code` | Agregar columna `TEXT UNIQUE` (6 caracteres alfanuméricos) |
| `teams.leader_id` | Agregar columna FK a `profiles.id` |
| `event_config.teams_enabled` | Insertar nueva clave (`false` por defecto) |
| Policy INSERT en `teams` | Los usuarios no pueden crear equipos actualmente |
| RPCs transaccionales | `create_team()`, `join_team()`, `leave_team()` |
| Realtime | Agregar `teams` y `profiles` a publicación `supabase_realtime` |

---

## Decisiones de Diseño

| Decisión | Resolución |
|---|---|
| ¿Quién puede crear/unirse? | Solo usuarios con `registration_status = 'aprobado'` |
| ¿Si el líder abandona? | El equipo se **disuelve** y todos quedan sin equipo |
| ¿Modelo de unión? | Solo por **código privado** (sin listado público de equipos) |
| ¿Lógica de validación dónde? | **RPCs de Postgres** (`SECURITY DEFINER`) para transacciones atómicas y prevenir race conditions |

---

## ÉPICA 12.1 — Migración de Base de Datos

> **Scope:** Preparar el esquema SQL, funciones RPC y configuración de Realtime.
> Todas las migraciones se ejecutan en Supabase.

### Tarea 12.1.1 — Agregar columnas faltantes a `teams`

- [x] Ejecutar migración SQL para agregar `join_code` (`TEXT UNIQUE`) y `leader_id` (`UUID FK → profiles.id`) a la tabla `teams`
- [x] Verificar con `SELECT * FROM teams LIMIT 1` que las columnas existen
- [ ] **Commit:** `feat: [db] add join_code and leader_id columns to teams table`

```sql
ALTER TABLE public.teams 
  ADD COLUMN IF NOT EXISTS join_code TEXT UNIQUE,
  ADD COLUMN IF NOT EXISTS leader_id UUID REFERENCES public.profiles(id);
```

---

### Tarea 12.1.2 — Insertar clave `teams_enabled` en `event_config`

- [x] Insertar la clave `teams_enabled` con valor `false` y descripción clara
- [x] Verificar con `SELECT * FROM event_config WHERE key = 'teams_enabled'`
- [ ] **Commit:** `feat: [db] add teams_enabled flag to event_config`

```sql
INSERT INTO public.event_config (key, value, description) 
VALUES ('teams_enabled', 'false', 'Habilita la sección de gestión de equipos en el Dashboard del participante')
ON CONFLICT (key) DO NOTHING;
```

---

### Tarea 12.1.3 — Habilitar Realtime para `teams` y `profiles`

- [x] Agregar ambas tablas a la publicación `supabase_realtime`
- [x] Verificar con `SELECT * FROM pg_publication_tables WHERE pubname = 'supabase_realtime'`
- [ ] **Commit:** `feat: [db] enable realtime for teams and profiles tables`

```sql
ALTER PUBLICATION supabase_realtime ADD TABLE public.teams;
ALTER PUBLICATION supabase_realtime ADD TABLE public.profiles;
```

---

### Tarea 12.1.4 — Crear RPC `create_team`

- [x] Crear función `public.create_team(p_team_name TEXT)` con `SECURITY DEFINER`
- [x] Validaciones internas:
  - [x] `teams_enabled` está activo
  - [x] Usuario tiene `registration_status = 'aprobado'`
  - [x] Usuario no pertenece a otro equipo (`team_id IS NULL`)
  - [x] Generar `join_code` único de 6 caracteres (loop + `md5(random())`)
  - [x] Insertar en `teams`, asignar `leader_id` y actualizar `profiles.team_id`
- [x] Retorna JSON: `{ ok, team_id, join_code, team_name }` o `{ ok, error }`
- [ ] Testear llamando `SELECT public.create_team('Mi Equipo');` como usuario aprobado
- [ ] **Commit:** `feat: [db] add create_team RPC with business validations`

---

### Tarea 12.1.5 — Crear RPC `join_team`

- [x] Crear función `public.join_team(p_join_code TEXT)` con `SECURITY DEFINER`
- [x] Validaciones internas:
  - [x] `teams_enabled` está activo
  - [x] Usuario tiene `registration_status = 'aprobado'`
  - [x] Usuario no pertenece a otro equipo
  - [x] Código existe en `teams.join_code`
  - [x] Equipo no ha alcanzado `max_team_size` (leído de `event_config`)
  - [x] Si usuario `is_egresado`, el equipo no supera `max_egresados_per_team`
- [x] Retorna JSON: `{ ok, team_name, team_id }` o `{ ok, error }`
- [ ] Testear escenarios: código válido, código inválido, equipo lleno, egresado duplicado
- [ ] **Commit:** `feat: [db] add join_team RPC with egresado and size validation`

---

### Tarea 12.1.6 — Crear RPC `leave_team`

- [x] Crear función `public.leave_team()` con `SECURITY DEFINER`
- [x] Lógica:
  - [x] Si el usuario es líder (`leader_id = auth.uid()`): disolver equipo completo (SET `team_id = NULL` para todos, DELETE equipo)
  - [x] Si el usuario es miembro: solo actualizar su `profiles.team_id = NULL`
- [x] Retorna JSON: `{ ok, dissolved, message }` o `{ ok, error }`
- [ ] Testear ambos escenarios (líder y miembro)
- [ ] **Commit:** `feat: [db] add leave_team RPC with leader dissolution logic`

---

### Tarea 12.1.7 — Agregar policy INSERT para usuarios en `teams`

- [x] Crear policy que permita a usuarios aprobados sin equipo insertar en `teams`
- [x] Ampliar policy SELECT para que usuarios vean todos los equipos (necesario para validar código)
- [x] Verificar con `SELECT * FROM pg_policies WHERE tablename = 'teams'`
- [x] **Bonus:** Revocar acceso `anon` a las RPCs (fix de seguridad detectado por advisor)
- [ ] **Commit:** `feat: [db] add INSERT RLS policy for approved users on teams`

```sql
CREATE POLICY "approved_user_insert_teams" ON public.teams
  FOR INSERT TO public
  WITH CHECK (
    get_user_role() = 'usuario'::user_role
    AND (SELECT registration_status FROM public.profiles WHERE id = auth.uid()) = 'aprobado'
    AND (SELECT team_id FROM public.profiles WHERE id = auth.uid()) IS NULL
  );

DROP POLICY IF EXISTS "user_select_own_team" ON public.teams;
CREATE POLICY "user_select_teams" ON public.teams
  FOR SELECT TO public
  USING (get_user_role() = 'usuario'::user_role);
```

---

## ÉPICA 12.2 — Componente Frontend: TeamManager

> **Scope:** Crear el componente visual y su lógica client-side para gestionar equipos desde el Dashboard.
> Seguir la estética de marca definida en `GEMINI.md` y los estándares de `BEST_PRACTICES.md`.

### Tarea 12.2.1 — Crear componente `TeamManager.astro`

- [x] Crear archivo `src/components/TeamManager.astro`
- [x] Recibe props: `userId`, `teamId`, `isEgresado`, `fullName`
- [x] Implementar **3 estados visuales**:

```
Estado A — Sin equipo:
┌──────────────┐  ┌──────────────────────────┐
│ Crear Equipo │  │ Unirse con Código: [___] │
│ Nombre: [__] │  │         [Unirse →]       │
│ [Crear →]    │  └──────────────────────────┘
└──────────────┘

Estado B — En equipo (líder):
┌───────────────────────────────────────────┐
│ 🏆 Mi Equipo: "Los Innovadores"          │
│ Código: ABC123 [📋 Copiar]               │
│ ── Integrantes (3/5) ──                  │
│ • Juan Pérez (Líder) ⭐                  │
│ • María López                             │
│ • Carlos Díaz (Egresado)                  │
│ [⚠ Disolver Equipo]                      │
└───────────────────────────────────────────┘

Estado C — En equipo (miembro):
│ (Igual que B pero botón "Abandonar")     │
```

- [x] Llamadas a RPCs: `supabase.rpc('create_team', ...)`, `supabase.rpc('join_team', ...)`, `supabase.rpc('leave_team')`
- [x] Mostrar feedback con mensajes de error/éxito estilizados
- [x] Botón "Copiar código" con `navigator.clipboard.writeText()`
- [x] Mostrar badge "Egresado" junto a integrantes que lo sean
- [x] Mostrar contador de integrantes vs máximo (ej: `3/5`)
- [x] Confirmar antes de disolver/abandonar con `confirm()`
- [x] Estilos scoped respetando variables CSS de la marca
- [x] Testear en local: crear equipo, copiar código, validar estados
- [x] **Commit:** `feat: [dashboard] add TeamManager component with create/join/leave logic`

---

### Tarea 12.2.2 — Integrar Realtime en `TeamManager`

- [ ] Suscribirse a `postgres_changes` en tabla `profiles` filtrando por `team_id`
- [ ] Al detectar cambio: refrescar la lista de integrantes sin recargar la página
- [ ] Manejar `unsubscribe` al desmontar el componente
- [ ] Testear con 2 navegadores: unirse en uno, ver actualización en el otro
- [ ] **Commit:** `feat: [dashboard] add realtime subscription for team member updates`

```typescript
const channel = supabase
  .channel('team-updates')
  .on('postgres_changes', {
    event: '*',
    schema: 'public',
    table: 'profiles',
    filter: `team_id=eq.${currentTeamId}`
  }, (payload) => {
    refreshTeamMembers();
  })
  .subscribe();
```

---

## ÉPICA 12.3 — Integración en Dashboard y Panel Admin

> **Scope:** Conectar el componente con las páginas existentes y agregar el control administrativo.

### Tarea 12.3.1 — Dashboard de Participantes (`src/pages/dashboard/index.astro`)

- [x] Importar e instanciar `<TeamManager />` dentro del bloque de "Perfil Completo".
- [x] Leer `event_config` desde el servidor (Astro.locals o supabase server client).
  - [x] Extraer `teams_enabled`
  - [x] Extraer `max_team_size` y `min_team_size`
- [x] **Lógica de Renderizado:**
  - [x] Si `teams_enabled == false`: Mostrar mensaje "La formación de equipos se habilitará próximamente" + Candado.
  - [x] Si `teams_enabled == true` Y `registration_status == 'aprobado'`: Mostrar `<TeamManager />`.
  - [x] Si `registration_status == 'pendiente'`: Mostrar mensaje "Esperá a que la administración apruebe tu perfil..." + Candado.
- [x] **Commit:** `feat: [dashboard] integrate TeamManager based on event_config and registration status`, `fullName={profile.full_name}`
- [x] Ubicar debajo de la tarjeta de perfil existente, dentro del `success-layout`
- [x] Testear: con `teams_enabled=false` no aparece, con `true` sí
- [x] **Commit:** `feat: [dashboard] conditionally render TeamManager based on teams_enabled flag`

---

### Tarea 12.3.2 — Agregar toggle de `teams_enabled` en `admin/index.astro`

- [ ] En el frontmatter SSR: leer el valor actual de `teams_enabled` desde `event_config`
- [ ] En la zona de `admin-actions`: agregar un toggle switch estilizado con label "Formación de equipos"
- [ ] Al hacer click: actualizar `event_config` via Supabase (`UPDATE ... SET value = 'true'/'false'`)
- [ ] Feedback visual: toast de confirmación + cambio de estado del switch
- [ ] Estilos del toggle respetando la paleta de marca
- [ ] Testear: activar → ir al dashboard → verificar que aparece el componente
- [ ] **Commit:** `feat: [admin] add teams_enabled toggle switch to admin panel`

---

## ÉPICA 12.4 — Verificación y Documentación

> **Scope:** Validación end-to-end del flujo completo y actualización de documentación.

### Tarea 12.4.1 — Test End-to-End del flujo completo

- [ ] **Test 1 — Crear equipo:** Usuario aprobado crea equipo → genera código → aparece como líder
- [ ] **Test 2 — Unirse por código:** Segundo usuario usa el código → aparece en la lista de integrantes
- [ ] **Test 3 — Regla de egresados:** Segundo egresado intenta unirse → mensaje de error claro
- [ ] **Test 4 — Límite de tamaño:** Llenar equipo a 5 → sexto usuario recibe error
- [ ] **Test 5 — Abandonar (miembro):** Miembro regular abandona → queda sin equipo, equipo sigue
- [ ] **Test 6 — Disolver (líder):** Líder abandona → todos quedan sin equipo, equipo se borra
- [ ] **Test 7 — Switch admin:** Desactivar `teams_enabled` → sección desaparece del dashboard
- [ ] **Test 8 — Realtime:** Abrir 2 navegadores, unirse en uno → aparece en el otro sin refresh
- [ ] **Commit (si hay fixes):** `fix: [teams] resolve issues found during e2e testing`

---

### Tarea 12.4.2 — Validación SQL de integridad

- [ ] Ejecutar queries de verificación:

```sql
-- No hay equipos con más miembros de los permitidos
SELECT t.name, COUNT(p.id) as members 
FROM teams t LEFT JOIN profiles p ON p.team_id = t.id 
GROUP BY t.id HAVING COUNT(p.id) > 5;

-- No hay equipos con más egresados de los permitidos
SELECT t.name, COUNT(p.id) as egresados 
FROM teams t JOIN profiles p ON p.team_id = t.id AND p.is_egresado = true 
GROUP BY t.id HAVING COUNT(p.id) > 1;

-- Todos los líderes pertenecen a su propio equipo
SELECT t.name, t.leader_id, p.team_id 
FROM teams t JOIN profiles p ON p.id = t.leader_id 
WHERE p.team_id != t.id OR p.team_id IS NULL;
```

- [ ] Verificar que las 3 consultas retornan **0 filas**
- [ ] **Commit:** `docs: [teams] add SQL integrity validation queries`

---

### Tarea 12.4.3 — Actualizar documentación

- [ ] Actualizar `README.md` con la nueva funcionalidad de equipos
- [ ] Marcar esta épica como completada en este archivo
- [ ] **Commit:** `docs: [readme] update documentation with team management feature`

---

## Riesgos y Mitigaciones

| Riesgo | Probabilidad | Impacto | Mitigación |
|---|---|---|---|
| Race condition: 2 egresados se unen simultáneamente | Media | Alto | RPCs `SECURITY DEFINER` con transacciones atómicas |
| Usuario manipula cliente para saltear validaciones | Baja | Alto | Toda lógica crítica en funciones Postgres, no en el frontend |
| Código de equipo predecible | Muy Baja | Medio | 6 chars alfanuméricos = 2.176M combinaciones + validación de unicidad |
| Líder abandona y hay proyecto vinculado | Media | Alto | Bloquear disolución si existe `project` vinculado (Fase futura) |
| Realtime no se activa correctamente | Media | Bajo | Fallback: botón manual "Refrescar equipo" |

---

## Archivos Afectados (Resumen)

| Archivo | Acción | Épica |
|---|---|---|
| Supabase: tabla `teams` | MODIFY (add columns) | 12.1.1 |
| Supabase: tabla `event_config` | INSERT (nueva clave) | 12.1.2 |
| Supabase: publicación Realtime | MODIFY | 12.1.3 |
| Supabase: RPC `create_team` | NEW | 12.1.4 |
| Supabase: RPC `join_team` | NEW | 12.1.5 |
| Supabase: RPC `leave_team` | NEW | 12.1.6 |
| Supabase: RLS policies `teams` | MODIFY | 12.1.7 |
| `src/components/TeamManager.astro` | NEW | 12.2.1 |
| `src/pages/dashboard/index.astro` | MODIFY | 12.3.1 |
| `src/pages/admin/index.astro` | MODIFY | 12.3.2 |

---

*Documento creado para el proyecto HEM2026 — Hackathon EduTech Mendoza 2026*
*Última actualización: 2026-05-14*
