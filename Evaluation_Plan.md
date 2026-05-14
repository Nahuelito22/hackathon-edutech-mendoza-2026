# Plan Arquitectónico — ÉPICA 14: Módulo de Evaluación y Panel de Jurados

Este documento detalla la arquitectura de base de datos, seguridad y frontend propuesta para el sistema de evaluación de proyectos en la Hackathon EduTech Mendoza 2026.

## 1. Estructura de Base de Datos (Supabase)

### Tabla: `evaluations`
Almacenará las calificaciones individuales que cada juez otorga a cada proyecto.

| Columna | Tipo | Restricciones / Detalles |
| :--- | :--- | :--- |
| `id` | `uuid` | Primary Key, `gen_random_uuid()` |
| `project_id` | `uuid` | `REFERENCES projects(id) ON DELETE CASCADE` |
| `judge_id` | `uuid` | `REFERENCES profiles(id) ON DELETE CASCADE` |
| `score_innovation` | `smallint` | `CHECK (score_innovation BETWEEN 1 AND 10)` |
| `score_viability` | `smallint` | `CHECK (score_viability BETWEEN 1 AND 10)` |
| `score_ux` | `smallint` | `CHECK (score_ux BETWEEN 1 AND 10)` |
| `score_pitch` | `smallint` | `CHECK (score_pitch BETWEEN 1 AND 10)` |
| `feedback` | `text` | Opcional. Comentarios adicionales para el equipo. |
| `created_at` | `timestamptz` | `now()` |
| `updated_at` | `timestamptz` | `now()` |

**Restricciones de Tabla:**
- `UNIQUE(project_id, judge_id)`: Un juez solo puede evaluar una vez a un mismo proyecto.

### Políticas de Seguridad (RLS) en `evaluations`
- **Lectura (SELECT):** 
  - Jueces: Solo pueden ver sus propias evaluaciones (`judge_id = auth.uid()`).
  - Admins/Superadmins: Pueden ver TODAS las evaluaciones para calcular los ganadores.
- **Inserción/Actualización (INSERT/UPDATE):**
  - Solo los jueces (`role = 'juez'`) pueden insertar/actualizar.
  - La clave de configuración `evaluation_enabled` debe estar en `true` para permitir el guardado.

---

## 2. Configuración Administrativa (Switch)

En la tabla `event_config`, insertaremos una nueva clave:
- `key`: `'evaluation_enabled'`
- `value`: `{"enabled": false}` (o `false` si usamos booleanos directos).

Desde el panel `/admin`, se agregará un nuevo switch tipo Toggle ("Recepción de Evaluaciones"). Esto controlará si los jueces pueden enviar los formularios o si el módulo aparece "Cerrado".

---

## 3. Panel del Jurado (Ruta y UI)

**Recomendación de Ruta:**
Se recomienda crear una ruta dedicada **`/dashboard/juez`** o simplemente **`/evaluacion`**.
*¿Por qué?* El `/dashboard` actual está muy enfocado en la "Gestión de Equipo" y "Entrega de Proyecto" (vista de participantes). Inyectar toda la UI de evaluación mediante condicionales ensuciaría el código de `/dashboard/index.astro`. Al tener una ruta dedicada:
1. El código es modular.
2. Un middleware o lógica SSR puede redirigir automáticamente a los usuarios con `role === 'juez'` a esta página en vez del dashboard normal.

**Flujo de Usuario (UI Juez):**
1. **Vista principal:** Grilla/Lista de proyectos entregados.
2. **Estado:** Muestra si el proyecto ya fue evaluado por él (marcado con check) o está pendiente.
3. **Formulario Modal/Expansible:** Al hacer clic en un proyecto, se abren los sliders/inputs numéricos para los criterios (Innovación, Viabilidad, UX, Pitch) y el área de Feedback. Si `evaluation_enabled` es falso, el formulario será de solo lectura.

---

## 4. Tabla de Posiciones (Leaderboard para Admins)

**Recomendación de Cálculo:**
**Mediante una Vista en Postgres (Database View)**.
Realizar este cálculo en el frontend requeriría enviar todas las evaluaciones a la red y que Javascript las agrupe y sume, lo cual es ineficiente y propenso a errores.

**Propuesta de SQL View (`project_leaderboard`):**
Crear una vista (o RPC) que calcule automáticamente:
- El puntaje total por categoría.
- El promedio general.
- La cantidad de jueces que han evaluado el proyecto.

```sql
CREATE OR REPLACE VIEW project_leaderboard AS
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
    projects p
LEFT JOIN 
    teams t ON p.team_id = t.id
LEFT JOIN 
    evaluations e ON p.id = e.project_id
GROUP BY 
    p.id, p.title, t.name
ORDER BY 
    final_score DESC;
```

De esta manera, en `/admin`, simplemente hacemos `SELECT * FROM project_leaderboard` y renderizamos la tabla ordenadamente en milisegundos.

---

## Próximos Pasos (Hoja de Ruta Épica 14)

Si este plan es aprobado, procederemos con las siguientes tareas atómicas:
1. Crear la migración SQL (`evaluations` table, RLS, `event_config`, y `project_leaderboard` view).
2. Agregar el switch de evaluación en el panel `/admin`.
3. Crear la página `/evaluacion` y el componente de formulario de rúbricas para el Juez.
4. Mostrar la tabla Leaderboard en la vista de Admin utilizando la nueva base de datos.
