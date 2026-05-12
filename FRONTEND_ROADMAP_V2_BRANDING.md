# FRONTEND ROADMAP V2 — Adaptación a Identidad de Marca Oficial

> **Documento generado a partir del análisis de:**
> - `Brief_Marca_HackathonEduTech2026-v02.pdf` (8 págs.)
> - `Marca y manual de normas_rev02-_HackathonEduTech2026_.pdf` (20 págs.)
> - `Manual de normas_PARA IMPRESION._HackathonEduTech2026_.pdf` (10 págs.)
> - Assets en `/LOGOS_FONDO_TRANSPARENTE-_HackathonEduTech2026_/` (5 archivos PNG)

---

## 1. RESUMEN DE AUDITORÍA: Estado Actual vs. Exigencia de Marca

### 1.1 Paleta de Colores

| Aspecto | ❌ Estado Actual (V1) | ✅ Exigencia de Marca |
|---|---|---|
| Color Primario 1 | `#00d4ff` (Cyan neón) | **`#88007b`** (Fucsia/Magenta — Pantone 2415 C) |
| Color Primario 2 | `#00ff88` (Verde neón) | **`#9fc637`** (Verde lima — Pantone 2292 C) |
| Color Primario 3 | `#ff6b35` (Naranja neón) | **`#000000`** (Negro — soporte tipográfico) |
| Color de Fondo Claro | No definido formalmente | **`#eae7ea`** (Gris rosado — Pantone 9345 C) |
| Filosofía cromática | Hacker/gamer, colores de alta saturación sin control | Fusión educación + tecnología. **Fucsia** = energía y modernidad. **Verde lima** = innovación y frescura. |

**Equivalencias RGB oficiales** (del manual pág. 20):
- **Fucsia**: R136 G0 B123 → `#88007b`
- **Verde Lima**: R159 G198 B55 → `#9fc637`
- **Gris claro**: R234 G231 B234 → `#eae7ea`
- **Negro**: R34 G34 B32 → `#222220` (negro de marca, no puro)

### 1.2 Tipografía

| Aspecto | ❌ Estado Actual (V1) | ✅ Exigencia de Marca |
|---|---|---|
| Display / Títulos | `Bebas Neue` (condensada, estilo racing) | **`Lexend Black`** (logotipo) |
| Headings | `Syne` (geométrica, sci-fi) | **`Lexend Regular`** (bajadas y destacados) |
| Body | `Lora` (serif literaria) | **`Lexend Extra Light`** (textos generales) |
| Mono | `DM Mono` | No especificada — puede mantenerse para código/datos |
| Nº Familias | 4 familias distintas | **1 sola familia: Lexend** (3 pesos) |

> **Nota:** Lexend está disponible en [Google Fonts](https://fonts.google.com/specimen/Lexend). Es una fuente diseñada específicamente para **máxima legibilidad en pantalla**, lo que se alinea con el requisito del brief.

### 1.3 Naming Oficial

| Aspecto | ❌ Estado Actual (V1) | ✅ Exigencia de Marca |
|---|---|---|
| Título en Hero | `EDUTECH` (solo la parte tech) | **`HACKATHON EDUTECH`** (nombre completo, siempre junto) |
| Subtítulo | "Hackathon de Nivel Superior Mendoza 2026" | **`2026 — Segunda Edición`** (grafía oficial: "Segunda Edición", no "2da") |
| Logo | SVG genérico inventado | **Isologo oficial**: Foco + He + trama de hormigas |

> ⚠️ **Regla inamovible del brief (sec. 4.2):** *"El nombre siempre aparece en su totalidad. 'EduTech' puede tener tratamiento tipográfico diferenciado dentro del conjunto, pero no se separa ni se reemplaza."*

### 1.4 Tono Visual — Qué Evitar

El brief (sec. 4.4) establece explícitamente:

| ✗ EVITAR | Nuestro estado actual |
|---|---|
| Estética de startup tecnológica genérica | ⚠️ Parcialmente — los iconos/badges genéricos aplican |
| Diseño institucional / ministerial frío | ✅ No aplica |
| Lúdico infantil / escolar primario | ✅ No aplica |
| **Oscuro/neón tipo gaming extremo** | **❌ INCUMPLIMIENTO TOTAL — `cyber-dark` con cyan/verde neón** |
| Cualquier cosa que intimide o excluya | ⚠️ El tono "hacker" puede intimidar a perfiles pedagógicos |

### 1.5 Metáfora Visual: Hormigas + Foco

La propuesta ganadora usa una **doble metáfora**:
1. **Comunidad de hormigas** → Colaboración sistémica, superorganismo, cada individuo aporta al colectivo
2. **Foco / bombilla** → La "solución" al desafío, la iluminación como resultado del trabajo colaborativo

Esto se materializa en:
- **Isotipo**: Un foco que contiene las letras `He` (Hackathon EduTech), rodeado por una **trama modular de hormigas** estilizadas (los nodos interconectados)
- **Trama/patrón**: Los nodos conectados con forma de hormiga se usan como textura decorativa

### 1.6 Sistema de Temas — Decisión Requerida

| Aspecto | Situación |
|---|---|
| Temas actuales | 3 temas: `cyber-dark`, `eco-light`, `high-contrast` |
| Temas de marca | Solo se definen 4 fondos: blanco, fucsia, verde, negro |
| **Propuesta** | **2 temas:** Un modo **Claro** (fondo `#eae7ea` / blanco) y un modo **Oscuro** (fondo negro/gris oscuro con acentos fucsia/verde). El tercero se elimina para simplificar. |

> **⚠️ DECISIÓN DEL USUARIO REQUERIDA**: ¿Mantenemos 2 temas (claro/oscuro) o solo 1 tema claro fiel al manual? El manual muestra el logo en fondos claros, fucsia, verde y negro — no define un "modo oscuro web" per se.

---

## 2. HOJA DE RUTA DE REFACTORIZACIÓN (Épicas y Tareas)

---

### ÉPICA 1: Tipografía y CSS Global (`global.css`)

#### Tarea 1.1 — Reemplazar Google Fonts
- [x] **Archivo**: `src/layouts/Layout.astro`
- **Acciones**:
  1. Eliminar el `<link>` actual que carga Bebas Neue, DM Mono, Lora y Syne
  2. Reemplazar con el `<link>` de Google Fonts para **Lexend** con pesos: 200 (Extra Light), 400 (Regular), 900 (Black)
  3. Opcionalmente mantener DM Mono para datos técnicos (countdown, horarios, tags)

#### Tarea 1.2 — Actualizar variables tipográficas en `:root`
- [x] **Archivo**: `src/styles/global.css`
- **Acciones**:
  1. Cambiar `--font-display` de `'Bebas Neue'` a `'Lexend', sans-serif` (peso Black 900)
  2. Cambiar `--font-heading` de `'Syne'` a `'Lexend', sans-serif` (peso Regular 400)
  3. Cambiar `--font-body` de `'Lora'` a `'Lexend', sans-serif` (peso Extra Light 200)
  4. Mantener `--font-mono` como `'DM Mono'` o evaluar eliminarlo
  5. Ajustar `font-weight` en cada componente que use estas variables

#### Tarea 1.3 — Reemplazar paleta de colores en los temas
- [x] **Archivo**: `src/styles/global.css`
- **Acciones**:
  1. Redefinir tema **claro** (renombrar `eco-light` → `brand-light` o similar):
     - `--c1: #88007b` (fucsia) | `--c1r: 136,0,123`
     - `--c2: #9fc637` (verde lima) | `--c2r: 159,198,55`
     - `--c3: #222220` (negro de marca) | `--c3r: 34,34,32`
     - `--bg-1: #ffffff` | `--bg-2: #eae7ea` | `--bg-3: #f5f3f5`
     - `--txt-1: #222220` | `--txt-2: #555555`
  2. Redefinir tema **oscuro** (renombrar `cyber-dark` → `brand-dark`):
     - Mismos `--c1`, `--c2` pero sobre fondos oscuros
     - `--bg-1: #1a1a1a` | `--bg-2: #242424` | `--bg-card: #2a2a2a`
     - `--txt-1: #eae7ea` | `--txt-2: #9a9a9a`
  3. **Eliminar** el tema `high-contrast` (simplificar a 2 temas)
  4. Actualizar el tema por defecto en el `<script is:inline>` de Layout.astro

#### Tarea 1.4 — Actualizar ThemeToggle
- [x] **Archivo**: `src/components/ThemeToggle.astro`
- **Acciones**:
  1. Reducir opciones de 3 a 2 (claro / oscuro)
  2. Cambiar nombres y colores de los swatches del menú
  3. Actualizar lógica de `localStorage` con nuevos nombres de tema
  4. Actualizar el tema fallback en `Layout.astro` (`brand-light` como default)

---

### ÉPICA 2: Logos y Assets

#### Tarea 2.1 — Integrar logos oficiales al proyecto
- [x] **Archivos**: `public/` o `src/assets/`
- **Acciones**:
  1. Copiar los 5 PNGs de `/LOGOS_FONDO_TRANSPARENTE-_HackathonEduTech2026_/` a `public/img/brand/`
  2. Optimizar con herramienta de compresión si necesario
  3. Considerar crear una versión SVG del isologo simplificado para el navbar (mejor rendimiento)

#### Tarea 2.2 — Reemplazar logo SVG del Navbar
- [x] **Archivo**: `src/components/Navbar.astro`
- **Acciones**:
  1. Eliminar el SVG inline genérico actual (el rectángulo con líneas)
  2. Reemplazar por la imagen del isologo oficial (`MARCA_SIMPLE_NEGRO_SIN_FONDO.png` en tema claro, versión blanca/invertida para tema oscuro)
  3. Actualizar texto: de `Edu<span>Tech</span> / Mendoza 2026` a la grafía oficial completa
  4. Aplicar tipografía Lexend Black para "HACKATHON EDUTECH", Lexend Regular para "Segunda Edición"

#### Tarea 2.3 — Reemplazar logo SVG del Footer
- [x] **Archivo**: `src/components/Footer.astro`
- **Acciones**:
  1. Misma lógica que Navbar — reemplazar SVG inline por imagen oficial
  2. Actualizar textos de marca con naming correcto

#### Tarea 2.4 — Crear favicon desde isotipo
- [x] **Archivo**: `public/favicon.svg` o `public/favicon.ico`
- **Acciones**:
  1. Crear un favicon a partir del isotipo del foco (la "He" dentro del foco)
  2. Generar versiones 16×16, 32×32, 192×192 (para PWA)

---

### ÉPICA 3: Rediseño del Hero Section

#### Tarea 3.1 — Reestructurar contenido del Hero
- [x] **Archivo**: `src/components/Hero.astro`
- **Acciones**:
  1. Reemplazar título `EDUTECH` por estructura completa:
     - "HACKATHON" (Lexend Extra Light, grande)
     - "EDUTECH" (Lexend Black, grande, color `--c1` fucsia)
  2. Cambiar subtítulo a: "Segunda Edición — Mendoza 2026"
  3. Integrar el isologo oficial (foco + trama) como elemento visual del hero
  4. Actualizar el badge de "2da Edición — Mendoza, Argentina"

#### Tarea 3.2 — Reemplazar fondo animado
- [x] **Archivo**: `src/components/Hero.astro` (CSS + JS)
- **Acciones**:
  1. Eliminar las shapes geométricas flotantes actuales (círculos con border neón)
  2. Reemplazar por un fondo sutil con la **trama de hormigas** (el patrón modular del manual) como textura de fondo con baja opacidad
  3. Ajustar gradientes del hero de cyan/verde neón → fucsia/verde lima suaves
  4. Evaluar si las partículas CSS se mantienen (pueden funcionar como "hormigas" abstractas con los nuevos colores)

#### Tarea 3.3 — Actualizar botón CTA y countdown
- [x] **Archivo**: `src/components/Hero.astro` (CSS)
- **Acciones**:
  1. Cambiar `btnGlow` de cyan → fucsia (`--c1`)
  2. Verificar que el countdown use Lexend + colores de marca
  3. Ajustar date-chips a los nuevos colores

---

### ÉPICA 4: Actualización de Secciones Interiores

#### Tarea 4.1 — InfoCards
- [ ] **Archivo**: `src/components/InfoCards.astro`
- **Acciones**:
  1. Actualizar colores de acentos (iconos, bordes hover) a fucsia/verde
  2. Verificar que la tipografía se adapta correctamente con Lexend

#### Tarea 4.2 — Schedule (Cronograma)
- [ ] **Archivo**: `src/components/Schedule.astro`
- **Acciones**:
  1. Cambiar el color del timeline dot/border de cyan → fucsia/verde según día
  2. Actualizar tags y colores de acento
  3. Ajustar el fondo sólido de las cards al nuevo tema

#### Tarea 4.3 — FAQ
- [ ] **Archivo**: `src/components/FAQ.astro`
- **Acciones**:
  1. Actualizar color del icono `+` y hover de cyan → fucsia
  2. Verificar legibilidad con nueva tipografía

---

### ÉPICA 5: Limpieza y Verificación Final

#### Tarea 5.1 — Limpieza de código CSS residual
- [ ] **Archivo**: `src/styles/global.css`
- **Acciones**:
  1. Eliminar variables CSS huérfanas (ej. `--gold`, `--silver`, `--bronze` si no se usan)
  2. Eliminar el bloque `[data-theme="high-contrast"]` completo
  3. Eliminar el bloque `[data-theme="cyber-dark"]` completo (reemplazado por `brand-dark`)
  4. Eliminar el bloque `[data-theme="eco-light"]` completo (reemplazado por `brand-light`)
  5. Verificar que no queden referencias a colores hardcodeados (como `#161925` en Schedule.astro)

#### Tarea 5.2 — Verificación responsive y build
- [ ] **Acciones**:
  1. Test visual en 375px, 768px, 1200px+
  2. Test en ambos temas (claro/oscuro)
  3. `npm run build` sin errores
  4. Verificar contraste WCAG AA en textos sobre fondos de marca
  5. Verificar que el isologo se vea correcto en tamaño mínimo (navbar mobile)

#### Tarea 5.3 — Commit y documentación
- [ ] **Acciones**:
  1. Commit con mensaje descriptivo: `refactor: [branding] adaptar frontend a identidad de marca oficial`
  2. Actualizar README si corresponde
  3. Actualizar `FRONTEND_ROADMAP.md` original con nota de que V1 fue superada por V2

---

## 3. NOTAS TÉCNICAS

### Tipografía Lexend — Carga recomendada
```html
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Lexend:wght@200;400;900&display=swap" rel="stylesheet">
```

### Variables CSS recomendadas
```css
:root {
    --font-display: 'Lexend', sans-serif;  /* Black 900 — logotipo/títulos */
    --font-heading: 'Lexend', sans-serif;  /* Regular 400 — subtítulos */
    --font-body: 'Lexend', sans-serif;     /* ExtraLight 200 — cuerpo */
    --font-mono: 'DM Mono', monospace;     /* Mantener para datos técnicos */
}
```

### Paleta de marca resumida
```
Fucsia:     #88007b  (R136 G0 B123)  — Pantone 2415 C
Verde Lima: #9fc637  (R159 G198 B55) — Pantone 2292 C
Gris Claro: #eae7ea  (R234 G231 B234) — Pantone 9345 C
Negro:      #222220  (R34 G34 B32)
```

### Assets de logo disponibles
```
public/img/brand/
├── MARCA_COMPLETA_COLOR_SIN_FONDO.png    (isotipo + texto, a full color)
├── MARCA_COMPLETA_FUCSIA_SIN_FONDO.png   (versión monocroma fucsia)
├── MARCA_COMPLETA_VERDE_SIN_FONDO.png    (versión monocroma verde)
├── MARCA_COMPLETA_NEGRO_SIN_FONDO.png    (versión monocroma negro)
└── MARCA_SIMPLE_NEGRO_SIN_FONDO.png      (versión horizontal simplificada)
```

---

## 4. PREGUNTAS ABIERTAS PARA EL USUARIO

> [!IMPORTANT]
> Antes de ejecutar, necesito tu confirmación en estos puntos:

1. **Temas**: ¿Mantenemos **2 temas** (claro + oscuro con colores de marca) o preferís **solo 1 tema claro** fiel al manual?

2. **Trama de hormigas**: ¿Querés que intente recrear el patrón modular de hormigas como textura CSS/SVG para el fondo del hero, o preferís un fondo más limpio/simple?

3. **Grafía de la edición**: El manual dice "Segunda Edición" pero el brief dice "2da Edición". ¿Cuál preferís para la web?

4. **Fuente mono**: ¿Mantenemos `DM Mono` para el countdown y datos técnicos del cronograma, o usamos Lexend para todo?

5. **Nivel de fidelidad del logo en Navbar**: ¿Usamos la imagen PNG directamente, o preferís que recree el logo como texto estilizado con Lexend (sin el isotipo del foco en el navbar, solo texto)?
