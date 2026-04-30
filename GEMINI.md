# Proyecto: HEM2026 (Hackathon EduTech Mendoza 2026)

## Contexto
Plataforma web oficial para la Hackathon EduTech Mendoza 2026.
Desarrollada de manera colaborativa por estudiantes del IES 9-023 y el IES Tomás Alva Edison.

## Stack Tecnológico
- **Frontend**: Astro (SSG/SSR)
- **Backend**: Supabase (PostgreSQL, Auth, RLS, Edge Functions)
- **Deploy**: Vercel (`main` → Producción, `develop` → Staging/Dev)
- **Monitoreo**: Sentry (errores, logs, performance) + Vercel Analytics
- **Lenguaje**: TypeScript cuando sea necesario
- **Control de versiones**: Git / GitHub

## Reglas de Desarrollo
- Idioma del código (variables, funciones, componentes, commits): **inglés**
- Idioma de documentación y comentarios de usuario: **español**
- Preferir TypeScript sobre JavaScript siempre que sea posible
- Seguir la estructura de carpetas estándar de Astro
- Nunca hacer merge ni push directo a `main` — siempre vía Pull Request
- Testear en local antes de cualquier push

## Flujo de Ramas
```
[Nombre]_Develop → test local OK → PR a develop → test OK → PR a main (Producción)
```

## Estructura del Proyecto
```
HEM2026/
├── src/
│   ├── pages/          # Rutas/páginas de Astro
│   ├── components/     # Componentes reutilizables
│   ├── layouts/        # Layouts base
│   ├── styles/         # CSS global y variables
│   └── lib/            # Utilidades, helpers, integración Supabase
├── public/             # Assets estáticos (imágenes, favicons)
├── astro.config.mjs    # Configuración de Astro
├── package.json
├── tsconfig.json
├── .env.example        # Variables de entorno de ejemplo
├── README.md
├── GIT_GUIDELINES.md   # Guía de contribución y control de versiones
└── BEST_PRACTICES.md   # Buenas prácticas y uso de IA
```
> **Nota:** Esta estructura se completará cuando se inicialice el proyecto Astro.

## Archivos Importantes
- `GIT_GUIDELINES.md` — Reglas de ramas, commits y Pull Requests
- `BEST_PRACTICES.md` — Estándares de calidad, testing y uso de IA
- `.env.example` — Template de variables de entorno (SIN secrets)

## Notas para el Agente
- La carpeta `ayudas_y_recursos/` es personal y está ignorada por git. No la modifiques.
- La carpeta `.gemini/` es configuración personal del agente. Está ignorada por git.
- Este es un proyecto colaborativo con desarrolladores junior — priorizar claridad y simplicidad.
- Ante la duda, pedir confirmación antes de hacer cambios destructivos.
