# Design System - HackathonEduTech 2026

## Visión General
Este documento define el sistema de diseño completo para la web del Hackathon EduTech 2026.

---

## 📋 Paleta de Colores

### Colores Principales
- **Púrpura Primario** (PANTONE 2415 C): `#88007b`
  - Principal - Marca y acciones
  - Claro: `#a82da9`
  - Oscuro: `#5c0052`

- **Verde Secundario** (PANTONE 2292 C): `#9fc637`
  - Secundaria - Destacados y acentos
  - Claro: `#b8d859`
  - Oscuro: `#7a9c1f`

### Colores Neutrales
- **Blanco**: `#ffffff` (Fondo principal)
- **Negro**: `#000000` (Texto principal)
- **Gris Claro** (PANTONE 9345 C): `#eae7ea` (Superficies secundarias)

### Escala de Grises para Texto
- Primario (muy oscuro): `#000000`
- Secundario: `#333333`
- Terciario (gris): `#666666`

---

## 🔤 Tipografía

### Fuentes
- **Logo**: `Lexend` - Para titulares, logotipos y elementos de marca
- **Body**: `Roboto` - Para textos corporales y contenido regular

### Pesos de Lexend
- **100**: Extra Light - Logotipos minimalistas
- **400**: Regular - Bajadas y textos secundarios
- **700**: Bold - Titulares principales
- **900**: Black - Logotipos principales y énfasis máximo

### Pesos de Roboto
- **100-900**: Completo rango disponible
- **Regular (400)**: Cuerpo de texto estándar
- **Itálica**: Disponible para énfasis

### Tamaños de Fuente
| Escala | Tamaño | Uso |
|--------|--------|-----|
| text-xs | 12px | Captions y labels pequeños |
| text-sm | 14px | Texto secundario |
| text-base | 16px | Texto corporal |
| text-lg | 18px | Textos destacados |
| text-xl | 20px | Subencabezados |
| text-2xl | 24px | Encabezados menores |
| text-3xl | 30px | Encabezados |
| text-4xl | 36px | Encabezados principales |
| text-5xl | 48px | Hero titles |

---

## 🎨 Componentes

### 1. Button
**Variantes:**
- Primary (Púrpura)
- Secondary (Verde)
- Outline (Borde púrpura)

**Tamaños:**
- Small: 12px padding
- Medium: 16px padding (default)
- Large: 24px padding

**Estados:**
- Default
- Hover (sombra aumentada, color oscuro)
- Active (sin elevación)
- Disabled (opacidad 50%)

### 2. Typography
**Tipos:**
- h1-h6: Encabezados (Lexend)
- p: Párrafo (Roboto)
- body: Cuerpo (Roboto)
- caption: Etiquetas pequeñas

**Props:**
- type: 'h1' | 'h2' | ... | 'caption'
- text: Contenido
- color: 'primary' | 'secondary' | 'light' | 'dark'
- align: 'left' | 'center' | 'right'
- weight: 'light' | 'normal' | 'semibold' | 'bold' | 'black'

### 3. Card
**Variantes:**
- default: Línea de borde clara
- elevated: Sombra suave
- outlined: Borde más pronunciado

**Props:**
- title: Título del card
- description: Descripción corta
- variant: Tipo visual
- hover: Efecto hover (default: true)

### 4. Input
**Tipos soportados:**
- text
- email
- password
- number
- date
- search

**Features:**
- Label asociada
- Placeholder
- Estado requerido (*)
- Foco: Borde púrpura + sombra

### 5. Badge
**Variantes:**
- primary (Púrpura)
- secondary (Verde)
- success (Verde brillante)
- warning (Naranja)
- error (Rojo)
- info (Azul)

**Tamaños:**
- small
- medium

### 6. Avatar
**Variantes:**
- primary: Gradiente púrpura
- secondary: Gradiente verde

**Tamaños:**
- small: 32px
- medium: 48px (default)
- large: 64px

**Tipos:**
- Con imagen
- Con iniciales
- Con placeholder emoji

### 7. Tooltip
**Posiciones:**
- top
- bottom
- left
- right

**Comportamiento:**
- Aparece al hover
- Transición suave
- Punta direccional

### 8. Accordion
**Features:**
- Múltiples items
- Un item abierto por defecto
- Icono rotativo
- Animación suave

---

## 📐 Espaciado

| Escala | Valor | Uso |
|--------|-------|-----|
| xs | 4px | Espacios muy pequeños |
| sm | 8px | Espacios pequeños |
| md | 16px | Espaciado estándar |
| lg | 24px | Espacios amplios |
| xl | 32px | Separación de secciones |
| 2xl | 48px | Espaciado principal |

---

## 🌐 Responsive Design

### Breakpoints
- **Mobile**: Default (< 768px)
- **Tablet**: >= 768px
- **Desktop**: >= 1024px

### Mobile First
El sistema está diseñado mobile-first. Los tamaños aumentan progresivamente en tablet y desktop.

---

## 📚 Uso en Componentes

### Importar Variables CSS
```css
:root {
  --color-primary: #88007b;
  --font-logo: 'Lexend', sans-serif;
  /* ... etc */
}
```

### Tamaños de Fuente
```css
font-size: var(--text-base);
font-family: var(--font-logo);
```

### Espaciado
```css
padding: var(--spacing-lg);
gap: var(--spacing-md);
```

---

## 🎯 Convenciones de Codificación

### Estructura de Componentes
1. Props interface
2. Destructuring de props
3. Template HTML
4. Bloque `<style>` con CSS modular
5. Script (si es necesario)

### Clases CSS
- Usar BEM para componentes complejos
- Nombres descriptivos en camelCase
- Evitar estilos inline excepto propiedades dinámicas

### Colores
Siempre usar variables CSS, nunca valores hardcodeados:
- ✅ `color: var(--color-primary)`
- ❌ `color: #88007b`

---

## 🚀 Próximos Pasos

- [ ] Agregar componentes adicionales según sea necesario
- [ ] Crear página de componentes interactiva
- [ ] Documentar patrones de uso comunes
- [ ] Agregar estados de accesibilidad
- [ ] Crear guía de contribución

---

**Ultima actualización**: 7 de Mayo, 2026
**Versión**: 1.0.0
