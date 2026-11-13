import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../../application/ports/local_db_port.dart';
import '../../application/ports/log_uso_port.dart';
import '../../domain/entities/actividad_local.dart';
import '../../domain/entities/log_uso_local.dart';

class SqliteDbRepository implements ILocalDbPort, ILogUsoLocalPort {
  static const _tablaLogsUso = 'logs_uso_local';

  static Database? _database;

  // sqflite no está disponible en web: cola en memoria como respaldo.
  static final Map<String, ActividadLocal> _webPendientes = {};

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('rimai_offline.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return openDatabase(
      path,
      version: 3,
      onCreate: _createDB,
      // DDL idempotente (IF NOT EXISTS): ver INC-001 en docs/registro_incidencias.md.
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) await _createPendingSessionsTable(db);
        if (oldVersion < 3) await _createLogsUsoTable(db);
      },
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await _createLegacyActivitiesTable(db);
    await _createPendingSessionsTable(db);
    await _createLogsUsoTable(db);
  }

  /// Sesiones de uso (Instrumento 3). Fechas en milisegundos UTC: comparar
  /// enteros evita los errores de ordenar cadenas ISO de longitud variable.
  Future<void> _createLogsUsoTable(Database db) async {
    await db.execute('''
    CREATE TABLE IF NOT EXISTS $_tablaLogsUso (
      id TEXT PRIMARY KEY,
      usuario_id TEXT NOT NULL,
      fecha_hora_ingreso_ms INTEGER NOT NULL,
      fecha_hora_salida_ms INTEGER,
      ultimo_latido_ms INTEGER NOT NULL,
      tipo_cierre TEXT,
      rechazado INTEGER NOT NULL DEFAULT 0,
      sync_attempts INTEGER NOT NULL DEFAULT 0,
      last_error TEXT
    )
    ''');
    await db.execute('''
    CREATE INDEX IF NOT EXISTS idx_logs_uso_local_usuario
    ON $_tablaLogsUso (usuario_id, rechazado, fecha_hora_salida_ms)
    ''');
  }

  Future<void> _createLegacyActivitiesTable(Database db) async {
    await db.execute('''
    CREATE TABLE IF NOT EXISTS actividades_pendientes (
      id TEXT PRIMARY KEY,
      patient_id INTEGER,
      actividad_id TEXT,
      plan_id INTEGER,
      tiempo_empleado_segundos INTEGER,
      nivel_apoyo_requerido INTEGER,
      observaciones TEXT,
      detonantes_presentados TEXT,
      completada INTEGER,
      timestamp_local TEXT
    )
    ''');
  }

  Future<void> _createPendingSessionsTable(Database db) async {
    await db.execute('''
    CREATE TABLE IF NOT EXISTS sesiones_pendientes_sync (
      id TEXT PRIMARY KEY,
      nino_id TEXT NOT NULL,
      plan_id TEXT NOT NULL,
      actividad_id TEXT NOT NULL,
      aciertos INTEGER NOT NULL,
      repeticiones INTEGER NOT NULL,
      tiempo_respuesta_segundos INTEGER NOT NULL,
      nivel_ayuda_requerido INTEGER NOT NULL,
      nivel_dificultad_usado TEXT NOT NULL,
      observaciones TEXT,
      timestamp_local TEXT NOT NULL,
      sync_attempts INTEGER NOT NULL DEFAULT 0,
      last_error TEXT
    )
    ''');
  }

  @override
  Future<void> saveActividad(ActividadLocal actividad) async {
    if (kIsWeb) {
      _webPendientes[actividad.id] = actividad;
      return;
    }
    final db = await database;

    await db.insert(
      'sesiones_pendientes_sync',
      actividad.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<List<ActividadLocal>> getActividadesPendientes() async {
    if (kIsWeb) {
      return _webPendientes.values.toList()
        ..sort((a, b) => a.timestampLocal.compareTo(b.timestampLocal));
    }
    final db = await database;
    final maps = await db.query(
      'sesiones_pendientes_sync',
      orderBy: 'timestamp_local ASC',
    );

    return maps.map(ActividadLocal.fromJson).toList();
  }

  @override
  Future<void> deleteActividades(List<String> ids) async {
    if (ids.isEmpty) return;
    if (kIsWeb) {
      ids.forEach(_webPendientes.remove);
      return;
    }
    final db = await database;
    await db.transaction((txn) async {
      for (final id in ids) {
        await txn.delete(
          'sesiones_pendientes_sync',
          where: 'id = ?',
          whereArgs: [id],
        );
      }
    });
  }

  // ---------------------------------------------------------------------------
  // ILogUsoLocalPort (el registro de uso no se activa en web)
  // ---------------------------------------------------------------------------

  @override
  Future<void> guardarSesionUso(LogUsoLocal sesion) async {
    if (kIsWeb) return;
    final db = await database;
    await db.insert(
      _tablaLogsUso,
      sesion.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<List<LogUsoLocal>> sesionesUsoAbiertasOEnPausa() async {
    if (kIsWeb) return [];
    final db = await database;
    final maps = await db.query(
      _tablaLogsUso,
      where: 'rechazado = 0 AND (fecha_hora_salida_ms IS NULL OR tipo_cierre = ?)',
      whereArgs: [LogUsoLocal.cierreSegundoPlano],
      orderBy: 'fecha_hora_ingreso_ms DESC',
    );
    return maps.map(LogUsoLocal.fromMap).toList();
  }

  @override
  Future<List<LogUsoLocal>> sesionesUsoListasParaSync({
    required String usuarioId,
    required DateTime finGracia,
    int limite = 200,
  }) async {
    if (kIsWeb) return [];
    final db = await database;
    final maps = await db.query(
      _tablaLogsUso,
      where: 'usuario_id = ? AND rechazado = 0 AND fecha_hora_salida_ms IS NOT NULL '
          'AND (tipo_cierre != ? OR fecha_hora_salida_ms <= ?)',
      whereArgs: [
        usuarioId,
        LogUsoLocal.cierreSegundoPlano,
        finGracia.toUtc().millisecondsSinceEpoch,
      ],
      orderBy: 'fecha_hora_ingreso_ms ASC',
      limit: limite,
    );
    return maps.map(LogUsoLocal.fromMap).toList();
  }

  @override
  Future<void> eliminarSesionesUso(List<String> ids) async {
    if (kIsWeb || ids.isEmpty) return;
    final db = await database;
    final batch = db.batch();
    for (final id in ids) {
      batch.delete(_tablaLogsUso, where: 'id = ?', whereArgs: [id]);
    }
    await batch.commit(noResult: true);
  }

  @override
  Future<void> marcarSesionesUsoRechazadas(Map<String, String> motivos) async {
    if (kIsWeb || motivos.isEmpty) return;
    final db = await database;
    final batch = db.batch();
    motivos.forEach((id, motivo) {
      batch.update(
        _tablaLogsUso,
        {'rechazado': 1, 'last_error': motivo},
        where: 'id = ?',
        whereArgs: [id],
      );
    });
    await batch.commit(noResult: true);
  }

  @override
  Future<void> registrarFalloSyncUso(List<String> ids, String error) async {
    if (kIsWeb || ids.isEmpty) return;
    final db = await database;
    final batch = db.batch();
    for (final id in ids) {
      batch.rawUpdate(
        'UPDATE $_tablaLogsUso SET sync_attempts = sync_attempts + 1, last_error = ? WHERE id = ?',
        [error.length > 300 ? error.substring(0, 300) : error, id],
      );
    }
    await batch.commit(noResult: true);
  }
}
