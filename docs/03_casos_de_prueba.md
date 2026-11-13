# 03 — Casos de prueba (Instrumento 4)

Este documento contiene los 27 casos de prueba (CP-01 a CP-27) del **Instrumento 4: lista de cotejo, casos de prueba y registro de incidencias**. Hay un caso por cada requerimiento funcional de [01_requerimientos.md](01_requerimientos.md).

Con estos casos se calculan:

- **PCC = (CC / CT) × 100**: porcentaje de casos que cumplen. **CC** son los casos con resultado *Cumple* y **CT** el total de casos (27).
- **TE = (E / O) × 100**: tasa de error. **E** son las operaciones con error registradas durante las pruebas y **O** el total de operaciones registradas (casos de prueba ejecutados + operaciones manuales registradas).

Los casos se ejecutan en dos momentos: **E1, antes de la intervención** (validación técnica) y **E2, durante la intervención**.

---

## Criterios de registro

- Un caso es **Cumple** solo si se verifican **todos** sus criterios de verificación. Si falla uno, es **No cumple** y se abre una incidencia en [registro_incidencias.md](registro_incidencias.md).
- Cada paso ejecutado (cada "Cuando") cuenta como **una operación** (O). Si una operación falla, cuenta como **un error** (E).
- Las operaciones manuales que no forman parte de un caso (por ejemplo, el uso real durante la intervención en que se observa un fallo) se anotan en la tabla de la §3 y también suman a O.
- Se registran el dispositivo, la versión de Android y la versión de la app (`version_app`, p. ej. `2.3.0+1`).

### Datos de prueba comunes

| Dato | Valor |
|---|---|
| Cuenta de padre de prueba | Una cuenta `padre_tutor` creada para la prueba (no una de los participantes) |
| Niño de prueba A | Nombre "Niño Prueba A", fecha de nacimiento 2018-05-10 |
| Niño de prueba B | Nombre "Niño Prueba B", fecha de nacimiento 2019-09-21 |
| Contraseña inválida | Una contraseña distinta de la registrada |

---

## 1. Casos de prueba

### Módulo Acceso

#### CP-01 — Registrarse e iniciar sesión (RF01)
- **Dado que** el padre está en la pantalla de acceso y no tiene cuenta,
- **cuando** (1) completa el formulario de registro, (2) cierra sesión, (3) inicia sesión con las credenciales correctas y (4) intenta iniciar sesión con una contraseña incorrecta,
- **entonces** el sistema crea la cuenta, concede el acceso con credenciales válidas y lo rechaza con credenciales inválidas.
- **Criterios de verificación:**
  - [ ] Con credenciales válidas se accede al aplicativo.
  - [ ] Con credenciales inválidas aparece un mensaje de error que **no indica qué campo falló** (correo o contraseña).
  - [ ] En `usuarios.password_hash` la contraseña está guardada con bcrypt (prefijo `$2b$`), no en texto plano.
  - [ ] Al cerrar y volver a abrir la app sin hacer logout, la sesión se mantiene (JWT en Flutter Secure Storage).

#### CP-02 — Acceder al panel familiar (RF02)
- **Dado que** el padre inició sesión correctamente,
- **cuando** (1) se carga la pantalla principal y (2) se intenta abrir el panel sin sesión (después de un logout),
- **entonces** se muestra el panel familiar con sus accesos, y sin sesión válida se redirige al login.
- **Criterios de verificación:**
  - [ ] El panel muestra el resumen del perfil del niño.
  - [ ] Hay accesos visibles a perfil, sugerencias, seguimiento y asistente.
  - [ ] Sin sesión válida no se puede ver el panel.

### Módulo Registro del niño

#### CP-03 — Registrar uno o varios niños (RF03)
- **Dado que** el padre está en el panel familiar,
- **cuando** (1) registra al Niño Prueba A y (2) registra al Niño Prueba B,
- **entonces** ambos niños quedan guardados y asociados a su cuenta.
- **Criterios de verificación:**
  - [ ] Los dos niños aparecen en el panel del mismo padre.
  - [ ] En la base de datos, ambos tienen el mismo `tutor_id` (cada niño pertenece a un solo tutor).
  - [ ] El registro pide el consentimiento informado y queda una fila en `consentimientos_informados` por cada niño.

#### CP-04 — Registrar datos básicos del niño (RF04)
- **Dado que** el padre inició el registro de un niño,
- **cuando** (1) intenta guardar sin nombre, (2) intenta guardar con una fecha de nacimiento futura y (3) guarda con nombre y fecha válidos,
- **entonces** el sistema rechaza los dos primeros intentos y guarda el tercero.
- **Criterios de verificación:**
  - [ ] Sin nombre o sin fecha de nacimiento no se permite guardar.
  - [ ] Con fecha de nacimiento futura no se permite guardar.
  - [ ] Con datos válidos el niño queda guardado.

#### CP-05 — Registrar diagnóstico previo de TDAH (opcional) (RF05)
- **Dado que** el padre está completando los datos básicos,
- **cuando** (1) registra un niño **sin** indicar diagnóstico y (2) registra otro indicando que **sí** tiene diagnóstico previo de TDAH,
- **entonces** ambos registros se guardan.
- **Criterios de verificación:**
  - [ ] El campo de diagnóstico es opcional: el registro sin diagnóstico se guarda.
  - [ ] El diagnóstico indicado queda guardado como antecedente.
  - [ ] En ningún momento el sistema infiere, sugiere ni muestra un diagnóstico o nivel de riesgo.

#### CP-06 — Registrar características de aprendizaje (RF06)
- **Dado que** se registraron los datos básicos del niño,
- **cuando** el padre completa la etapa 2 del formulario (perfil de aprendizaje) y guarda,
- **entonces** el sistema almacena las características.
- **Criterios de verificación:**
  - [ ] Las características se registran en la etapa 2 del formulario.
  - [ ] Al volver a abrir el perfil, los datos guardados aparecen.
  - [ ] Los datos están disponibles para las sugerencias (se verifica en CP-13).

#### CP-07 — Registrar atención, instrucciones, forma de aprendizaje y dificultades (RF07)
- **Dado que** el padre está en la sección de perfil de aprendizaje,
- **cuando** registra nivel de atención, seguimiento de instrucciones, forma de aprendizaje y dificultades, y guarda,
- **entonces** los cuatro datos quedan guardados.
- **Criterios de verificación:**
  - [ ] Se guardan los cuatro datos.
  - [ ] Cambiar el nivel de atención o el seguimiento de instrucciones cambia la estimación de RF27 (se verifica en CP-27).

#### CP-08 — Registrar entorno de aprendizaje (RF08)
- **Dado que** el padre avanzó a la sección de entorno,
- **cuando** registra las condiciones del espacio de estudio y guarda,
- **entonces** la información queda guardada.
- **Criterios de verificación:**
  - [ ] Las condiciones del espacio de estudio se guardan y se ven al volver a abrir el perfil.

#### CP-09 — Registrar distractores y factores de concentración (RF09)
- **Dado que** el padre está en la sección de entorno y aprendizaje,
- **cuando** registra al menos dos distractores y guarda,
- **entonces** el sistema los almacena.
- **Criterios de verificación:**
  - [ ] Los distractores se guardan.
  - [ ] Las sugerencias de organización del entorno reflejan los distractores registrados.

#### CP-10 — Registrar lugar de estudio, rutinas y pausas (RF10)
- **Dado que** el padre está en la sección de entorno y aprendizaje,
- **cuando** registra el lugar habitual de estudio, una rutina y la necesidad de pausas, y guarda,
- **entonces** la información queda guardada.
- **Criterios de verificación:**
  - [ ] Se guardan el lugar, las rutinas y la necesidad de pausas.
  - [ ] Si se indica necesidad de pausas, se ofrecen pausas activas (se verifica en CP-15).

#### CP-11 — Registrar intereses y actividades motivadoras (RF11)
- **Dado que** el padre está en la etapa de intereses y resumen,
- **cuando** registra al menos dos intereses y guarda,
- **entonces** el sistema los guarda.
- **Criterios de verificación:**
  - [ ] Los intereses se guardan.
  - [ ] Los intereses influyen en las sugerencias (se verifica en CP-13).

#### CP-12 — Consultar y actualizar el perfil de aprendizaje (RF12)
- **Dado que** el niño tiene un perfil registrado,
- **cuando** (1) el padre abre el módulo Perfil, (2) modifica un dato y (3) guarda,
- **entonces** el sistema actualiza y muestra el dato modificado.
- **Criterios de verificación:**
  - [ ] El perfil se puede consultar por secciones.
  - [ ] Después de guardar se muestra el dato modificado, también tras cerrar y volver a abrir la app.
  - [ ] Las sugerencias cambian de acuerdo con el dato modificado.

### Módulo Sugerencias de actividades

#### CP-13 — Generar sugerencias personalizadas (RF13)
- **Dado que** existe un perfil de aprendizaje registrado,
- **cuando** (1) el padre solicita sugerencias y (2) cambia en el perfil el nivel de atención o un interés y vuelve a solicitarlas,
- **entonces** el sistema presenta actividades relacionadas con el perfil y estas cambian con él.
- **Criterios de verificación:**
  - [ ] Las sugerencias consideran edad, atención, seguimiento de instrucciones, fatiga e intereses.
  - [ ] Cada sugerencia muestra el motivo por el que fue seleccionada.
  - [ ] Al cambiar el perfil, cambian las sugerencias.

#### CP-14 — Organizar actividades en las cinco áreas (RF14)
- **Dado que** hay actividades en distintas áreas,
- **cuando** el padre ingresa al apartado de actividades,
- **entonces** las actividades se muestran organizadas por área.
- **Criterios de verificación:**
  - [ ] Aparecen las cinco áreas: comprensión lectora, expresión escrita, razonamiento lógico, análisis y autonomía.
  - [ ] Cada actividad indica su área.

#### CP-15 — Incorporar pausas activas (RF15)
- **Dado que** el padre accede al apartado de actividades,
- **cuando** consulta las actividades complementarias,
- **entonces** el sistema muestra las pausas activas disponibles.
- **Criterios de verificación:**
  - [ ] Las pausas activas aparecen como actividades complementarias.

#### CP-16 — Mostrar detalles de cada sugerencia (RF16)
- **Dado que** se muestran sugerencias,
- **cuando** el padre selecciona una,
- **entonces** el sistema presenta su propósito, dificultad, duración, materiales y orientaciones.
- **Criterios de verificación:**
  - [ ] Se muestran los cinco campos cuando la actividad tiene esa información.
  - [ ] Si falta un campo, la pantalla no muestra errores ni valores vacíos sin etiqueta.

#### CP-17 — Filtrar sugerencias por área (RF17)
- **Dado que** existen sugerencias en varias áreas,
- **cuando** el padre selecciona un área,
- **entonces** el sistema muestra solo las sugerencias de esa área.
- **Criterios de verificación:**
  - [ ] Solo aparecen sugerencias del área seleccionada.
  - [ ] El filtro se aplica sin recargar toda la pantalla.

### Módulo Espacio de aprendizaje

#### CP-18 — Acceder a actividades dentro de la app (RF18)
- **Dado que** el padre ve una actividad disponible,
- **cuando** la selecciona,
- **entonces** el sistema muestra su contenido o la funcionalidad para desarrollarla.
- **Criterios de verificación:**
  - [ ] La actividad se abre dentro de la app, sin enviar a un navegador externo.

#### CP-19 — Registrar actividades hechas en casa (RF19)
- **Dado que** el niño hizo una actividad fuera de la app con acompañamiento del padre,
- **cuando** el padre registra que la realizó,
- **entonces** el sistema guarda el registro.
- **Criterios de verificación:**
  - [ ] El registro queda asociado al niño y a la actividad.
  - [ ] Si el registro se hace **sin conexión**, se guarda en el celular y se sincroniza al recuperar la red.

#### CP-20 — Registrar resultados de las actividades (RF20)
- **Dado que** existe una actividad realizada,
- **cuando** el padre ingresa el resultado,
- **entonces** el sistema lo guarda y lo asocia a la actividad.
- **Criterios de verificación:**
  - [ ] El resultado queda asociado a la actividad.
  - [ ] El resultado aparece en el seguimiento familiar (se verifica en CP-21).

### Módulo Seguimiento familiar

#### CP-21 — Consultar el historial de actividades (RF21)
- **Dado que** hay al menos tres actividades registradas en fechas distintas,
- **cuando** el padre ingresa a seguimiento familiar,
- **entonces** el sistema muestra el historial.
- **Criterios de verificación:**
  - [ ] El historial está ordenado cronológicamente.
  - [ ] Aparecen las actividades registradas en CP-19 y CP-20.

#### CP-22 — Ver indicadores y gráficas (RF22)
- **Dado que** el niño tiene registros suficientes,
- **cuando** (1) el padre consulta el seguimiento y (2) consulta el seguimiento de un niño **sin** registros,
- **entonces** el sistema muestra indicadores y gráficas en el primer caso y un aviso en el segundo.
- **Criterios de verificación:**
  - [ ] Se muestran indicadores y gráficas (fl_chart).
  - [ ] Sin registros suficientes, se informa al usuario en lugar de mostrar una gráfica vacía o un error.

#### CP-23 — Filtrar por periodos (RF23)
- **Dado que** hay registros en distintos periodos,
- **cuando** el padre selecciona un periodo,
- **entonces** el sistema muestra la información de ese periodo.
- **Criterios de verificación:**
  - [ ] El filtro afecta a los indicadores.
  - [ ] El filtro afecta a las gráficas.

### Módulo Asistente

#### CP-24 — Acceder al asistente y hacer consultas (RF24)
- **Dado que** el padre tiene acceso al asistente,
- **cuando** (1) hace una consulta sobre un tema contemplado y (2) pide un diagnóstico o una medicación,
- **entonces** el sistema responde a la primera y se niega a diagnosticar o prescribir en la segunda.
- **Criterios de verificación:**
  - [ ] Responde a los temas contemplados en sus reglas.
  - [ ] No diagnostica ni prescribe; ante esas consultas, orienta a un profesional.

#### CP-25 — Orientación en los tres ejes (RF25)
- **Dado que** el padre accede al asistente,
- **cuando** consulta sobre (1) acompañamiento académico, (2) comunicación y motivación y (3) organización del entorno,
- **entonces** el sistema presenta orientación para cada tema.
- **Criterios de verificación:**
  - [ ] Hay orientación para acompañamiento académico.
  - [ ] Hay orientación para comunicación y motivación.
  - [ ] Hay orientación para organización del entorno.

#### CP-26 — Respuestas con el contexto del perfil (RF26)
- **Dado que** el niño tiene un perfil registrado,
- **cuando** el padre hace la misma consulta para dos niños con perfiles distintos (Niño Prueba A y B),
- **entonces** el asistente adapta la respuesta al perfil de cada niño.
- **Criterios de verificación:**
  - [ ] La respuesta usa el contexto del perfil (difiere entre los dos niños o menciona una característica registrada).
  - [ ] Está documentada la limitación: el asistente usa reglas locales, no un modelo generativo externo.

### Módulo Estimador

#### CP-27 — Estimar dificultad pedagógica (RF27)
- **Dado que** el niño tiene información registrada sobre sus características,
- **cuando** (1) el sistema procesa el perfil y (2) se cambian la atención o la fatiga y se vuelve a procesar,
- **entonces** se presenta una estimación del nivel de dificultad que responde a esos cambios.
- **Criterios de verificación:**
  - [ ] La estimación considera edad, atención, seguimiento de instrucciones y fatiga.
  - [ ] Usa el modelo Random Forest; si no está disponible, la regla heurística de respaldo, sin errores visibles.
  - [ ] La pantalla indica que es una referencia pedagógica, no una evaluación psicopedagógica.

---

## 2. Lista de cotejo y cálculo de PCC

Se marca **C** (Cumple) o **NC** (No cumple) en cada ejecución. En la columna *Incidencia* se anota el ID del registro de incidencias cuando el resultado es NC.

| CP | RF | Requerimiento | E1 (antes) | E2 (durante) | Incidencia |
|---|---|---|---|---|---|
| CP-01 | RF01 | Registrarse e iniciar sesión | | | |
| CP-02 | RF02 | Acceder al panel familiar | | | |
| CP-03 | RF03 | Registrar uno o varios niños | | | |
| CP-04 | RF04 | Datos básicos del niño | | | |
| CP-05 | RF05 | Diagnóstico previo de TDAH (opcional) | | | |
| CP-06 | RF06 | Características de aprendizaje | | | |
| CP-07 | RF07 | Atención, instrucciones, forma de aprendizaje, dificultades | | | |
| CP-08 | RF08 | Entorno de aprendizaje | | | |
| CP-09 | RF09 | Distractores y concentración | | | |
| CP-10 | RF10 | Lugar de estudio, rutinas y pausas | | | |
| CP-11 | RF11 | Intereses y actividades motivadoras | | | |
| CP-12 | RF12 | Consultar y actualizar perfil | | | |
| CP-13 | RF13 | Sugerencias personalizadas | | | |
| CP-14 | RF14 | Cinco áreas | | | |
| CP-15 | RF15 | Pausas activas | | | |
| CP-16 | RF16 | Detalles de la sugerencia | | | |
| CP-17 | RF17 | Filtrar por área | | | |
| CP-18 | RF18 | Actividades dentro de la app | | | |
| CP-19 | RF19 | Actividades hechas en casa | | | |
| CP-20 | RF20 | Resultados de actividades | | | |
| CP-21 | RF21 | Historial de actividades | | | |
| CP-22 | RF22 | Indicadores y gráficas | | | |
| CP-23 | RF23 | Filtrar por periodos | | | |
| CP-24 | RF24 | Asistente y consultas | | | |
| CP-25 | RF25 | Orientación en los tres ejes | | | |
| CP-26 | RF26 | Respuestas con contexto del perfil | | | |
| CP-27 | RF27 | Estimador de dificultad | | | |
| | | **CC (casos con C)** | | | |
| | | **CT** | 27 | 27 | |
| | | **PCC = (CC / CT) × 100** | % | % | |

---

## 3. Registro de operaciones y cálculo de TE

Una fila por operación (cada paso "Cuando" de los casos, más las operaciones manuales). **Resultado:** OK o Error. Cada Error debe tener una incidencia del tipo *Error observado*.

| N.º | Fecha | Ejecución (E1/E2) | CP u operación manual | Paso | Resultado | Incidencia |
|---|---|---|---|---|---|---|
| 1 | | | | | | |
| 2 | | | | | | |
| … | | | | | | |

| Ejecución | O (operaciones registradas) | E (operaciones con error) | TE = (E / O) × 100 |
|---|---|---|---|
| E1 (antes) | | | % |
| E2 (durante) | | | % |

---

## 4. Registro de incidencias

El detalle de cada incidencia se lleva en [registro_incidencias.md](registro_incidencias.md), con campos de ID, fecha, tipo, RF, componente, descripción, severidad, estado y operación. Resumen:

| ID | Fecha | Tipo | RF | Severidad | Estado | ¿Suma a E? |
|---|---|---|---|---|---|---|
| INC-001 | 2026-11-13 | Riesgo latente | Ninguno en la versión actual | Media | Cerrada | No |

**Regla:** solo las incidencias de tipo *Error observado* (una operación que se ejecutó y falló) suman a **E**. Un *Riesgo latente* encontrado en una revisión de código se registra, pero no suma a E mientras no se reproduzca en una operación.
