# ÉPICA 13 — Módulo de Entrega de Proyectos

**Objetivo**: Permitir que los equipos conformados envíen su solución tecnológica final durante el evento, controlado por un switch administrativo, y utilizando la tabla `projects` existente.

## Tareas a Ejecutar

### 1. Base de Datos (Supabase)
- [x] Insertar nueva clave en `event_config`: `project_submission_enabled` (boolean, default false).
- [x] Configurar políticas RLS en la tabla `projects`: 
  - Solo permitir `INSERT`/`UPDATE` si el `team_id` coincide con el del equipo del usuario actual.
  - Administradores y jueces pueden leer todos los proyectos.
- [x] Agregar restricción `UNIQUE` en la columna `team_id` de la tabla `projects` (1 proyecto por equipo máximo).
- [x] Crear el archivo de migración `.sql`.
- [x] **Commit:** `feat: [db] configure projects table RLS and project_submission_enabled flag`

### 2. Panel de Administración (`/admin/index.astro`)
- [ ] Leer el valor de `project_submission_enabled` de la base de datos vía SSR.
- [ ] Añadir un nuevo Switch Toggle: "Recepción de Proyectos: Activa/Inactiva".
- [ ] Implementar la lógica cliente (JS) para hacer un `UPDATE` a `event_config` al cambiar el switch.
- [ ] **Commit:** `feat: [admin] add project_submission_enabled toggle switch`

### 3. Frontend: Componente de Entrega (`src/components/ProjectSubmission.astro`)
- [ ] Crear el archivo `ProjectSubmission.astro`.
- [ ] Si `project_submission_enabled` es `false`: Mostrar tarjeta/candado indicando "La entrega de proyectos se habilitará el día del evento".
- [ ] Si `project_submission_enabled` es `true`: Mostrar formulario utilizando los campos existentes:
  - Título del Proyecto (`title`)
  - Descripción del Problema (`description_problem`)
  - Descripción de la Solución (`description_solution`)
  - Enlace al Prototipo (`url_prototype`)
  - Enlace a Material de Apoyo (Opcional) (`url_support_material`)
- [ ] Renderizar el componente dentro del Dashboard, solo visible cuando el usuario pertenece a un equipo.
- [ ] **Commit:** `feat: [dashboard] create ProjectSubmission component UI`

### 4. Lógica de Cliente y UX
- [ ] En el formulario, si el usuario NO es el `leader_id`, bloquear todos los inputs (modo `readonly`) y ocultar/deshabilitar el botón de enviar.
- [ ] Al hacer submit (solo líder), realizar un `UPSERT` en la tabla `projects` asociando el `team_id`.
- [ ] Mostrar Toast de confirmación de éxito o de error.
- [ ] Al montar el componente, cargar los datos previos del proyecto (si existen) para permitir edición.
- [ ] **Commit:** `feat: [logic] project submission bound to team leader and upsert`

### 5. Verificación y Testing
- [ ] Validar que un líder pueda enviar y editar el proyecto.
- [ ] Validar que un integrante no-líder solo pueda visualizar los datos cargados por el líder.
- [ ] Validar el apagado del switch desde el panel de admin.
- [ ] **Commit:** `fix: [projects] resolve issues after e2e test`
