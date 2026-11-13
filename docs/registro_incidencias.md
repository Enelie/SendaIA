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
