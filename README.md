# Cátedra de Ciencias

Notas de curso de **Cátedra de Ciencias** — una introducción al pensamiento científico: historia y filosofía de la ciencia, lectura crítica de artículos académicos y comunicación científica.

**Autor:** Dr. Mario Abarca · **Licencia:** [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/deed.es)

---

## 📖 Contenido

- **Prefacio** — Para quién es este libro y cómo aprovecharlo
- **Historia de la Ciencia** — Evolución del método científico y las instituciones de investigación
- **Filosofía de la Ciencia** — Problema de demarcación, revoluciones científicas y críticas a la ciencia
- **Literatura Científica** — Historia de las publicaciones y cómo leer un artículo científico
- **Presentaciones** — El arte de exponer trabajos de investigación oralmente
- **Modelo por Competencias** — Formación para el científico del siglo XXI

---

## 🐳 Requisitos

El proyecto usa un **contenedor de desarrollo (dev container)** con todo el tooling preinstalado. Solo necesitás:

- **[Docker](https://docs.docker.com/get-docker/)** (o un runtime compatible como Podman)
- **[VS Code](https://code.visualstudio.com/)** con la extensión [Dev Containers](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers) (recomendado)

Al abrir la carpeta en VS Code, el editor detectará el contenedor y ofrecerá reabrir el proyecto dentro de él. Todo lo demás —LaTeX, Inkscape, Python, fuentes— ya viene configurado.

---

## 🚀 Uso

| Comando | Qué hace |
|---------|----------|
| `make` | Compila PDF y EPUB en `salida/` |
| `make clean` | Borra archivos auxiliares (conserva `salida/`) |
| `make view` | Abre el PDF compilado |
| `make format` | Formatea los fuentes LaTeX |

Los productos finales quedan en:
- `salida/catedraciencias.pdf`
- `salida/catedraciencias.epub`
<b>
---

## 📁 Estructura

```
.
├── catedraciencias.tex    # Documento principal
├── preambulo/             # Configuración: fuentes, estilos, comandos
├── capitulos/             # Un archivo .tex por capítulo
├── img/                   # Imágenes (JPG, PNG, SVG)
├── bibliografia.bib       # Referencias (biblatex)
├── Examenes/              # Exámenes en Markdown
├── scripts/               # Scripts auxiliares
├── salida/                # PDF y EPUB generados
├── Makefile
├── CHANGELOG.md
└── LICENSE
```

---

## ✍️ Guía rápida de escritura

El documento usa **LuaLaTeX** con clase `scrbook` (KOMA-Script) e idioma español (`polyglossia`).

**Etiquetas** — prefijos para `\label{}`:

| Prefijo | Para |
|---------|------|
| `cha:` | capítulos |
| `sec:` | secciones |
| `sub:` | subsecciones |
| `fig:` | figuras |
| `rem:` | bloques *recordar* |

**Comandos útiles:**

| Comando | Ejemplo | Resultado |
|---------|---------|-----------|
| `\terminology{Término}` | `\terminology{Ciencia}` | Negrita + entrada en el índice |
| `\person{Nombre}` | `\person{Aristóteles}` | Texto + índice ordenado |
| `\person[Apellido]{Nombre}` | `\person[Bacon]{Francis}` | "Francis Bacon", índice: "Bacon, Francis" |
| `\footurl{URL}` | `\footurl{https://…}` | URL como nota al pie |

**Entornos:**

| Entorno | Uso |
|---------|-----|
| `remember` | Concepto clave destacado |
| `digress` | Comentario o digresión lateral |
| `theorem`, `lemma`, `definition`, `example`, `exercise` | Teoremas y definiciones (numerados por capítulo) |

**Imágenes** — colocalas en `img/` y referencialas sin extensión:

```latex
\includegraphics{img/mi-figura}
```

Los SVG en `figuras/` se convierten automáticamente a PDF con Inkscape.

---

## 🏷️ Versiones

Versionado semántico. El historial completo está en [`CHANGELOG.md`](CHANGELOG.md).
