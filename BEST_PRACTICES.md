# BEST_PRACTICES.md — Buenas Prácticas y Estándares de Calidad

> Este documento define los estándares de calidad del equipo y las pautas para el uso responsable de inteligencia artificial en el desarrollo del proyecto HEM2026.

---

## 1. Guía de Uso de IA y Agentes de Código

### Principio fundamental

> **La IA es una herramienta, no un reemplazo.** Vos sos el desarrollador. La IA te asiste, pero la responsabilidad del código es tuya.

### Reglas de uso

#### ✅ Lo que SÍ hacer:

1. **Pedir tareas atómicas** — Siempre dar instrucciones pequeñas y específicas.
   - ✅ *"Creá un componente de botón con estas propiedades: ..."*
   - ❌ *"Hacé toda la página de login con autenticación"*

2. **Entender antes de implementar** — Nunca copies código que no entiendas.
   - Si la IA genera algo y no sabés qué hace, **preguntale que te lo explique**.
   - Si después de la explicación seguís sin entender, **pedí ayuda a un compañero**.

3. **Dar contexto** — Cuanto más contexto le des a la IA, mejor resultado obtenés.
   - Mencioná qué tecnologías usás (Astro, Supabase, TypeScript)
   - Describí qué querés lograr, no solo qué código querés
   - Compartí archivos relevantes si es necesario

4. **Iterar** — Si el primer resultado no es perfecto, refiná el pedido.
   - *"Está bien, pero cambiale X por Y"*
   - *"Ahora agregale manejo de errores"*

#### ❌ Lo que NO hacer:

1. **No pedir todo junto** — Las tareas grandes generan código de baja calidad.
2. **No confiar ciegamente** — La IA puede generar código incorrecto, inseguro o ineficiente.
3. **No copiar y pegar sin revisar** — Siempre leé y entendé el código antes de usarlo.
4. **No usar IA para saltear el aprendizaje** — Si no sabés CSS, aprendé CSS. La IA te ayuda a practicar, no a evitar.

### Flujo recomendado con IA

```
1. Definí qué querés hacer (en español, claro y específico)
       │
2. Pedile a la IA una tarea atómica
       │
3. Revisá el código generado
       │
4. ¿Lo entendés? ──── No ──── Pedí explicación
       │                              │
      Sí                         ¿Lo entendés ahora?
       │                              │
5. Probalo en local              No ──── Pedí ayuda humana
       │                              │
6. ¿Funciona? ──── No ──── Iterá con la IA (explicale qué falló)
       │
      Sí
       │
7. Commiteá y seguí con la próxima tarea
```

---

## 2. Estándares de Calidad y Testing

### La regla de oro

> ⚠️ **Siempre testeá en local antes de cualquier push al repositorio remoto.**

No importa qué tan seguro estés de que "funciona". Abrí tu navegador, revisá que todo se vea bien y que no se rompió nada.

### Checklist antes de hacer push

- [ ] `npm run dev` funciona sin errores
- [ ] Revisé visualmente la página en el navegador
- [ ] Probé en al menos **1 navegador** (Chrome, Firefox o Edge)
- [ ] No hay errores en la consola del navegador (F12 → Console)
- [ ] Los cambios no rompen funcionalidad existente
- [ ] Eliminé código de debug (`console.log`, comentarios temporales)
- [ ] El código sigue las convenciones del equipo (ver abajo)

### Antes de crear un Pull Request (adicional)

- [ ] `npm run build` compila sin errores
- [ ] Probé en **vista móvil** (F12 → Toggle Device Toolbar)
- [ ] Los textos visibles están en **español** (interfaz de usuario)
- [ ] El código (variables, funciones) está en **inglés**

---

## 3. Convenciones de Código

### Idiomas

| Qué | Idioma | Ejemplo |
|-----|--------|---------|
| Variables y funciones | Inglés | `getUserData()`, `isLoading` |
| Componentes | Inglés | `NavBar.astro`, `LoginForm.tsx` |
| Comentarios en código | Inglés | `// Fetch user data from Supabase` |
| Interfaz de usuario (textos visibles) | Español | `"Iniciar Sesión"`, `"Bienvenido"` |
| Documentación del proyecto | Español | README.md, GIT_GUIDELINES.md |
| Commits | Inglés | `feat: add login component` |

### Formato de archivos

- **Indentación:** 2 espacios (no tabs)
- **Fin de línea:** LF (Unix)
- **Encoding:** UTF-8
- **Punto y coma:** Sí en TypeScript/JavaScript
- **Comillas:** Simples (`'`) en JS/TS, dobles (`"`) en HTML/Astro

### Nombres de archivos

| Tipo | Convención | Ejemplo |
|------|-----------|---------|
| Componentes Astro | PascalCase | `NavBar.astro` |
| Componentes React/TSX | PascalCase | `LoginForm.tsx` |
| Páginas Astro | kebab-case | `about-us.astro` |
| Utilidades/Helpers | camelCase | `formatDate.ts` |
| Estilos | kebab-case | `global-styles.css` |
| Constantes/Config | camelCase | `supabaseClient.ts` |

---

## 4. Seguridad

### Reglas fundamentales:

1. **Nunca subir secrets al repositorio** — Las API keys, tokens y contraseñas van en `.env` (que está en `.gitignore`)
2. **Usar `.env.example`** — Crear un archivo de ejemplo con las variables necesarias pero **sin valores reales**
3. **Row Level Security (RLS)** — Siempre activar RLS en las tablas de Supabase
4. **Validar inputs** — Nunca confiar en datos que vienen del usuario sin validar

### Ejemplo de `.env.example`:
```env
# Supabase
PUBLIC_SUPABASE_URL=tu_url_aqui
PUBLIC_SUPABASE_ANON_KEY=tu_anon_key_aqui

# Sentry
PUBLIC_SENTRY_DSN=tu_dsn_aqui
```

---

## 5. Comunicación del Equipo

- **Antes de empezar algo nuevo:** Avisá en qué vas a trabajar para evitar conflictos
- **Si encontrás un bug:** Reportalo con contexto (qué hiciste, qué esperabas, qué pasó)
- **Si estás trabado:** Pedí ayuda. No pierdas horas en algo que un compañero puede resolver en 5 minutos
- **Si rompiste algo:** Avisá inmediatamente. Todos nos equivocamos, lo importante es no ocultar errores

---

*Documento creado para el proyecto HEM2026 — Hackathon EduTech Mendoza 2026*
