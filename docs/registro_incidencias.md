# Registro de incidencias

Forma parte del **Instrumento 4** (lista de cotejo, casos de prueba y registro de incidencias), que calcula:

- **TE = (E / O) × 100**, donde **E** son las operaciones con error registradas durante las pruebas y **O** el total de operaciones registradas (casos de prueba ejecutados más operaciones manuales registradas).

**Criterio de conteo.** Solo suman a **E** las incidencias de tipo *Error observado*, es decir, una operación que se ejecutó y falló. Un *Riesgo latente* detectado en una revisión de código se registra para su seguimiento, pero **no suma a E** mientras no se reproduzca en una operación. Si se reproduce, se registra como *Error observado* y se enlaza con el riesgo original.

| Campo | Contenido |
|---|---|
| ID | INC-NNN |
| Fecha | Fecha de detección (AAAA-MM-DD) |
| Tipo | Error observado \| Riesgo latente |
| RF | Requerimiento funcional afectado (RF01–RF27) |
| Componente | Archivo o módulo |
| Descripción | Qué ocurre o puede ocurrir |
| Severidad | Alta \| Media \| Baja |
| Estado | Abierta \| En corrección \| Cerrada |
| Operación | Caso de prueba u operación en que se observó (solo para errores observados) |

---

## INC-001: dos clases SQLite abren el mismo archivo con versiones distintas

| Campo | Contenido |
|---|---|
| Fecha | 2026-11-13 |
| Tipo | **Riesgo latente** (detectado en revisión de código; no observado en ejecución). **No suma a E.** |
| RF | **Ninguno en la versión actual.** Ver la verificación más abajo. |
| Componente | `sendaia_app/lib/adapters/output/sqlite_local_database.dart` (`SQLiteLocalDatabase`, versión **1**), frente a `sqlite_db_repository.dart` (`SqliteDbRepository`, versión **3**) |
| Severidad | Media |
| Estado | **Cerrada** (2026-11-13): se eliminó el código muerto |

**Descripción.** Ambas clases abrían `rimai_offline.db` con números de versión distintos (3 y 1) y cada una tenía sus propios `onCreate` y `onUpgrade`:

1. `main.dart` abre siempre primero `SqliteDbRepository`, así que el archivo se crea por su `onCreate`. La tabla `patient_profiles_queue`, que solo creaba el `onCreate` de `SQLiteLocalDatabase`, **nunca llegaba a existir**. Si se hubiera usado `SQLiteLocalDatabase.queuePatientProfile()`, habría fallado con *no such table*.
2. Si `SQLiteLocalDatabase` abría el archivo con la versión 1, sqflite lo trataba como una degradación de versión, y la versión del esquema podía alternar entre 1 y 3.

**Verificación de RF afectados (con `docs/01_requerimientos.md`).** Se revisó si el riesgo alcanzaba a RF03 (registrar niños), RF04 (datos básicos) o RF12 (consultar y actualizar perfil):

- El único consumidor de `SQLiteLocalDatabase` era `ApiPatientRepository` (cola offline del perfil clínico). **Esa clase no se instanciaba en ninguna parte de la app**, y su único caso de uso posible (`SubmitClinicalProfileUsecase`) tampoco se usa.
- Además, `ApiPatientRepository` enviaba a `/api/v1/pacientes/perfil-clinico`, pero el backend expone el prefijo `/api/v1/perfiles`: el endpoint no existe.
- RF03, RF04 y RF12 se implementan por otro camino: `dashboard_providers.dart` → `POST`/`PUT /api/dashboard/familia/paciente`, en línea y sin SQLite.

Conclusión: **ningún RF implementado pasaba por el código afectado.** El código muerto correspondía a un flujo alternativo de envío offline del perfil (temáticamente cercano a RF04 y RF06–RF12) que nunca se conectó. Por eso la incidencia no afecta a PCC ni a TE.

**Resolución.** Se eliminaron `sqlite_local_database.dart` (con la tabla `patient_profiles_queue`) y `api_patient_repository.dart`. La tabla no aparecía en ninguna migración del backend ni en otro modelo. Ahora `SqliteDbRepository` es la única clase que abre `rimai_offline.db`; su `onUpgrade` usa DDL idempotente (`CREATE TABLE IF NOT EXISTS`) y en la versión 3 incorporó `logs_uso_local` (Instrumento 3).

**Código muerto que queda (sin riesgo, pendiente de decisión).** `lib/application/ports/patient_port.dart` y `lib/application/usecases/submit_clinical_profile_usecase.dart` ya no tienen ningún adaptador ni consumidor.

---

## INC-002: `origen_registro` marca como offline todas las sesiones de la app familiar

| Campo | Contenido |
|---|---|
| Fecha | 2026-11-13 |
| Tipo | **Riesgo latente** (detectado en revisión de código; no observado en ejecución). **No suma a E.** |
| RF | **Ninguno.** `origen_registro` no forma parte de los 27 RF ni de los instrumentos de recolección de datos. |
| Componente | `sendaia_app/lib/core/providers/pmv2_providers.dart` (`SesionService.guardarResultadoActividad`) y `backend/app/adapters/inbound/api/dashboard_controller.py` (registro de sesiones en `POST /api/sesiones`) |
| Severidad | Baja |
| Estado | **Abierta** (se propone corregir en una versión futura) |

**Descripción.** El backend asigna `origen_registro = 'familia_app_offline'` a toda sesión que llega con `client_event_id`, y `'familia_app'` a las que llegan sin él. Pero la app familiar genera un `client_event_id` para cada resultado y lo envía siempre, también cuando hay conexión y el resultado se guarda en línea. En consecuencia, todas las sesiones registradas desde la app quedan marcadas como `familia_app_offline` y el campo no permite distinguir los registros hechos sin conexión de los hechos en línea.

**Impacto.** Ninguno sobre los RF ni sobre los indicadores de la tesis. El `client_event_id` cumple bien su función (evitar duplicados al sincronizar); solo la etiqueta de origen es incorrecta.

**Corrección propuesta.** Que el cliente indique explícitamente si el envío viene de la cola local (por ejemplo, un campo `desde_cola_offline`) y que el backend asigne `origen_registro` a partir de ese dato y no de la presencia del `client_event_id`.

---

## INC-003: el estimador de dificultad no cumple RF27

| Campo | Contenido |
|---|---|
| Fecha | 2026-11-14 |
| Tipo | **Riesgo latente** (detectado en revisión de código; no observado en ejecución). **No suma a E** hasta que CP-27 se ejecute y falle. |
| RF | **RF27** (estimar dificultad pedagógica). Afecta también a un criterio de CP-07 (RF07) y a uno de CP-13 (RF13). |
| Componente | `backend/app/ai/motor.py` (`MotorAdaptativoRandomForest`), `backend/scripts/train_model.py` y `backend/app/adapters/inbound/api/dashboard_controller.py` (`POST /api/dashboard/paciente/{nino_id}/plan/generar`) |
| Severidad | Alta |
| Estado | **Abierta** |
| Operación | CP-27, CP-07 y CP-13 (fallarán en E1) |

**Descripción.** RF27 no se cumple: el estimador usa variables distintas a las del requerimiento y no expone la estimación al padre. CP-27, CP-07 y CP-13 fallarán en E1.

- RF27 (`docs/01_requerimientos.md`) pide que la estimación considere **edad, atención, seguimiento de instrucciones y fatiga**. El Random Forest (`rf_dificultad.pkl`) usa **edad, nivel cognitivo, número de características del perfil sensorial y número de objetivos de intervención**. El número de características suma campos heredados del enfoque TEA (hipersensibilidad, hiposensibilidad, comportamientos repetitivos e intereses intensos).
- El modelo solo se ejecuta cuando el **terapeuta** genera el plan; su resultado fija el nivel de dificultad inicial del plan. El padre no ve la estimación ni el aviso de que es una referencia pedagógica.
- El otro estimador del backend (`AISupportUseCases.estimate_support_level`) tampoco usa atención, seguimiento de instrucciones ni fatiga.

**Criterios que fallarán.**

- CP-27: "La estimación considera edad, atención, seguimiento de instrucciones y fatiga" y "La pantalla indica que es una referencia pedagógica".
- CP-07: "Cambiar el nivel de atención o el seguimiento de instrucciones cambia la estimación de RF27".
- CP-13: "Las sugerencias consideran edad, atención, seguimiento de instrucciones, fatiga e intereses" (RF13 tampoco está implementado en la versión evaluada).

**Tratamiento.** Se mantiene RF27 tal como está definido y se documenta como limitación conocida (sección 8.11 de `docs/documentacion_tecnica.md`). La corrección propuesta para una versión futura es reentrenar el estimador con las variables que pide RF27 (edad, atención, seguimiento de instrucciones y fatiga) y mostrar la estimación al padre con el aviso de referencia pedagógica.

---

## INC-004: RF13, RF14, RF15 y RF17 no están implementados

| Campo | Contenido |
|---|---|
| Fecha | 2026-11-14 |
| Tipo | **Riesgo latente** (no observado en ejecución; se observará cuando se ejecuten CP-13, CP-14, CP-15 y CP-17 en E1). **No suma a E** hasta entonces. |
| RF | **RF13, RF14, RF15 y RF17** |
| Componente | Módulo de sugerencias de actividades de la app familiar (`sendaia_app`) y su backend |
| Severidad | Alta (afecta al PCC) |
| Estado | **Abierta** |
| Operación | CP-13, CP-14, CP-15 y CP-17 (fallarán en E1) |

**Descripción.** Las sugerencias personalizadas, la organización en cinco áreas, las pausas activas y el filtro por área no están implementados en la versión evaluada. CP-13, CP-14, CP-15 y CP-17 fallarán en E1.

RF16 (detalles de la actividad: propósito, dificultad, duración y materiales) sí está implementado y no forma parte de esta incidencia.

**Tratamiento.** Se mantienen los RF y se documentan como limitación en 8.11. Corrección propuesta para una versión futura: implementar las cuatro funcionalidades.
