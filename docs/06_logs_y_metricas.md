# 06 — Logs de uso y métricas del Instrumento 3

Este documento describe cómo SENDAIA registra el uso del aplicativo y cómo se obtienen los indicadores de la **ficha de registro de uso (Instrumento 3)** de la tesis *"Implementación de un aplicativo móvil con IA para fortalecer el apoyo parental en el aprendizaje de niños con TDAH del Centro Colibrí, 2026"*.

También registra las decisiones de diseño y las limitaciones que deben declararse en la tesis (secciones 3.6 y 8.10).

---

## 1. Indicadores

| Símbolo | Definición operativa | Dónde se obtiene |
|---|---|---|
| **N** | Número de accesos del participante durante la intervención. Un acceso es un registro en `logs_uso` cuya `fecha_hora_ingreso` cae dentro de la ventana de la intervención. | Conteo en la exportación |
| **S** | Número de semanas de intervención = **8**. | Parámetro `semanas` |
| **FU** | Frecuencia de uso = **N / S** (accesos por semana). | Columna `FU` |
| **T** | Duración de un acceso, en minutos = `fecha_hora_salida − fecha_hora_ingreso`. | Columna `tiempo_permanencia_min`, calculada por PostgreSQL |
| **ΣT** | Suma de las T del participante. | Columna `sum_T_min` |
| **TPP** | Tiempo de permanencia promedio = **ΣT / N** (minutos por acceso). | Columna `TPP_min` |

**Ventana de la intervención:** desde las 00:00 del día `fecha_inicio` hasta las 00:00 del día `fecha_inicio + 7·S`, en hora de Lima. El inicio se incluye y el fin no. Con S = 8 son exactamente 56 días.

---

## 2. Qué cuenta como acceso

El registro lo hace `UsageSessionTracker`, en [sendaia_app/lib/application/services/usage_session_tracker.dart](../sendaia_app/lib/application/services/usage_session_tracker.dart).

| Evento en el celular | Efecto en el registro |
|---|---|
| Inicio de sesión (o registro) exitoso | Se **abre** un acceso. |
| Abrir la app o volver a ella con una sesión válida (token no expirado) | Se **abre** un acceso, salvo que aplique el período de gracia. |
| La app pasa a segundo plano (otra app, pantalla apagada) | El acceso se **cierra de forma provisional** (`tipo_cierre = segundo_plano`). |
| El padre vuelve **antes de 5 minutos** | Se **reabre el mismo acceso**: no suma a N. |
| El padre vuelve **después de 5 minutos** | El acceso anterior queda cerrado en el momento en que salió y se abre uno nuevo. |
| Bajar la barra de notificaciones, diálogo del sistema | No afecta (estados `inactive` y `hidden`). |
| Cerrar sesión (logout) | El acceso se **cierra** (`tipo_cierre = logout`). |
| La app se cerró a la fuerza o falló con un acceso abierto | Al volver a abrirla, ese acceso se cierra con la hora del **último latido** (`tipo_cierre = recuperada`). |

Mientras la app está en primer plano se guarda un **latido** cada 60 s. Así, si la app se cierra de forma abrupta, la salida se estima con un error menor a 60 s.

**Solo se registra el rol `padre_tutor`.** Terapeutas y administradores (el investigador) no forman parte de la muestra.

---

## 3. Decisión de diseño: período de gracia de 5 minutos

**Decisión.** Si el padre deja la app y vuelve en 5 minutos o menos, se considera la misma sesión de uso.

**Justificación.** Sin período de gracia, salir 10 segundos a responder un mensaje y volver contaría como dos accesos. Eso **inflaría N** (y FU) y **subestimaría TPP** de forma artificial. Las herramientas estándar de analítica móvil agrupan la actividad del mismo modo: Google Analytics 4 y Firebase Analytics cierran una sesión tras **30 minutos** de inactividad. Se eligió **5 minutos** por ser un criterio más conservador y adecuado para una intervención educativa de sesiones cortas.

**Dónde se configura.** La constante `kPeriodoGraciaUso` está en [log_uso_local.dart](../sendaia_app/lib/domain/entities/log_uso_local.dart). No debe cambiarse durante la intervención: cambiarla altera la definición operativa de N.

**Limitación que se declara.** *"El período de gracia de 5 minutos puede agrupar en una sola sesión dos episodios de uso separados por una interrupción breve."*

---

## 4. Modelo de datos

La migración es [backend/sql/14_migration_log_uso.sql](../backend/sql/14_migration_log_uso.sql).

### `logs_uso`: una fila por acceso

| Columna | Tipo | Nota |
|---|---|---|
| `id` | UUID | PK |
| `client_event_id` | UUID, UNIQUE | Se genera en el celular. Un reenvío no duplica el acceso. |
| `usuario_id` | UUID → `usuarios` | `ON DELETE RESTRICT`: no se pueden perder datos del estudio por un borrado. |
| `rol_usuario` | VARCHAR(50) | |
| `fecha_hora_ingreso` / `fecha_hora_salida` | TIMESTAMPTZ | CHECK: salida ≥ ingreso. |
| `tiempo_permanencia_min` | NUMERIC(8,2) | **GENERATED ALWAYS AS … STORED**. T lo calcula la base de datos y no se puede escribir ni manipular desde el cliente. |
| `tipo_cierre` | VARCHAR(20) | `logout` \| `segundo_plano` \| `recuperada` |
| `plataforma`, `version_app` | VARCHAR(20) | Diagnóstico. `version_app` es `versión+build` de la app (p. ej. `2.3.0+1`), obtenida con `package_info_plus`; sirve para atribuir incidencias a una versión concreta. |
| `fecha_sync` | TIMESTAMPTZ | Momento en que llegó al servidor. Permite medir el retraso de las sesiones registradas sin conexión. |

Es una tabla **distinta de `logs_auditoria`**. Aquella registra cambios clínicos sobre entidades; esta registra sesiones de uso.

### `participantes_estudio`: seudonimización

| Columna | Nota |
|---|---|
| `codigo` | `P01`, `P02`, …; UNIQUE. |
| `usuario_id` | UNIQUE: **un código por padre**, aunque tenga varios hijos o consentimientos. |
| `consentimiento_id` | FK a `consentimientos_informados`: **nadie entra al estudio sin consentimiento**. |
| `activo` | `FALSE` = retirado del estudio (ver §6). |

No se usó una columna en `consentimientos_informados` porque esa tabla tiene una fila por niño y por evento de consentimiento. Un padre con dos hijos tendría dos filas y, por tanto, dos posibles códigos.

### `sp_registrar_log_uso`

Inserta un acceso y devuelve `insertado`, `duplicado` (mismo `client_event_id` y mismo usuario) o `conflicto` (el `client_event_id` ya pertenece a otro usuario). Rechaza:
- una salida anterior al ingreso;
- un ingreso más de 5 minutos en el futuro (tolerancia por el reloj del celular);
- una duración mayor a 12 horas;
- un usuario inexistente.

---

## 5. Flujo sin conexión: del celular al servidor

1. Cada cambio de estado del acceso se guarda **primero en SQLite**, en la tabla `logs_uso_local` de `SqliteDbRepository` (base local versión 3).
2. `SyncOfflineUsecase.sincronizarLogsUso()` sube los accesos cerrados de forma definitiva a `POST /api/v1/logs/uso/sync`, en lotes de hasta 200. Se ejecuta:
   - al abrir la app;
   - al recuperar la conexión;
   - al cerrar o reabrir un acceso;
   - antes del logout.
3. Los accesos en segundo plano que todavía están dentro del período de gracia **no se suben**, porque aún pueden reabrirse.
4. Según la respuesta del servidor:
   - **aceptados** (incluye duplicados): se borran del celular;
   - **rechazados**: se marcan y no se reintentan; cuentan como incidencias del Instrumento 4;
   - **sin respuesta o error**: quedan en la cola y se reintentan.
5. **El servidor toma `usuario_id` del JWT, nunca del cuerpo.** Por eso el celular solo sube los accesos del usuario del token actual. Si dos padres usan el mismo celular, los accesos pendientes de cada uno se suben cuando ese padre vuelve a iniciar sesión.

Esto es crítico para la validez del Instrumento 3: sin la cola local, los accesos hechos sin red se perderían y FU quedaría subestimado.

---

## 6. Participantes y criterio de retiro

### Asignación de códigos (una vez, antes de la intervención)

Desde la raíz del repo, en PowerShell:

1. Aplicar **solo** la migración 14. No se usa `apply_migrations.ps1` sobre una base existente, porque vuelve a ejecutar todo desde `01_init.sql`, que no es idempotente.
   ```powershell
   docker cp backend\sql\14_migration_log_uso.sql rimai_postgres:/tmp/14_migration_log_uso.sql
   docker exec rimai_postgres psql -U rimai_user -d rimai_db -v ON_ERROR_STOP=1 -f /tmp/14_migration_log_uso.sql
   ```
2. Ejecutar el script [backend/sql/seed_participantes_estudio.sql](../backend/sql/seed_participantes_estudio.sql):
   ```powershell
   docker cp backend\sql\seed_participantes_estudio.sql rimai_postgres:/tmp/seed_participantes_estudio.sql
   docker exec rimai_postgres psql -U rimai_user -d rimai_db -v ON_ERROR_STOP=1 -f /tmp/seed_participantes_estudio.sql
   ```
   Se usa `docker cp` + `-f` en lugar de `Get-Content | docker exec`, porque Windows PowerShell 5.1 recodifica la entrada y puede corromper caracteres no ASCII.
3. Revisar la tabla de correspondencia que imprime el script. Deben aparecer los 30 padres del Centro Colibrí, y solo ellos.

**El seed se ejecuta solo en la base que se usará durante la intervención.** Si se ejecuta en la base de desarrollo, asignará códigos a las cuentas de desarrollo que tengan consentimiento.

El script incluye a los usuarios `padre_tutor` activos que tienen al menos un consentimiento aceptado y no revocado, y excluye las cuentas de prueba `@rimai.dev`. Numera por fecha del primer consentimiento y continúa desde el código más alto ya asignado. **Es idempotente:** volver a ejecutarlo nunca cambia ni duplica un código.

La tabla de correspondencia (código ↔ persona) es confidencial. Solo debe estar en poder del investigador y no se incluye en ninguna exportación.

### Retiro

Un padre que abandona la investigación se marca así:
```sql
UPDATE participantes_estudio SET activo = FALSE WHERE codigo = 'P07';
```
Sus datos no se borran. La exportación lo excluye por defecto y lo incluye con `incluir_inactivos=true` (agrega la columna `activo`). Esto aplica el criterio de la tesis, *"se retirará del análisis a los participantes que abandonen la investigación"*, sin perder la trazabilidad.

---

## 7. Exportación: `GET /api/v1/logs/export`

**Permiso:** solo el rol `admin` (investigador). Cada exportación queda registrada en `logs_auditoria` con `accion = 'EXPORT_LOG_USO'`, sus parámetros y el número de filas. Si ese registro falla, la exportación no se entrega. Límite: 10 solicitudes por minuto.

| Parámetro | Valor por defecto | Descripción |
|---|---|---|
| `fecha_inicio` | (obligatorio) | Primer día de la intervención, `AAAA-MM-DD`, en hora de Lima. |
| `semanas` | `8` | S, entre 1 y 52. |
| `nivel` | `resumen` | `resumen` (una fila por participante) o `detalle` (una fila por acceso). |
| `formato` | `csv` | `csv` (UTF-8 con BOM, para Excel o SPSS) o `json` (incluye metadatos y definiciones). |
| `incluir_inactivos` | `false` | Incluir a los participantes retirados. |

Ejemplo:
```powershell
$token = "<JWT del admin>"
Invoke-WebRequest -Headers @{Authorization = "Bearer $token"} `
  -Uri "http://localhost:8000/api/v1/logs/export?fecha_inicio=2026-03-02&semanas=8&nivel=resumen" `
  -OutFile log_uso_resumen.csv
```

### Columnas de `nivel=resumen`

| Columna | Significado |
|---|---|
| `codigo` | P01, P02, … (nunca `usuario_id`, nombre ni correo). |
| `activo` | Solo aparece con `incluir_inactivos=true` (1 = activo, 0 = retirado). |
| `N`, `S`, `FU`, `sum_T_min`, `TPP_min` | Indicadores de la §1. |
| `sem1` … `semS` | Accesos por semana. Su suma es igual a N. |
| `sesiones_recuperadas` | Accesos cuya salida se estimó por cierre abrupto de la app (§2). |

### Columnas de `nivel=detalle`

`codigo, n_sesion, semana, fecha_hora_ingreso, fecha_hora_salida, tiempo_permanencia_min, tipo_cierre`. Las fechas van en ISO 8601 con desfase de Lima (`-05:00`).

### Reglas de cálculo que se declaran en la tesis

1. **N = 0 entra en el análisis.** La consulta parte de `participantes_estudio` con un `LEFT JOIN` a `logs_uso`. Un padre que nunca usó la app aparece con N = 0 y FU = 0. Omitirlo inflaría la media de FU.
2. **TPP vacío cuando N = 0.** Dividir entre cero no da un promedio válido. Se trata como dato faltante, no como 0.
3. **Semana según la fecha de Lima.** Un acceso del domingo a las 22:00 en Lima (03:00 UTC del lunes) cuenta en la semana del domingo. Si el servidor no tiene la base de zonas IANA, se usa UTC−5 fijo, que es equivalente porque Perú no aplica horario de verano desde 1994.
4. **Redondeo.** Los valores de FU y TPP se recalcularán en SPSS a partir de N y ΣT exportados por el endpoint, para evitar discrepancias por redondeo entre el backend y el software estadístico. El backend exporta N y ΣT sin redondeo adicional. N es un entero y ΣT (`sum_T_min`) es la suma exacta de las duraciones T almacenadas; cada T se guarda con una resolución de 0,01 min (0,6 s). Las columnas `FU` y `TPP_min` del archivo se redondean a 2 decimales, con redondeo convencional medio hacia arriba (0,125 → 0,13), solo como referencia de lectura.

---

## 8. Amenazas a la validez y limitaciones (texto propuesto para 3.6 y 8.10)

**Texto consolidado para la tesis:**

> El registro de uso depende de los timestamps del reloj del dispositivo móvil, lo que puede introducir desfases. Este riesgo se mitiga con el campo fecha_sync (que registra cuándo se sincronizó la sesión) y con la tolerancia de 5 minutos del stored procedure, pero no se elimina por completo. Adicionalmente, el período de gracia de 5 minutos puede agrupar en una sola sesión dos episodios de uso separados por una interrupción breve, y las sesiones no sincronizadas antes de la exportación final no se incluyen en el cálculo.

Detalle de cada limitación:

1. **Período de gracia.** *"El período de gracia de 5 minutos puede agrupar en una sola sesión dos episodios de uso separados por una interrupción breve."*
2. **Reloj del dispositivo.** *"Las marcas de tiempo de ingreso y salida provienen del reloj del celular del participante. Un reloj desajustado desplaza las sesiones en el tiempo; esto se mitiga rechazando sesiones con ingreso futuro (tolerancia de 5 minutos) o con duración superior a 12 horas, y registrando la hora de llegada al servidor (`fecha_sync`), pero no se elimina."*
3. **Cierres abruptos.** *"Cuando la aplicación se cierra de forma abrupta, la hora de salida se estima con el último latido registrado, con un error inferior a 60 segundos. Estas sesiones se identifican en la columna `sesiones_recuperadas`."*
4. **Accesos no sincronizados.** *"Un acceso registrado sin conexión solo llega al servidor cuando el celular recupera la red. Los accesos que no se hayan sincronizado al momento de la exportación final no se incluyen."* **Mitigación:** antes de la exportación final, pedir a los participantes que abran la app con conexión y esperar al menos un día.
5. **Uso fuera del alcance medido.** El registro de uso funciona en la app Android; la versión web no registra accesos. Los participantes usan el APK de Android.
6. **Uso compartido del dispositivo.** El registro identifica la cuenta, no a la persona: si otro familiar usa la app con la sesión del padre, ese uso se atribuye al padre.

---

## 9. Lista de control del investigador

- [ ] **Antes de la intervención**
  - [ ] Aplicar la migración 14 en la base de producción.
  - [ ] Ejecutar `seed_participantes_estudio.sql` y verificar los 30 códigos.
  - [ ] Guardar la tabla de correspondencia en un lugar seguro, fuera del repositorio.
  - [ ] Fijar y registrar `fecha_inicio` (primer día de la semana 1).
- [ ] **Durante las 8 semanas**
  - [ ] Exportar `nivel=resumen` cada semana para detectar participantes sin uso.
  - [ ] Marcar los retiros con `activo = FALSE`.
- [ ] **Al cierre**
  - [ ] Pedir a los participantes que abran la app con conexión (limitación 4).
  - [ ] Exportar `resumen` y `detalle` en CSV y JSON; archivar los archivos junto con la fecha de exportación.
