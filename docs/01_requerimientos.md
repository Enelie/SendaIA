# Requerimientos funcionales de SENDAIA

Este documento define los 27 requerimientos funcionales (RF01–RF27) del aplicativo móvil SENDAIA, alineados con la tesis "Implementación de un aplicativo móvil con IA para fortalecer el apoyo parental en el aprendizaje de niños con TDAH del Centro Colibrí, 2026".

Cada RF incluye: módulo, dimensión de la variable X que alimenta, historia de usuario, criterios de aceptación y el caso de prueba (CP) asociado en `docs/03_casos_de_prueba.md`.

---

## Módulo: Acceso

### RF01 — Registrarse e iniciar sesión
- **Dimensión:** Usabilidad (UA1 — facilidad de acceso)
- **Historia de usuario:** Como padre o tutor, quiero registrarme e iniciar sesión para acceder de manera segura al aplicativo.
- **Dado que** el padre o tutor se encuentra en la pantalla de acceso y dispone de los datos necesarios para registrarse,
- **cuando** completa el formulario de registro y posteriormente ingresa sus credenciales,
- **entonces** el sistema registra la cuenta y permite el acceso al aplicativo.
- **Criterios de aceptación:**
  - Credenciales válidas → acceso concedido.
  - Credenciales inválidas → mensaje de error sin revelar qué campo falló.
  - Contraseña almacenada con hash bcrypt.
  - Sesión persistente mediante JWT y Flutter Secure Storage.
- **Caso de prueba:** CP-01

### RF02 — Acceder al panel familiar
- **Dimensión:** Usabilidad (UA1, UA2)
- **Historia de usuario:** Como padre o tutor, quiero acceder al panel familiar para utilizar las funcionalidades disponibles.
- **Dado que** el padre o tutor inició sesión correctamente,
- **cuando** el sistema carga la pantalla principal,
- **entonces** se muestra el panel familiar con los accesos a las principales funcionalidades.
- **Criterios de aceptación:**
  - El panel solo es accesible con sesión válida.
  - Muestra el resumen del perfil del niño y los accesos a perfil, sugerencias, seguimiento y asistente.
- **Caso de prueba:** CP-02

---

## Módulo: Registro del niño

### RF03 — Registrar uno o varios niños asociados a la cuenta
- **Dimensión:** Funcionalidad
- **Historia de usuario:** Como padre o tutor, quiero registrar uno o varios niños asociados a mi cuenta para gestionar su información.
- **Dado que** el padre o tutor inició sesión y está en el panel familiar,
- **cuando** selecciona la opción de registrar un niño y completa el proceso,
- **entonces** el sistema guarda la información y la asocia a su cuenta.
- **Criterios de aceptación:**
  - Un tutor puede tener N niños.
  - Cada niño queda vinculado a un solo tutor (tutor_id).
  - El registro incluye consentimiento informado del tutor.
- **Caso de prueba:** CP-03

### RF04 — Registrar datos básicos del niño
- **Dimensión:** Funcionalidad
- **Historia de usuario:** Como padre o tutor, quiero registrar los datos básicos del niño para contar con su información inicial.
- **Dado que** el usuario inició el proceso de registro,
- **cuando** ingresa nombre y fecha de nacimiento,
- **entonces** el sistema valida y guarda la información.
- **Criterios de aceptación:**
  - Nombre y fecha de nacimiento son obligatorios.
  - Fecha de nacimiento válida (no futura).
- **Caso de prueba:** CP-04

### RF05 — Registrar diagnóstico previo de TDAH (opcional)
- **Dimensión:** Funcionalidad
- **Historia de usuario:** Como padre o tutor, quiero indicar si el niño cuenta con un diagnóstico previo de TDAH para registrar esta información como antecedente.
- **Dado que** el usuario completa los datos básicos,
- **cuando** indica si el niño tiene diagnóstico previo,
- **entonces** el sistema registra la información sin exigir que exista diagnóstico.
- **Criterios de aceptación:**
  - El campo es opcional.
  - El sistema no infiere ni diagnostica.
- **Caso de prueba:** CP-05

### RF06 — Registrar características de aprendizaje
- **Dimensión:** Funcionalidad
- **Historia de usuario:** Como padre o tutor, quiero registrar las características de aprendizaje de mi hijo para identificar sus necesidades educativas.
- **Dado que** se registraron los datos básicos,
- **cuando** el usuario completa la información del perfil de aprendizaje,
- **entonces** el sistema la almacena.
- **Criterios de aceptación:**
  - Se registran las características en la etapa 2 del formulario.
  - Los datos quedan disponibles para el motor de sugerencias.
- **Caso de prueba:** CP-06

### RF07 — Registrar atención, seguimiento de instrucciones, forma de aprendizaje y dificultades
- **Dimensión:** Funcionalidad
- **Historia de usuario:** Como padre o tutor, quiero registrar el nivel de atención, concentración, forma de aprendizaje y seguimiento de instrucciones del niño.
- **Dado que** el usuario está en la sección de perfil de aprendizaje,
- **cuando** registra estas características,
- **entonces** el sistema las guarda correctamente.
- **Criterios de aceptación:**
  - Se registran nivel de atención, seguimiento de instrucciones, forma de aprendizaje y dificultades.
  - Estos datos alimentan el estimador RF27.
- **Caso de prueba:** CP-07

### RF08 — Registrar entorno de aprendizaje
- **Dimensión:** Funcionalidad
- **Historia de usuario:** Como padre o tutor, quiero registrar las condiciones del entorno de aprendizaje del niño.
- **Dado que** el usuario avanzó a la sección de entorno,
- **cuando** ingresa la información del entorno,
- **entonces** el sistema la guarda.
- **Criterios de aceptación:**
  - Se registran las condiciones del espacio de estudio.
  - Alimenta la dimensión "organización del entorno de aprendizaje" de la variable Y.
- **Caso de prueba:** CP-08

### RF09 — Registrar distractores y factores de concentración
- **Dimensión:** Funcionalidad
- **Historia de usuario:** Como padre o tutor, quiero registrar los principales distractores y dificultades de concentración del niño.
- **Dado que** el usuario está en la sección de entorno y aprendizaje,
- **cuando** registra los distractores,
- **entonces** el sistema los almacena.
- **Criterios de aceptación:**
  - Se registran distractores y factores que dificultan la concentración.
  - Alimenta las sugerencias de organización del entorno.
- **Caso de prueba:** CP-09

### RF10 — Registrar lugar de estudio, rutinas y pausas
- **Dimensión:** Funcionalidad
- **Historia de usuario:** Como padre o tutor, quiero registrar el lugar habitual de estudio, las rutinas y la necesidad de pausas.
- **Dado que** el usuario está en la sección de entorno y aprendizaje,
- **cuando** registra el lugar, las rutinas y las pausas,
- **entonces** el sistema guarda la información.
- **Criterios de aceptación:**
  - Se registran lugar, rutinas y necesidad de pausas.
  - Alimenta las sugerencias de pausas activas (RF15).
- **Caso de prueba:** CP-10

### RF11 — Registrar intereses y actividades motivadoras
- **Dimensión:** Funcionalidad
- **Historia de usuario:** Como padre o tutor, quiero registrar los intereses de mi hijo para que las actividades recomendadas consideren lo que le motiva.
- **Dado que** el usuario está en la etapa de intereses y resumen,
- **cuando** registra los intereses,
- **entonces** el sistema los guarda.
- **Criterios de aceptación:**
  - Se registran intereses y actividades motivadoras.
  - Alimenta la personalización de sugerencias (RF13).
- **Caso de prueba:** CP-11

### RF12 — Consultar y actualizar el perfil de aprendizaje
- **Dimensión:** Usabilidad (UA2) y Funcionalidad
- **Historia de usuario:** Como padre o tutor, quiero consultar y actualizar el perfil de aprendizaje para mantener su información vigente.
- **Dado que** el niño tiene un perfil registrado,
- **cuando** el usuario abre el módulo Perfil, modifica un dato y guarda,
- **entonces** el sistema actualiza y muestra el dato modificado.
- **Criterios de aceptación:**
  - El perfil se puede consultar por secciones.
  - Los cambios se reflejan en el motor de sugerencias.
- **Caso de prueba:** CP-12

---

## Módulo: Sugerencias de actividades

### RF13 — Generar sugerencias personalizadas
- **Dimensión:** Funcionalidad (FA1) e Interacción y personalización (IP1)
- **Historia de usuario:** Como padre o tutor, quiero recibir sugerencias educativas personalizadas según el perfil de mi hijo.
- **Dado que** existe un perfil de aprendizaje registrado,
- **cuando** el tutor solicita sugerencias,
- **entonces** el sistema presenta actividades relacionadas con las características del perfil.
- **Criterios de aceptación:**
  - Se consideran edad, atención, seguimiento de instrucciones, fatiga e intereses.
  - Se muestra el motivo de la selección.
- **Caso de prueba:** CP-13

### RF14 — Organizar actividades en las cinco áreas
- **Dimensión:** Funcionalidad
- **Historia de usuario:** Como padre o tutor, quiero visualizar las actividades organizadas por áreas de aprendizaje.
- **Dado que** el sistema tiene actividades en distintas áreas,
- **cuando** el tutor ingresa al apartado de actividades,
- **entonces** el sistema las muestra organizadas por área.
- **Criterios de aceptación:**
  - Cinco áreas: comprensión lectora, expresión escrita, razonamiento lógico, análisis y autonomía.
  - Cada actividad indica su área.
- **Caso de prueba:** CP-14

### RF15 — Incorporar pausas activas
- **Dimensión:** Funcionalidad
- **Historia de usuario:** Como padre o tutor, quiero contar con actividades de pausas activas.
- **Dado que** el tutor accede al apartado de actividades,
- **cuando** consulta las actividades complementarias,
- **entonces** el sistema muestra las pausas activas disponibles.
- **Criterios de aceptación:**
  - Las pausas activas se presentan como actividades complementarias.
- **Caso de prueba:** CP-15

### RF16 — Mostrar propósito, dificultad, duración, materiales y orientaciones
- **Dimensión:** Funcionalidad (FA1) y Usabilidad (UA3)
- **Historia de usuario:** Como padre o tutor, quiero consultar los detalles de cada sugerencia.
- **Dado que** se muestran sugerencias,
- **cuando** el tutor selecciona una,
- **entonces** el sistema presenta propósito, dificultad, duración, materiales y orientaciones.
- **Criterios de aceptación:**
  - Los cinco campos se muestran cuando hay información disponible.
- **Caso de prueba:** CP-16

### RF17 — Filtrar sugerencias por área
- **Dimensión:** Funcionalidad
- **Historia de usuario:** Como padre o tutor, quiero filtrar las sugerencias por área de aprendizaje.
- **Dado que** existen sugerencias en varias áreas,
- **cuando** el tutor selecciona un área,
- **entonces** el sistema muestra las sugerencias del área seleccionada.
- **Criterios de aceptación:**
  - El filtro se aplica sin recargar toda la pantalla.
- **Caso de prueba:** CP-17

---

## Módulo: Espacio de aprendizaje

### RF18 — Acceder a actividades dentro de la app
- **Dimensión:** Funcionalidad (FA2) e Interacción y personalización
- **Historia de usuario:** Como padre o tutor, quiero acceder a las actividades desde el aplicativo.
- **Dado que** el tutor visualiza una actividad disponible,
- **cuando** selecciona la actividad,
- **entonces** el sistema muestra el contenido o la funcionalidad para desarrollarla.
- **Criterios de aceptación:**
  - La actividad se abre dentro de la app.
- **Caso de prueba:** CP-18

### RF19 — Registrar actividades hechas en casa
- **Dimensión:** Funcionalidad (FA2)
- **Historia de usuario:** Como padre o tutor, quiero registrar las actividades realizadas fuera del aplicativo.
- **Dado que** el niño realizó una actividad con acompañamiento del tutor fuera de la app,
- **cuando** el tutor registra la realización,
- **entonces** el sistema guarda el registro.
- **Criterios de aceptación:**
  - El registro se asocia al niño y a la actividad.
- **Caso de prueba:** CP-19

### RF20 — Registrar resultados de las actividades
- **Dimensión:** Funcionalidad (FA2)
- **Historia de usuario:** Como padre o tutor, quiero registrar los resultados de las actividades realizadas.
- **Dado que** existe una actividad realizada,
- **cuando** el tutor ingresa el resultado,
- **entonces** el sistema lo guarda y lo asocia a la actividad.
- **Criterios de aceptación:**
  - El resultado queda disponible para el seguimiento familiar.
- **Caso de prueba:** CP-20

---

## Módulo: Seguimiento familiar

### RF21 — Consultar el historial de actividades
- **Dimensión:** Funcionalidad
- **Historia de usuario:** Como padre o tutor, quiero consultar el historial de actividades de mi hijo.
- **Dado que** existen actividades registradas,
- **cuando** el tutor ingresa a seguimiento familiar,
- **entonces** el sistema muestra el historial.
- **Criterios de aceptación:**
  - El historial está ordenado cronológicamente.
- **Caso de prueba:** CP-21

### RF22 — Ver indicadores y gráficas
- **Dimensión:** Funcionalidad
- **Historia de usuario:** Como padre o tutor, quiero visualizar indicadores y gráficos del seguimiento.
- **Dado que** el niño tiene registros suficientes,
- **cuando** el tutor consulta el seguimiento,
- **entonces** el sistema muestra indicadores y gráficos.
- **Criterios de aceptación:**
  - Los gráficos usan fl_chart.
  - Si no hay registros suficientes, se informa al usuario.
- **Caso de prueba:** CP-22

### RF23 — Filtrar por periodos
- **Dimensión:** Funcionalidad
- **Historia de usuario:** Como padre o tutor, quiero filtrar el seguimiento por periodos de tiempo.
- **Dado que** existen registros en distintos periodos,
- **cuando** el tutor selecciona un periodo,
- **entonces** el sistema muestra la información correspondiente.
- **Criterios de aceptación:**
  - El filtro afecta indicadores y gráficos.
- **Caso de prueba:** CP-23

---

## Módulo: Asistente

### RF24 — Acceder al asistente y hacer consultas
- **Dimensión:** Funcionalidad e Interacción y personalización
- **Historia de usuario:** Como padre o tutor, quiero contar con un asistente para realizar consultas sobre el aprendizaje de mi hijo.
- **Dado que** el tutor tiene acceso al módulo del asistente,
- **cuando** ingresa una consulta,
- **entonces** el sistema muestra una respuesta relacionada.
- **Criterios de aceptación:**
  - El asistente responde a temas contemplados en sus reglas.
  - No diagnostica ni prescribe.
- **Caso de prueba:** CP-24

### RF25 — Recibir orientación en los tres ejes
- **Dimensión:** Funcionalidad (FA1)
- **Historia de usuario:** Como padre o tutor, quiero recibir orientación sobre acompañamiento académico, comunicación y motivación, y organización del entorno.
- **Dado que** el tutor accede al asistente,
- **cuando** consulta sobre estos temas,
- **entonces** el sistema presenta orientación relacionada.
- **Criterios de aceptación:**
  - Los tres ejes están cubiertos.
- **Caso de prueba:** CP-25

### RF26 — Respuestas con el contexto del perfil
- **Dimensión:** Interacción y personalización (IP1)
- **Historia de usuario:** Como padre o tutor, quiero que las orientaciones del asistente consideren las características de mi hijo.
- **Dado que** el niño tiene un perfil registrado,
- **cuando** el tutor realiza una consulta relacionada con sus características,
- **entonces** el asistente considera el perfil para responder.
- **Criterios de aceptación:**
  - El asistente usa el contexto del perfil.
  - Limitación documentada: el asistente usa reglas locales, no un modelo generativo externo.
- **Caso de prueba:** CP-26

---

## Módulo: Estimador

### RF27 — Estimar dificultad pedagógica
- **Dimensión:** Funcionalidad (FA1) e Interacción y personalización (IP1)
- **Historia de usuario:** Como padre o tutor, quiero que el aplicativo estime el nivel de dificultad pedagógica de mi hijo.
- **Dado que** el niño tiene información registrada sobre sus características,
- **cuando** el sistema procesa la información,
- **entonces** presenta una estimación del nivel de dificultad.
- **Criterios de aceptación:**
  - Considera edad, atención, seguimiento de instrucciones y fatiga.
  - Usa Random Forest (Scikit-learn) o, en su defecto, una regla heurística de respaldo.
  - La estimación es una referencia pedagógica, no una evaluación psicopedagógica.
- **Caso de prueba:** CP-27

---

## Trazabilidad resumida RF ↔ dimensión ↔ instrumento

| RF | Dimensión X | Ítem cuestionario | Instrumento |
|---|---|---|---|
| RF01, RF02 | Usabilidad | UA1, UA2 | Instr. 2 (postest) |
| RF02, RF12 | Usabilidad | UA2 | Instr. 2 (postest) |
| RF16, RF25, RF26 | Usabilidad | UA3 | Instr. 2 (postest) |
| RF13, RF14, RF27 | Funcionalidad | FA1 | Instr. 2 (postest) |
| RF14, RF15, RF18–RF20 | Funcionalidad | FA2 | Instr. 2 (postest) |
| RF01–RF27 | Funcionalidad | PCC, TE | Instr. 4 |
| RF12, RF26, RF27 | Interacción y personalización | IP1 | Instr. 2 (postest) |
| RF01, RF02 | Interacción y personalización | FU | Instr. 3 (logs) |
| Uso general | Interacción y personalización | TPP | Instr. 3 (logs) |

## Trazabilidad RF ↔ dimensión Y (apoyo parental)

| Dimensión Y | Ítems | RF que ayudan a fortalecerla |
|---|---|---|
| Acompañamiento académico | AA1–AA3 | RF13–RF20 |
| Comunicación y motivación | CM1–CM3 | RF24–RF26 |
| Organización del entorno de aprendizaje | OE1–OE3 | RF08–RF10, RF15, RF25 |
