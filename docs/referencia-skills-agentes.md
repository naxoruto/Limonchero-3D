# Skills y Agentes del Proyecto — Referencia en Español

> Traducción completa de todas las skills disponibles en el framework CCGS para Detective Noir / Limonchero 3D.
> Las skills están agrupadas por fase de desarrollo y tipo.

---

## Fase 0: Onboarding y Configuración

| Skill | Descripción |
|-------|-------------|
| **start** | Onboarding inicial — pregunta dónde estás y te guía al flujo de trabajo correcto. Sin suposiciones. |
| **setup-engine** | Configura el motor de juego y su versión para el proyecto. Fija el motor en CLAUDE.md, detecta lagunas de conocimiento y obtiene documentación de referencia del motor vía búsqueda web cuando la versión supera los datos de entrenamiento del LLM. |
| **project-stage-detect** | Analiza automáticamente el estado del proyecto, detecta la fase actual, identifica vacíos y recomienda próximos pasos según los artefactos existentes. Usar con: "¿en qué etapa estamos?", "auditoría completa del proyecto". |
| **adopt** | Onboarding brownfield — audita los artefactos existentes del proyecto para verificar conformidad con el formato de la plantilla (no solo existencia), clasifica brechas por impacto y produce un plan de migración numerado. Úsalo al unirte a un proyecto en curso o al actualizar desde una versión anterior de la plantilla. |
| **onboard** | Genera un documento de onboarding contextual para un nuevo colaborador o agente que se une al proyecto. Resume el estado del proyecto, arquitectura, convenciones y prioridades actuales según el rol o área especificada. |

---

## Fase 1: Conceptualización y Diseño

| Skill | Descripción |
|-------|-------------|
| **brainstorm** | Ideación guiada de concepto de juego — desde cero hasta un documento estructurado de concepto. Usa técnicas profesionales de ideación de estudio, marcos de psicología del jugador y exploración creativa estructurada. |
| **map-systems** | Descompone un concepto de juego en sistemas individuales, mapea dependencias, prioriza el orden de diseño y crea el índice de sistemas. |
| **art-bible** | Autoría guiada, sección por sección, de la Biblia de Arte. Crea la especificación de identidad visual que regula toda la producción de assets. Ejecutar después de aprobar /brainstorm y antes de /map-systems o cualquier autoría de GDD. |
| **prototype** | Prototipo de concepto — valida que la idea central vale la pena diseñar antes de escribir GDDs. Se ejecuta justo después de /brainstorm y /setup-engine. Enruta hacia HTML, Engine o Paper según el tipo de juego. Produce un build descartable y un veredicto PROCEED/PIVOT/KILL. |

---

## Fase 2: Documentos de Diseño (GDDs)

| Skill | Descripción |
|-------|-------------|
| **design-system** | Autoría guiada, sección por sección, de un GDD para un sistema individual del juego. Recopila contexto de documentos existentes, recorre cada sección requerida de forma colaborativa, referencia dependencias cruzadas y escribe incrementalmente al archivo. |
| **quick-design** | Especificación de diseño ligera para cambios pequeños — ajustes de tuning, mecánicas menores, balanceos. Omite la autoría completa de GDD cuando ya existe un GDD del sistema o el cambio es demasiado pequeño para justificar uno. Produce un Quick Design Spec que se incrusta directamente en los archivos de historia. |
| **design-review** | Revisa un documento de diseño de juego para verificar integridad, consistencia interna, implementabilidad y adherencia a los estándares de diseño del proyecto. Ejecutar antes de entregar un documento de diseño a los programadores. |
| **review-all-gdds** | Revisión holística de consistencia entre GDDs y de diseño de juego. Lee todos los GDDs de sistema simultáneamente y verifica contradicciones entre ellos, referencias obsoletas, conflictos de propiedad, incompatibilidades de fórmulas y violaciones de teoría de diseño de juegos (estrategias dominantes, desequilibrio económico, sobrecarga cognitiva, desviación de pilares). Ejecutar después de escribir todos los GDDs del MVP, antes de comenzar la arquitectura. |
| **consistency-check** | Escanea todos los GDDs contra el registro de entidades para detectar inconsistencias entre documentos: misma entidad con diferentes estadísticas, mismo ítem con diferentes valores, misma fórmula con diferentes variables. Enfoque grep-first — lee el registro y luego apunta solo a las secciones conflictivas de los GDDs. |
| **propagate-design-change** | Cuando se revisa un GDD, escanea todos los ADRs y el índice de trazabilidad para identificar qué decisiones arquitectónicas están ahora potencialmente obsoletas. Produce un informe de impacto del cambio y guía al usuario a través de la resolución. |

---

## Fase 3: Arquitectura

| Skill | Descripción |
|-------|-------------|
| **create-architecture** | Autoría guiada, sección por sección, del documento maestro de arquitectura del juego. Lee todos los GDDs, el índice de sistemas, los ADRs existentes y la biblioteca de referencia del motor para producir un plano arquitectónico completo antes de escribir cualquier código. Consciente de la versión del motor: marca lagunas de conocimiento y valida decisiones contra la versión fijada del motor. |
| **architecture-decision** | Crea un Architecture Decision Record (ADR) documentando una decisión técnica significativa, su contexto, alternativas consideradas y consecuencias. Cada decisión técnica importante debe tener un ADR. |
| **architecture-review** | Valida la integridad y consistencia de la arquitectura del proyecto contra todos los GDDs. Construye una matriz de trazabilidad que mapea cada requisito técnico de los GDDs a ADRs, identifica brechas de cobertura, detecta conflictos entre ADRs, verifica la consistencia de compatibilidad del motor en todas las decisiones y produce un veredicto PASS/CONCERNS/FAIL. El equivalente de arquitectura de /design-review. |
| **create-control-manifest** | Después de completar la arquitectura, produce una hoja plana de reglas accionables para programadores — qué debes hacer, qué nunca debes hacer, por sistema y por capa. Extraído de todos los ADRs aceptados, preferencias técnicas y documentos de referencia del motor. Más inmediatamente accionable que los ADRs (que explican el por qué). |

---

## Fase 4: Planificación de Sprints e Historias

| Skill | Descripción |
|-------|-------------|
| **create-epics** | Traduce GDDs aprobados + arquitectura en épicas — una épica por módulo arquitectónico. Define alcance, ADRs gobernantes, riesgo del motor y requisitos no trazados. NO descompone en historias — ejecutar /create-stories [epic-slug] después de crear cada épica. |
| **create-stories** | Descompone una sola épica en archivos de historia implementables. Lee la épica, su GDD, ADRs gobernantes y el manifiesto de control. Cada historia incluye su TR-ID del requisito GDD, guía ADR, criterios de aceptación, tipo de historia y ruta de evidencia de prueba. Ejecutar después de /create-epics para cada épica. |
| **sprint-plan** | Genera un nuevo plan de sprint o actualiza uno existente basado en el hito actual, trabajo completado y capacidad disponible. Extrae contexto de documentos de producción y backlogs de diseño. |
| **estimate** | Estima el esfuerzo de una tarea analizando complejidad, dependencias, velocidad histórica y factores de riesgo. Produce una estimación estructurada con niveles de confianza. |
| **scope-check** | Analiza una funcionalidad o sprint en busca de scope creep comparando el alcance actual contra el plan original. Marca adiciones, cuantifica la inflación y recomienda recortes. Usar con: "¿hay scope creep?", "revisión de alcance". |
| **story-readiness** | Valida que un archivo de historia esté listo para implementación. Verifica requisitos GDD incrustados, referencias ADR, notas del motor, criterios de aceptación claros y que no haya preguntas de diseño abiertas. Produce veredicto READY / NEEDS WORK / BLOCKED. |

---

## Fase 5: Implementación

| Skill | Descripción |
|-------|-------------|
| **dev-story** | Lee un archivo de historia y lo implementa. Carga el contexto completo (historia, requisito GDD, guías ADR, manifiesto de control), enruta al agente programador correcto para el sistema y motor, implementa el código y las pruebas, y confirma cada criterio de aceptación. La skill central de implementación — ejecutar después de /story-readiness, antes de /code-review y /story-done. |
| **code-review** | Realiza una revisión de código arquitectónica y de calidad en un archivo o conjunto de archivos especificado. Verifica cumplimiento de estándares de codificación, adherencia a patrones arquitectónicos, principios SOLID, testabilidad y preocupaciones de rendimiento. |
| **story-done** | Revisión de finalización de historia. Lee el archivo de historia, verifica cada criterio de aceptación contra la implementación, busca desviaciones de GDD/ADR, solicita revisión de código, actualiza el estado de la historia a Complete y muestra la siguiente historia lista del sprint. |
| **reverse-document** | Genera documentos de diseño o arquitectura a partir de implementación existente. Trabaja hacia atrás desde código/prototipos para crear documentos de planificación faltantes. |

---

## Fase 6: QA y Pruebas

| Skill | Descripción |
|-------|-------------|
| **test-setup** | Configura el framework de pruebas y el pipeline CI/CD para el motor del proyecto. Crea la estructura del directorio tests/, la configuración del ejecutor de pruebas específico del motor y el workflow de GitHub Actions. Ejecutar una vez durante la fase de Technical Setup antes de que comience el primer sprint. |
| **test-helpers** | Genera bibliotecas de ayuda de pruebas específicas del motor para el conjunto de pruebas del proyecto. Lee patrones de prueba existentes y produce tests/helpers/ con utilidades de aserción, funciones de fábrica y objetos mock adaptados a los sistemas del proyecto. Reduce el boilerplate en nuevos archivos de prueba. |
| **test-flakiness** | Detecta pruebas no deterministas (flaky) leyendo logs de ejecución de CI o historial de resultados de pruebas. Agrega tasas de éxito por prueba, identifica fallos intermitentes, recomienda cuarentena o corrección, y mantiene un registro de pruebas flaky. |
| **test-evidence-review** | Revisión de calidad de archivos de prueba y documentos de evidencia manual. Va más allá de la verificación de existencia — evalúa cobertura de aserciones, manejo de casos límite, convenciones de nomenclatura e integridad de evidencia. Produce veredicto ADEQUATE/INCOMPLETE/MISSING por historia. |
| **qa-plan** | Genera un plan de pruebas QA para un sprint o funcionalidad. Lee GDDs y archivos de historia, clasifica historias por tipo de prueba (Logic/Integration/Visual/UI), y produce un plan de pruebas estructurado cubriendo pruebas automatizadas requeridas, casos de prueba manuales, alcance de smoke test y requisitos de playtest para aprobación. |
| **smoke-check** | Ejecuta la puerta de smoke test de ruta crítica antes de la entrega a QA. Ejecuta el conjunto de pruebas automatizadas, verifica funcionalidad principal y produce un informe PASS/FAIL. Un smoke check fallido significa que el build no está listo para QA. |
| **regression-suite** | Mapea cobertura de pruebas a rutas críticas del GDD, identifica bugs corregidos sin pruebas de regresión, marca desviación de cobertura por nuevas funcionalidades y mantiene tests/regression-suite.md. |
| **soak-test** | Genera un protocolo de soak test para sesiones de juego extendidas. Define qué observar, medir y registrar durante sesiones largas para detectar fugas lentas, efectos de fatiga y casos límite que solo aparecen tras juego sostenido. |

---

## Fase 7: Revisión y Pulido

| Skill | Descripción |
|-------|-------------|
| **sprint-status** | Verificación rápida de estado del sprint. Lee el plan de sprint actual, escanea archivos de historia por estado y produce una instantánea concisa de progreso con evaluación de burndown y riesgos emergentes. |
| **bug-report** | Crea un informe de bug estructurado a partir de una descripción, o analiza código para identificar bugs potenciales. Asegura que cada informe de bug tenga pasos completos de reproducción, evaluación de severidad y contexto. |
| **bug-triage** | Lee todos los bugs abiertos en production/qa/bugs/, reevalúa prioridad vs. severidad, asigna a sprints, detecta tendencias sistémicas y produce un informe de triaje. Ejecutar al inicio del sprint o cuando el conteo de bugs crezca lo suficiente para necesitar repriorización. |
| **content-audit** | Audita el contenido especificado en GDDs contra el contenido implementado. Identifica qué está planeado vs. construido. |
| **asset-audit** | Audita los assets del juego para verificar cumplimiento con convenciones de nomenclatura, presupuestos de tamaño de archivo, estándares de formato y requisitos del pipeline. Identifica assets huérfanos, referencias faltantes y violaciones de estándares. |
| **asset-spec** | Genera especificaciones visuales por asset y prompts de generación AI a partir de GDDs, documentos de nivel o perfiles de personaje. Produce archivos de especificación estructurados y actualiza el manifiesto maestro de assets. Ejecutar después de que la biblia de arte y GDD/diseño de nivel estén aprobados, antes de que comience la producción. |
| **balance-check** | Analiza archivos de datos de balance del juego, fórmulas y configuración para identificar valores atípicos, progresiones rotas, estrategias degeneradas y desequilibrios de economía. Usar después de modificar cualquier dato o diseño relacionado con balance. |
| **perf-profile** | Flujo de trabajo estructurado de perfilado de rendimiento. Identifica cuellos de botella, mide contra presupuestos y genera recomendaciones de optimización con clasificación de prioridad. |
| **tech-debt** | Rastrea, categoriza y prioriza la deuda técnica en todo el código base. Escanea en busca de indicadores de deuda, mantiene un registro de deuda y recomienda programación de pago. |
| **security-audit** | Audita el juego en busca de vulnerabilidades de seguridad: manipulación de saves, vectores de trampa, exploits de red, exposición de datos y brechas de validación de entrada. Produce un informe de seguridad priorizado con guía de remediación. |

---

## Fase 8: UX/UI

| Skill | Descripción |
|-------|-------------|
| **ux-design** | Autoría guiada, sección por sección, de especificación UX para una pantalla, flujo o HUD. Lee el concepto del juego, journey del jugador y GDDs relevantes para proporcionar guía de diseño contextual. Produce ux-spec.md (por pantalla/flujo) o hud-design.md usando las plantillas del estudio. |
| **ux-review** | Valida una especificación UX, diseño de HUD o biblioteca de patrones de interacción para verificar integridad, cumplimiento de accesibilidad, alineación con GDD y preparación para implementación. Produce veredicto APPROVED / NEEDS REVISION / MAJOR REVISION NEEDED. |
| **team-ui** | Orquesta el equipo de UI a través del pipeline completo de UX: desde la autoría de especificación UX hasta diseño visual, implementación, revisión y pulido. Se integra con /ux-design, /ux-review y plantillas UX del estudio. |

---

## Fase 9: Equipos Multidisciplinarios (Teams)

| Skill | Descripción |
|-------|-------------|
| **team-audio** | Orquesta el equipo de audio: audio-director + sound-designer + technical-artist + gameplay-programmer para el pipeline completo de audio desde dirección hasta implementación. |
| **team-combat** | Orquesta el equipo de combate: coordina game-designer, gameplay-programmer, ai-programmer, technical-artist, sound-designer y qa-tester para diseñar, implementar y validar una funcionalidad de combate de principio a fin. |
| **team-level** | Orquesta el equipo de diseño de niveles: level-designer + narrative-director + world-builder + art-director + systems-designer + qa-tester para la creación completa de área/nivel. |
| **team-narrative** | Orquesta el equipo narrativo: coordina narrative-director, writer, world-builder y level-designer para crear contenido de historia cohesivo, lore del mundo y diseño de niveles dirigido por narrativa. |
| **team-live-ops** | Orquesta el equipo de live-ops para planificación de contenido post-lanzamiento: coordina live-ops-designer, economy-designer, analytics-engineer, community-manager, writer y narrative-director para diseñar y planificar una temporada, evento o actualización de contenido en vivo. |
| **team-polish** | Orquesta el equipo de pulido: coordina performance-analyst, technical-artist, sound-designer y qa-tester para optimizar, pulir y endurecer una funcionalidad o área para calidad de release. |
| **team-qa** | Orquesta el equipo de QA a través de un ciclo completo de pruebas. Coordina qa-lead (estrategia + plan de pruebas) y qa-tester (escritura de casos de prueba + reporte de bugs) para producir un paquete QA completo para un sprint o funcionalidad. |
| **team-release** | Orquesta el equipo de release: coordina release-manager, qa-lead, devops-engineer y producer para ejecutar un release desde candidato hasta despliegue. |

---

## Fase 10: Lanzamiento y Post-Lanzamiento

| Skill | Descripción |
|-------|-------------|
| **gate-check** | Valida la preparación para avanzar entre fases de desarrollo. Produce un veredicto PASS/CONCERNS/FAIL con bloqueadores específicos y artefactos requeridos. |
| **milestone-review** | Genera una revisión integral de progreso de hito incluyendo completitud de funcionalidades, métricas de calidad, evaluación de riesgos y recomendación go/no-go. |
| **vertical-slice** | Validación de Pre-Producción — construye un build de calidad de producción de principio a fin para confirmar que el loop completo del juego es alcanzable antes de comprometerse a Producción. Produce un veredicto PROCEED/PIVOT/KILL que regula la transición Pre-Producción → Producción. |
| **launch-checklist** | Validación completa de preparación para lanzamiento cubriendo cada departamento: código, contenido, tienda, marketing, comunidad, infraestructura, legal y aprobaciones go/no-go. |
| **release-checklist** | Genera una lista de verificación pre-release integral cubriendo verificación de build, requisitos de certificación, metadatos de tienda y preparación para lanzamiento. |
| **day-one-patch** | Prepara un parche de día uno para el lanzamiento de un juego. Define alcance, prioriza, implementa y valida con QA un parche enfocado que aborda problemas conocidos descubiertos después del gold master pero antes o inmediatamente después del lanzamiento público. |
| **hotfix** | Flujo de trabajo de corrección de emergencia que evade los procesos normales de sprint con un registro de auditoría completo. Crea rama hotfix, rastrea aprobaciones y asegura que la corrección se backportea correctamente. |
| **patch-notes** | Genera notas de parche orientadas al jugador a partir del historial de git, datos de sprint y changelogs internos. Traduce lenguaje de desarrollador a comunicación clara y atractiva para el jugador. |
| **changelog** | Auto-genera un changelog a partir de commits de git, datos de sprint y documentos de diseño. Produce versiones tanto internas como orientadas al jugador. |
| **retrospective** | Genera una retrospectiva de sprint o hito analizando trabajo completado, velocidad, bloqueadores y patrones. Produce ideas accionables para la siguiente iteración. |
| **localize** | Pipeline completo de localización: escanea strings hardcodeados, extrae y gestiona tablas de strings, valida traducciones, genera briefings para traductores, ejecuta revisión cultural/sensibilidad, gestiona localización de VO, prueba requisitos RTL/plataforma, aplica string freeze y reporta cobertura. |

---

## Skills Transversales

| Skill | Descripción |
|-------|-------------|
| **help** | Analiza lo que está hecho y la consulta del usuario y ofrece consejo sobre qué hacer a continuación. Usar si el usuario dice "¿qué debería hacer ahora?", "estoy atascado", "no sé qué hacer". |
| **playtest-report** | Genera una plantilla de informe de playtest estructurado o analiza notas de playtest existentes en un formato estructurado. Úsalo para estandarizar la recolección y análisis de feedback de playtest. |
| **caveman** *(global)* | Modo de comunicación ultra-comprimido. Reduce el uso de tokens ~75% hablando como cavernícola manteniendo precisión técnica completa. Soporta niveles de intensidad: lite, full (por defecto), ultra, wenyan-lite, wenyan-full, wenyan-ultra. |
| **emil-design-eng** *(global)* | Codifica la filosofía de Emil Kowalski sobre pulido de UI, diseño de componentes, decisiones de animación y los detalles invisibles que hacen que el software se sienta genial. |
| **find-skills** *(global)* | Ayuda a los usuarios a descubrir e instalar agent skills cuando preguntan "cómo hago X", "encuentra una skill para X", "hay una skill que pueda...", o expresan interés en extender capacidades. |
| **skill-improve** | Mejora una skill usando un ciclo test-fix-retest. Ejecuta verificaciones estáticas, propone correcciones dirigidas, reescribe la skill, re-prueba y mantiene o revierte según el cambio de puntuación. |
| **skill-test** | Valida archivos de skill para cumplimiento estructural y corrección de comportamiento. Tres modos: static (linter), spec (comportamiento), audit (informe de cobertura). |

---

## Resumen por Fase

| Fase | Skills |
|------|--------|
| **0. Onboarding** | start, setup-engine, project-stage-detect, adopt, onboard |
| **1. Conceptualización** | brainstorm, map-systems, art-bible, prototype |
| **2. GDDs** | design-system, quick-design, design-review, review-all-gdds, consistency-check, propagate-design-change |
| **3. Arquitectura** | create-architecture, architecture-decision, architecture-review, create-control-manifest |
| **4. Planificación** | create-epics, create-stories, sprint-plan, estimate, scope-check, story-readiness |
| **5. Implementación** | dev-story, code-review, story-done, reverse-document |
| **6. QA y Pruebas** | test-setup, test-helpers, test-flakiness, test-evidence-review, qa-plan, smoke-check, regression-suite, soak-test |
| **7. Revisión y Pulido** | sprint-status, bug-report, bug-triage, content-audit, asset-audit, asset-spec, balance-check, perf-profile, tech-debt, security-audit |
| **8. UX/UI** | ux-design, ux-review, team-ui |
| **9. Equipos** | team-audio, team-combat, team-level, team-narrative, team-live-ops, team-polish, team-qa, team-release |
| **10. Lanzamiento** | gate-check, milestone-review, vertical-slice, launch-checklist, release-checklist, day-one-patch, hotfix, patch-notes, changelog, retrospective, localize |
| **Transversales** | help, playtest-report, caveman, emil-design-eng, find-skills, skill-improve, skill-test |

---

*Total: 72 skills | Generado: Mayo 2026 | Proyecto: Detective Noir — Limonchero 3D*
