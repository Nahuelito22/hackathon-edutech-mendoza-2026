# Plan de Implementación: Épica 16 - Sistema de Mentoría Aleatoria y Tickets SOS

Este documento detalla la arquitectura y los pasos técnicos para implementar la asignación justa de mentores y el sistema de pedidos de ayuda (SOS) en tiempo real para el evento HEM2026.

## 1. Lógica de Servidor (Base de Datos y RPC)

### 1.1 Nueva Tabla: `help_requests` (Tickets SOS)

Se creará una tabla para rastrear las solicitudes de ayuda con sus respectivos tiempos.

```sql
CREATE TABLE IF NOT EXISTS public.help_requests (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    team_id UUID NOT NULL REFERENCES public.teams(id) ON DELETE CASCADE,
    mentor_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    status TEXT NOT NULL CHECK (status IN ('pendiente', 'en_camino', 'finalizado')) DEFAULT 'pendiente',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    started_at TIMESTAMP WITH TIME ZONE,
    finished_at TIMESTAMP WITH TIME ZONE
);

-- Índices para búsquedas eficientes
CREATE INDEX idx_help_requests_team ON public.help_requests(team_id);
CREATE INDEX idx_help_requests_mentor ON public.help_requests(mentor_id);
CREATE INDEX idx_help_requests_status ON public.help_requests(status);
```

### 1.2 Políticas RLS (Security) para `help_requests`

- **Participantes (Teams):** Solo el líder o miembros del equipo pueden crear tickets, pero únicamente si están asignados a su propio `mentor_id`. Pueden leer sus propios tickets.
- **Mentores:** Pueden leer los tickets donde ellos son el `mentor_id`. Pueden actualizar el `status` (a 'en_camino' o 'finalizado').
- **Admins:** Tienen acceso total para métricas y monitoreo.

### 1.3 Modificación en la tabla `teams` (Opcional si no existe)
Asumimos que `teams` ya tiene o necesitará una columna `mentor_id`:
```sql
ALTER TABLE public.teams ADD COLUMN IF NOT EXISTS mentor_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL;
```

### 1.4 Función RPC: `assign_mentors_randomly()`

Esta función PostgreSQL se encargará de asignar de forma equitativa los equipos a los mentores aprobados.

```sql
CREATE OR REPLACE FUNCTION assign_mentors_randomly(reset_current BOOLEAN DEFAULT false)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    mentor_record RECORD;
    team_record RECORD;
    mentors_array UUID[];
    mentor_count INT;
    i INT := 1;
BEGIN
    -- 1. Si se pide resetear, poner todos los mentor_id de teams en NULL
    IF reset_current THEN
        UPDATE public.teams SET mentor_id = NULL;
    END IF;

    -- 2. Obtener la lista de mentores aprobados
    SELECT array_agg(id) INTO mentors_array
    FROM public.profiles
    WHERE role = 'mentor' AND registration_status = 'aprobado';

    mentor_count := array_length(mentors_array, 1);

    IF mentor_count IS NULL OR mentor_count = 0 THEN
        RAISE EXCEPTION 'No hay mentores aprobados disponibles.';
    END IF;

    -- Mezclar los mentores aleatoriamente (Shuffle)
    SELECT array_agg(val) INTO mentors_array
    FROM (SELECT unnest(mentors_array) AS val ORDER BY random()) s;

    -- 3. Asignar mentores a los equipos que no tienen mentor
    FOR team_record IN SELECT id FROM public.teams WHERE mentor_id IS NULL ORDER BY random()
    LOOP
        UPDATE public.teams
        SET mentor_id = mentors_array[i]
        WHERE id = team_record.id;

        -- Rotar al siguiente mentor para mantener la distribución equitativa (Round-Robin)
        i := i + 1;
        IF i > mentor_count THEN
            i := 1;
        END IF;
    END LOOP;
END;
$$;
```

---

## 2. Configuración y Tiempo de Sesión

Insertar las nuevas claves en `event_config`:

```sql
INSERT INTO public.event_config (key, value)
VALUES 
  ('help_enabled', 'false'), -- Habilita o deshabilita los SOS a nivel general
  ('mentor_session_duration', '15') -- Tiempo en minutos por defecto
ON CONFLICT (key) DO NOTHING;
```

---

## 3. Frontend - Panel de Administración (`/admin/index.astro`)

### 3.1 Pestaña "Configuración" (Actualización)
- Se añade el switch para **Activar/Desactivar Pedidos SOS** (bindeado a `help_enabled`).
- Se añade un input numérico para cambiar el `mentor_session_duration` en minutos.

### 3.2 Nueva Sección o Pestaña "Mentoría"
- Un botón "🎲 Asignar Mentores (Solo Nuevos)" y un botón rojo "⚠️ Resetear y Reasignar Todos". Estos botones ejecutarán el RPC `assign_mentors_randomly(false/true)`.
- **Métricas:** Consultas simples a `help_requests` para mostrar cuántos tickets están 'pendientes', 'en_camino' y el promedio general de respuesta.

---

## 4. Frontend - Dashboard del Mentor (`/mentor.astro` o panel compartido)

- **Cola de Ayuda (Help Queue):** Un contenedor que se actualiza en tiempo real usando Supabase Realtime (escuchando inserts/updates en `help_requests` donde `mentor_id = current_user`).
- **Tarjeta de Ticket:** Muestra el nombre del equipo, proyecto, y estado.
- **Acciones:**
  - Botón "Voy en Camino" -> Pasa el estado a `en_camino` y guarda el `started_at = NOW()`.
  - Botón "Finalizar Ayuda" -> Pasa el estado a `finalizado` y guarda `finished_at = NOW()`.
- **Cronómetro:** Cuando el ticket está 'en_camino', se calcula el `(started_at + mentor_session_duration) - NOW()` y se muestra una cuenta regresiva. Si llega a 0, se pinta en rojo para alertar que el tiempo se excedió.

---

## 5. Frontend - Dashboard del Participante (`/dashboard`)

- **Información del Mentor:** Si el equipo ya tiene un `mentor_id`, obtener los datos del mentor desde `profiles` y mostrarlos en el frontend.
- **Botón "Pedir Ayuda (SOS)":**
  - Condición de deshabilitado: 
    - Si `help_enabled == 'false'`.
    - Si el equipo ya tiene un ticket en estado `pendiente` o `en_camino`.
- **Notificación de Estado:** Una vez pedido el SOS, el equipo verá en vivo si el estado del ticket cambió a "en_camino" para que sepan que su mentor está yendo hacia ellos.

---

### Preguntas Abiertas para Validación
1. ¿Las métricas de mentores estarán en una nueva pestaña "Mentoría" o dentro de "Resultados" / "Configuración"?
2. ¿Los mentores tendrán una vista exclusiva `/mentoria.astro` o se reutilizará algún panel existente para la cola de ayuda?
