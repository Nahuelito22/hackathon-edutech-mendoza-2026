# FRONTEND_ROADMAP.md — Plan de Migración PoC → Astro

> **Última actualización:** 2026-05-06
>
> Documento de referencia para la migración modular de las Pruebas de Concepto (PoC) en HTML plano hacia la arquitectura Astro del proyecto HEM2026.

---

## Contexto para el Agente

Antes de comenzar cualquier tarea de este roadmap, el agente **debe** leer y respetar los siguientes documentos de contexto del proyecto:

| Documento | Ruta | Propósito |
|-----------|------|-----------|
| **README.md** | `./README.md` | Visión general del proyecto, stack tecnológico, arquitectura de carpetas |
| **BEST_PRACTICES.md** | `./BEST_PRACTICES.md` | Estándares de calidad, convenciones de código (idioma, formato, nombres de archivo) |
| **GEMINI.md** | `./GEMINI.md` | Reglas específicas para el agente de IA, estructura del proyecto, notas de configuración |

### Reglas clave extraídas de los documentos:

- **Idioma del código** (variables, funciones, componentes, clases CSS): **inglés**
- **Idioma de la interfaz** (textos visibles al usuario): **español**
- **Idioma de commits**: **español** (ver sección de flujo de trabajo)
- **Nombres de componentes Astro**: PascalCase (ej: `ThemeToggle.astro`)
- **Nombres de páginas Astro**: kebab-case (ej: `index.astro`)
- **Nombres de estilos**: kebab-case (ej: `global.css`)
- **Framework CSS**: Vanilla CSS con variables `:root` — **NO Tailwind**
- **Framework de UI**: Ninguno — **Vanilla JS** para interactividad
- **TypeScript**: Preferido sobre JavaScript cuando sea posible

---

## Flujo de Trabajo por Tarea

Cada tarea individual del roadmap sigue este ciclo:

```
1. Implementar la tarea atómica
      │
2. Verificar en local con `npm run dev`
      │
3. Revisión visual en navegador (desktop + mobile)
      │
4. Confirmar con el usuario: "Listo para commit"
      │
5. Commit en español con formato descriptivo:
      │   feat: [componente] descripción breve del cambio
      │
6. Esperar confirmación del usuario → "Commit y seguimos"
      │
7. Siguiente tarea
```

> ⚠️ **No se avanza a la siguiente tarea sin confirmación explícita del usuario.**

---

## Archivos Fuente (PoCs)

Los siguientes archivos HTML contienen el código a migrar. Cada uno fue generado por un modelo de IA diferente y tiene un estilo visual distinto:

| Archivo | Ruta | Líneas | Estilo principal | Elementos clave |
|---------|------|--------|-----------------|-----------------|
| **ChatZ** | `PoC/ChatZ/ChatZ.html` | 1730 | Cyber Dark con glassmorphism | Cronograma detallado hora-por-hora (3 días), modal de inscripción, canvas de partículas, toast notifications, scroll reveal con IntersectionObserver |
| **Claude Opus 4.7** | `PoC/Claude_Opus_4.7/Claude_Opus4.7.html` | 492 | Compacto, minimalista | Partículas flotantes, countdown con gradiente, timeline vertical con puntos brillantes, FAQ con `+` rotativo |
| **MimoV2.5** | `PoC/XiaomiMimoV2.5/MimoV2.5.html` | 1070 | Editorial tipográfico (Bebas Neue + Syne + Lora + DM Mono) | Textura grain, grid overlay, formas geométricas animadas (drift), scroll-to-top, formulario inline con radio buttons y campos condicionales |

### Paletas de temas disponibles en las PoC

Las tres PoC comparten la estructura de **3 temas** con `data-theme`:

| Tema | Tipo | Background | Primario | Secundario | Acento |
|------|------|-----------|----------|------------|--------|
| `cyber-dark` | Oscuro | `#08090d` — `#0a0e17` | `#00d4ff` (cyan) | `#00ff88` (verde) | `#ff6b35` (naranja) |
| `eco-light` | Claro | `#fafbf8` — `#ffffff` | `#1a7a42` (verde) | `#1a3a5c` (azul) | `#c49a2a` (dorado) |
| `high-contrast` | Oscuro alto contraste | `#0d1117` — `#0f1629` | `#58a6ff` (azul) | `#3fb950` (verde) | `#d2a8ff` (violeta) |

---

## Estructura de Archivos Objetivo

```
src/
├── pages/
│   └── index.astro              # Página principal — Ensambla todos los componentes
├── layouts/
│   └── Layout.astro             # Layout base — <head>, global CSS, slot
├── components/
│   ├── ThemeToggle.astro         # Selector de tema (3 opciones)
│   ├── Navbar.astro              # Navegación principal + hamburger mobile
│   ├── Footer.astro              # Footer con links, legales, redes sociales
│   ├── Hero.astro                # Hero section + countdown + fondo animado
│   ├── InfoCards.astro           # Sección "Acerca del Hackathon"
│   ├── Schedule.astro            # Cronograma interactivo colapsable
│   └── FAQ.astro                 # Preguntas frecuentes con acordeón
├── styles/
│   └── global.css               # Variables CSS, reset, tipografía, utilidades
└── assets/                      # (reservado para logos, imágenes)
```

---

## Roadmap de Épicas y Tareas

### ÉPICA 1: Core Theming y Layout Base

#### Tarea 1.1 — Variables CSS Globales
- [x] **Archivo**: `src/styles/global.css`
- **Origen**: Variables CSS de `MimoV2.5.html` (líneas 16–76) como base principal, complementadas con `ChatZ.html` (líneas 12–89)
- **Acciones**:
  1. Crear el archivo `src/styles/global.css`
  2. Definir variables de `:root` con design tokens compartidos (fuentes, radios, max-width, transiciones)
  3. Definir 3 bloques `[data-theme="..."]` unificando las paletas:
     - `cyber-dark` → tema por defecto
     - `eco-light` → tema claro
     - `high-contrast` → alto contraste oscuro
  4. Incluir CSS reset (`*, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }`)
  5. Incluir estilos base de `body`, `a`, `img`, headings con transiciones de tema
  6. Incluir utilidades globales: `.container`, `.btn`, `.btn-primary`, `.btn-outline`, `.section-label`, `.section-title`, `.section-desc`
  7. Incluir animaciones reutilizables: `fadeInUp`, `fadeInDown`, `pulse`, scroll reveal (`.reveal` / `.revealed`)
  8. Incluir scrollbar custom y `::selection`
  9. Incluir `@media (prefers-reduced-motion: reduce)` para accesibilidad
- **Fuentes**: Google Fonts — `Syne` (headings), `Lora` (body), `DM Mono` (mono), `Bebas Neue` (display). Tomar de MimoV2.5.
- **Criterio de aceptación**: Al importar el CSS en un HTML básico con `data-theme="cyber-dark"`, los colores, tipografías y utilidades se aplican correctamente.

---

#### Tarea 1.2 — ThemeToggle Component
- [x] **Archivo**: `src/components/ThemeToggle.astro`
- **Origen**: Toggle de `MimoV2.5.html` (líneas 415–443, JS líneas 952–980)
- **Acciones**:
  1. Crear componente Astro con markup del selector (botón flotante + panel de opciones)
  2. Usar SVG inline para el ícono del botón (sol/tema). NO usar Font Awesome.
  3. Tres opciones: Cyber Dark, Eco Light, High Contrast — cada una con preview de color
  4. Migrar la lógica JS al bloque `<script>` del componente:
     - `setTheme(name)` → cambia `data-theme` en `<html>` y guarda en `localStorage`
     - Toggle de visibilidad del panel
     - Click outside para cerrar
     - Restaurar tema guardado al cargar
  5. Incluir estilos `<style>` scoped dentro del componente
  6. Posicionamiento: fixed bottom-right, `z-index: 999`
- **Criterio de aceptación**: Click en el botón abre el panel, seleccionar un tema lo aplica inmediatamente y persiste tras recargar.

---

#### Tarea 1.3 — Layout Base
- [x] **Archivo**: `src/layouts/Layout.astro`
- **Acciones**:
  1. Crear layout con `<html lang="es" data-theme="cyber-dark">`
  2. Configurar `<head>`:
     - `<meta charset="UTF-8">`
     - `<meta name="viewport">`
     - `<meta name="description">` con texto SEO del hackathon
     - `<title>` dinámico vía prop (`Astro.props.title`)
     - Preconnect a Google Fonts
     - Link a Google Fonts (Bebas Neue, Syne, Lora, DM Mono)
     - Import de `../styles/global.css`
  3. `<body>` con `<slot />` para contenido dinámico
  4. Incluir script inline de inicialización de tema (leer `localStorage` y aplicar `data-theme` ANTES del render para evitar FOUC — Flash of Unstyled Content)
- **Criterio de aceptación**: `npm run dev` muestra una página con el tema oscuro aplicado, tipografías cargadas, sin FOUC.

---

### ÉPICA 2: Navegación y Footer

#### Tarea 2.1 — Navbar
- [x] **Archivo**: `src/components/Navbar.astro`
- **Origen**: Navbar de `MimoV2.5.html` (CSS líneas 155–189, HTML líneas 507–538, JS líneas 1005–1029)
- **Acciones**:
  1. Markup semántico: `<nav>` con logo SVG inline, links de navegación, botones de acción (Iniciar Sesión / Registro), hamburger para mobile
  2. Logo: SVG de MimoV2.5 con texto "EduTech" + "Mendoza 2026"
  3. Links: Inicio, Acerca, Cronograma, Ediciones, FAQ
  4. CSS: fixed top, backdrop-filter blur, border-bottom, efecto `.scrolled` con shadow
  5. JS: Scroll listener para `.scrolled`, toggle de menú mobile, cerrar menú al click en link
  6. Mobile: Menú fullscreen con `transform: translateX()`, bloqueo de scroll del body
  7. Responsive: Links visibles a partir de `768px`, hamburger oculto
  8. Importar `ThemeToggle` dentro del Navbar (o dejarlo fuera como componente independiente en el Layout)
  9. Inyectar Navbar en `Layout.astro`
- **Criterio de aceptación**: Navbar fijo, blur en scroll, menú hamburger funcional en mobile, links visibles en desktop.

---

#### Tarea 2.2 — Footer
- [x] **Archivo**: `src/components/Footer.astro`
- **Origen**: Footer de `MimoV2.5.html` (CSS líneas 393–411, HTML líneas 872–922)
- **Acciones**:
  1. Estructura: brand (logo + descripción), columnas de links (Evento, Participá, Organizan), bottom bar (copyright)
  2. Links del footer: Acerca, Cronograma, Ediciones, FAQ, Inscripción, Bases y Condiciones, Contacto, IES 9-023, IES Edison
  3. Tipografía monospace para labels de columnas
  4. Responsive: 1 columna en mobile, grid en desktop
  5. Inyectar Footer en `Layout.astro`
- **Criterio de aceptación**: Footer completo con todos los links, responsive, con estilo coherente al tema.

---

### ÉPICA 3: Hero Section y Countdown

#### Tarea 3.1 — Hero Section con fondo animado
- [x] **Archivo**: `src/components/Hero.astro`
- **Origen**: Hero de `MimoV2.5.html` (CSS líneas 194–238, HTML líneas 542–583) para estructura, efecto visual de `Claude_Opus_4.7.html` (partículas y radial-gradient) como complemento
- **Acciones**:
  1. Badge: "2da Edición — Mendoza, Argentina" con dot pulsante
  2. Título: Tipografía display gigante "EDUTECH" con color primario
  3. Subtítulo: "Hackathon de Nivel Superior Mendoza 2026"
  4. Descripción: Párrafo descriptivo del evento
  5. Chips de fechas: 3 Jun Virtual → 5-6 Jun Presencial
  6. CTAs: "Inscribirse ahora" (primario) + "Conocer más" (ghost)
  7. Fondo: Formas geométricas animadas (`shape` circles con `drift`) de MimoV2.5 + radial gradients
  8. Opcional: Partículas canvas de ChatZ (evaluar performance)
  9. Animaciones de entrada: `fadeUp` escalonadas con delays
- **Criterio de aceptación**: Hero fullscreen con fondo dinámico, tipografía impactante, animaciones de entrada fluidas, responsive.

---

#### Tarea 3.2 — Countdown Timer
- [x] **Integrar en**: `src/components/Hero.astro`
- **Origen**: Countdown de `MimoV2.5.html` (CSS líneas 228–235, HTML líneas 572–577, JS líneas 982–1003) y `Claude_Opus_4.7.html` (JS líneas 440–455)
- **Acciones**:
  1. UI: 4 items (Días, Horas, Min, Seg) con cards, tipografía display, color primario
  2. Posición: Entre las fechas y los CTAs
  3. JS: Countdown hacia `2026-06-03T21:30:00-03:00` (inicio del evento virtual)
  4. Cuando el diff ≤ 0: Mostrar mensaje "¡El evento ha comenzado!" con estilo destacado
  5. `setInterval` cada 1 segundo
  6. Formato: padStart con ceros
- **Criterio de aceptación**: Countdown muestra tiempo restante en tiempo real, se actualiza cada segundo, maneja el caso de evento ya iniciado.

---

### ÉPICA 4: Información y Bases

#### Tarea 4.1 — InfoCards (Acerca del Hackathon)
- [x] **Archivo**: `src/components/InfoCards.astro`
- **Origen**: Sección "About" de `MimoV2.5.html` (CSS líneas 243–258, HTML líneas 586–617)
- **Acciones**:
  1. Header de sección: Label + título + descripción
  2. Grid de 3 cards:
     - **Temática**: Problemáticas educativas con respuesta tecnológica (ícono SVG libro)
     - **Sedes**: Le Parc + Edison con direcciones (ícono SVG ubicación)
     - **Modalidad**: Equipos de 3-5 personas, inscripción individual (ícono SVG personas)
  3. Cada card: ícono en contenedor coloreado, título h3, párrafo descriptivo
  4. Colores de íconos: c1 (primario), c2 (secundario), c3 (acento) — uno por card
  5. Hover: translateY(-4px), shadow, borde primario
  6. Grid responsive: 1 col mobile, 3 cols desktop
  7. Scroll reveal con delays escalonados (rd1, rd2, rd3)
- **Criterio de aceptación**: 3 cards informativas, hover animado, responsive, consistente con el tema.

---

### ÉPICA 5: Cronograma Interactivo

#### Tarea 5.1 — Estructura del Cronograma
- [x] **Archivo**: `src/components/Schedule.astro`
- **Origen**: Cronograma de `ChatZ.html` (HTML líneas 1005–1141) para los datos hora-por-hora
- **Acciones**:
  1. Header de sección: Label + título + descripción
  2. Estructura por día:
     - **Día Virtual** (Miércoles 3 Jun): 1 actividad
     - **Día 1 Presencial** (Viernes 5 Jun – Le Parc): 5 actividades detalladas
     - **Día 2 Presencial** (Sábado 6 Jun – Edison + Le Parc): 8 actividades detalladas
  3. Cada día tiene header con ícono, fecha y modalidad
  4. Cada actividad: horario + título + descripción

---

#### Tarea 5.2 — Lógica de Colapso/Expansión
- [x] **Integrar en**: `src/components/Schedule.astro`
- **Acciones**:
  1. Por defecto, los items de cada día vienen **colapsados** (solo se ve el header del día)
  2. Click en el header del día → expande/colapsa las actividades de ese día
  3. Animación suave: `max-height` con transición CSS
  4. Indicador visual de estado (chevron o +/-) que rota al expandir
  5. Permitir múltiples días abiertos simultáneamente (o no — confirmar con usuario)
  6. Opcional: primer día abierto por defecto

---

#### Tarea 5.3 — Estilo Visual del Cronograma
- [x] **Integrar en**: `src/components/Schedule.astro`
- **Origen**: Estilo visual de `MimoV2.5.html` (CSS líneas 263–288) — Timeline vertical con dots coloreados y tags
- **Acciones**:
  1. Timeline vertical con línea lateral y dots por día (colores c1, c2, c3)
  2. Cards de contenido con borde y fondo `bg-card`
  3. Tags pill para horarios y ubicaciones
  4. Tipografía mono para fechas y tags
  5. Fondo alternado de la sección (`bg-2`)
  6. Scroll reveal
- **Criterio de aceptación**: Cronograma con todos los datos de ChatZ, estilo visual de MimoV2.5, items colapsados por defecto con toggle funcional.

---

### ÉPICA 6: Preguntas Frecuentes

#### Tarea 6.1 — FAQ Accordion
- [ ] **Archivo**: `src/components/FAQ.astro`
- **Origen**: FAQ de `MimoV2.5.html` (CSS líneas 370–388, HTML líneas 834–867, JS líneas 1042–1050)
- **Acciones**:
  1. Header de sección: Label + título
  2. Lista de preguntas (mínimo 6):
     - ¿Quiénes pueden participar?
     - ¿Cuántas personas puede tener un equipo?
     - ¿La inscripción tiene algún costo?
     - ¿Qué tipo de soluciones se pueden presentar?
     - ¿Cómo se evalúan las propuestas?
     - ¿Cuántos equipos pasan a la final?
  3. Comportamiento acordeón: click abre la respuesta, cierra las demás
  4. Animación: `max-height` transition, ícono `+` que rota 45° al abrir
  5. Estilo: borde bottom separador, tipografía heading para preguntas, body para respuestas
  6. Accesibilidad: `<button>` para las preguntas, `aria-expanded`
  7. Scroll reveal con delays
  8. Max-width ~800px centrado
- **Criterio de aceptación**: Acordeón funcional, una sola pregunta abierta a la vez, animaciones suaves, accesible.

---

### ÉPICA 7: Ensamblaje Final

#### Tarea 7.1 — Index Page y Revisión General
- [ ] **Archivo**: `src/pages/index.astro`
- **Acciones**:
  1. Importar `Layout.astro` como wrapper
  2. Importar y renderizar en orden:
     - `Hero` (incluye countdown)
     - `InfoCards`
     - `Schedule`
     - `FAQ`
  3. (Navbar y Footer ya están en el Layout)
  4. Revisión responsive completa:
     - Mobile (375px)
     - Tablet (768px)
     - Desktop (1200px+)
  5. Revisión de los 3 temas: cyber-dark, eco-light, high-contrast
  6. Verificar que no haya errores en consola
  7. Verificar que `npm run build` compile sin errores
  8. Verificar scroll reveal en todas las secciones
  9. Verificar que el countdown funciona
  10. Verificar navegación por anclas desde navbar y footer
- **Criterio de aceptación**: Landing page completa, responsive, con 3 temas funcionales, sin errores en consola, build exitoso.

---

## Secciones Excluidas (Fuera del Scope de Landing V1)

Las siguientes secciones de las PoC **NO se migran** en esta primera iteración:

| Sección | Razón |
|---------|-------|
| Formulario de Inscripción | Se conectará a Supabase Auth — requiere integración backend |
| Modal de Inscripción | Idem — depende del formulario |
| Ediciones Anteriores / Podio | Se implementará con datos de la tabla `editions` de Supabase |
| Sección "Cómo Funciona" (ChatZ) | Contenido redundante con InfoCards + Schedule |
| CTA de Inscripción | Depende del formulario |
| Toast Notifications | Se implementará cuando haya formularios reales |
| Canvas de Partículas (ChatZ) | Impacto en performance — evaluar en una iteración posterior |

---

## Notas Técnicas

### Prevención de FOUC (Flash of Unstyled Content)
El tema debe aplicarse **antes** del primer render. Incluir en el `<head>` de `Layout.astro`:
```html
<script is:inline>
  const theme = localStorage.getItem('edutech-theme') || 'cyber-dark';
  document.documentElement.setAttribute('data-theme', theme);
</script>
```

### Scroll Reveal Pattern
Usar `IntersectionObserver` global en un `<script>` del Layout o de cada componente:
```js
const observer = new IntersectionObserver((entries) => {
  entries.forEach(e => {
    if (e.isIntersecting) {
      e.target.classList.add('revealed');
      observer.unobserve(e.target);
    }
  });
}, { threshold: 0.1, rootMargin: '0px 0px -40px 0px' });
document.querySelectorAll('.reveal').forEach(el => observer.observe(el));
```

### Convención de Variables CSS
Se unifica la nomenclatura de MimoV2.5 como estándar:
- `--bg-1`, `--bg-2`, `--bg-3` → fondos
- `--bg-card`, `--bg-card-h` → cards
- `--txt-1`, `--txt-2`, `--txt-m` → texto
- `--c1`, `--c2`, `--c3` → colores primario, secundario, acento
- `--c1r`, `--c2r`, `--c3r` → versiones RGB
- `--brd`, `--brd-s` → bordes
- `--sh-sm`, `--sh-md`, `--sh-lg` → sombras

---

*Documento creado para el proyecto HEM2026 — Hackathon EduTech Mendoza 2026*
