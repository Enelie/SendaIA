import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:rimai_app/core/providers/dashboard_providers.dart';
import 'package:rimai_app/core/providers/pmv2_providers.dart';
import 'package:rimai_app/domain/entities/actividad_local.dart';

Map<String, dynamic> _map(dynamic raw) =>
    raw is Map ? raw.cast<String, dynamic>() : <String, dynamic>{};

List<Map<String, dynamic>> _maps(dynamic raw) =>
    raw is List ? raw.map(_map).toList() : const [];

double? _numOrNull(dynamic raw) => raw is num ? raw.toDouble() : null;

int _int(dynamic raw) => raw is num ? raw.toInt() : 0;

/// Una actividad efectivamente registrada (resultados_actividad).
class RegistroActividad {
  final String id;
  final String actividadId;
  final String actividadNombre;
  final String? actividadTipo;
  final DateTime? fecha;
  final String estado;
  final double? duracionSegundos;
  final int? duracionEstimadaSegundos;
  final int? aciertos;
  final int? intentos;
  final int? nivelAyuda;
  final String? observaciones;

  const RegistroActividad({
    required this.id,
    required this.actividadId,
    required this.actividadNombre,
    this.actividadTipo,
    this.fecha,
    required this.estado,
    this.duracionSegundos,
    this.duracionEstimadaSegundos,
    this.aciertos,
    this.intentos,
    this.nivelAyuda,
    this.observaciones,
  });

  factory RegistroActividad.fromJson(Map<String, dynamic> j) =>
      RegistroActividad(
        id: j['id']?.toString() ?? '',
        actividadId: j['actividad_id']?.toString() ?? '',
        actividadNombre: j['actividad_nombre']?.toString() ?? 'Actividad',
        actividadTipo: j['actividad_tipo']?.toString(),
        fecha: DateTime.tryParse(j['fecha']?.toString() ?? '')?.toLocal(),
        estado: j['estado']?.toString() ?? 'completada',
        duracionSegundos: _numOrNull(j['duracion_segundos']),
        duracionEstimadaSegundos: (j['duracion_estimada_segundos'] as num?)?.toInt(),
        aciertos: (j['aciertos'] as num?)?.toInt(),
        intentos: (j['intentos'] as num?)?.toInt(),
        nivelAyuda: (j['nivel_ayuda_requerido'] as num?)?.toInt(),
        observaciones: j['observaciones']?.toString(),
      );
}

class SemanaActividad {
  final DateTime semana;
  final int actividades;
  final double? segundos;

  const SemanaActividad(
      {required this.semana, required this.actividades, this.segundos});

  factory SemanaActividad.fromJson(Map<String, dynamic> j) => SemanaActividad(
        semana: DateTime.parse(j['semana'].toString()),
        actividades: _int(j['actividades']),
        segundos: _numOrNull(j['segundos']),
      );
}

/// Actividad recomendada en el plan publicado y si ya se registró.
class ActividadRecomendadaEstado {
  final String planId;
  final String actividadId;
  final String nombre;
  final String? tipo;
  final bool realizada;
  final DateTime? ultimaRealizacion;

  const ActividadRecomendadaEstado({
    required this.planId,
    required this.actividadId,
    required this.nombre,
    this.tipo,
    required this.realizada,
    this.ultimaRealizacion,
  });

  factory ActividadRecomendadaEstado.fromJson(Map<String, dynamic> j) =>
      ActividadRecomendadaEstado(
        planId: j['plan_id']?.toString() ?? '',
        actividadId: j['actividad_id']?.toString() ?? '',
        nombre: j['nombre']?.toString() ?? 'Actividad',
        tipo: j['tipo']?.toString(),
        realizada: j['realizada'] == true,
        ultimaRealizacion:
            DateTime.tryParse(j['ultima_realizacion']?.toString() ?? '')
                ?.toLocal(),
      );
}

class SeguimientoFamiliar {
  final String ninoId;
  final DateTime desde;
  final DateTime hasta;
  final int actividadesCompletadas;
  final int diasConActividad;
  final double? segundosTotales;
  final int registrosConDuracion;
  final int aciertos;
  final int intentos;
  final List<SemanaActividad> porSemana;
  final List<RegistroActividad> registros;
  final bool registrosTruncados;
  final List<ActividadRecomendadaEstado> recomendadas;

  const SeguimientoFamiliar({
    required this.ninoId,
    required this.desde,
    required this.hasta,
    required this.actividadesCompletadas,
    required this.diasConActividad,
    this.segundosTotales,
    required this.registrosConDuracion,
    required this.aciertos,
    required this.intentos,
    required this.porSemana,
    required this.registros,
    required this.registrosTruncados,
    required this.recomendadas,
  });

  factory SeguimientoFamiliar.fromJson(dynamic raw) {
    final j = _map(raw);
    final r = _map(j['resumen']);
    return SeguimientoFamiliar(
      ninoId: j['nino_id']?.toString() ?? '',
      desde: DateTime.parse(j['desde'].toString()),
      hasta: DateTime.parse(j['hasta'].toString()),
      actividadesCompletadas: _int(r['actividades_completadas']),
      diasConActividad: _int(r['dias_con_actividad']),
      segundosTotales: _numOrNull(r['segundos_totales']),
      registrosConDuracion: _int(r['registros_con_duracion']),
      aciertos: _int(r['aciertos']),
      intentos: _int(r['intentos']),
      porSemana: _maps(j['por_semana']).map(SemanaActividad.fromJson).toList(),
      registros: _maps(j['registros']).map(RegistroActividad.fromJson).toList(),
      registrosTruncados: j['registros_truncados'] == true,
      recomendadas: _maps(j['recomendadas'])
          .map(ActividadRecomendadaEstado.fromJson)
          .toList(),
    );
  }
}

class SeguimientoService {
  SeguimientoService(this._dio);
  final Dio _dio;

  static String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<SeguimientoFamiliar> obtener(
      String ninoId, DateTime desde, DateTime hasta) async {
    try {
      final response = await _dio.get(
        '/api/dashboard/familia/ninos/$ninoId/seguimiento',
        queryParameters: {'desde': _fmt(desde), 'hasta': _fmt(hasta)},
      );
      return SeguimientoFamiliar.fromJson(response.data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) throw const SessionExpiredException();
      final detail = e.response?.data is Map ? e.response?.data['detail'] : null;
      throw Exception(detail?.toString() ??
          'No se pudo cargar el seguimiento. Revisa tu conexión.');
    }
  }
}

typedef SeguimientoArgs = ({String ninoId, DateTime desde, DateTime hasta});

final seguimientoServiceProvider =
    Provider((ref) => SeguimientoService(ref.read(dioProvider)));

final seguimientoFamiliarProvider = FutureProvider.autoDispose
    .family<SeguimientoFamiliar, SeguimientoArgs>((ref, args) {
  return ref
      .read(seguimientoServiceProvider)
      .obtener(args.ninoId, args.desde, args.hasta);
});

/// Actividades guardadas en este dispositivo sin conexión que aún no llegaron
/// al servidor (cola de SesionService). No se cuentan como registradas.
final actividadesPendientesSyncProvider = FutureProvider.autoDispose
    .family<List<ActividadLocal>, String>((ref, ninoId) async {
  final pendientes =
      await ref.read(sqliteDbRepositoryProvider).getActividadesPendientes();
  return pendientes.where((a) => a.ninoId == ninoId).toList();
});
