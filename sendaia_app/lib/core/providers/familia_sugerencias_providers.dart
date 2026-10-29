import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:rimai_app/core/providers/dashboard_providers.dart';

Map<String, dynamic> _toMap(dynamic raw) {
  if (raw is Map<String, dynamic>) return raw;
  if (raw is Map) return raw.cast<String, dynamic>();
  throw Exception('Respuesta inesperada del servidor.');
}

List<String> _stringList(dynamic raw) {
  if (raw is List) return raw.map((e) => e.toString()).toList();
  return [];
}

class SugerenciaActividad {
  final String actividadId;
  final String nombre;
  final String tipo;
  final String nivelDificultad;
  final int duracionSegundos;
  final int? duracionMinutos;
  final String? instrucciones;
  final List<String> materiales;
  final int puntuacion;
  final List<String> motivos;
  final List<String> consejos;

  const SugerenciaActividad({
    required this.actividadId,
    required this.nombre,
    required this.tipo,
    required this.nivelDificultad,
    required this.duracionSegundos,
    required this.duracionMinutos,
    required this.instrucciones,
    required this.materiales,
    required this.puntuacion,
    required this.motivos,
    required this.consejos,
  });

  factory SugerenciaActividad.fromJson(Map<String, dynamic> json) {
    return SugerenciaActividad(
      actividadId: json['actividad_id']?.toString() ?? '',
      nombre: json['nombre']?.toString() ?? '',
      tipo: json['tipo']?.toString() ?? '',
      nivelDificultad: json['nivel_dificultad']?.toString() ?? '',
      duracionSegundos: (json['duracion_segundos'] as num?)?.toInt() ?? 0,
      duracionMinutos: (json['duracion_minutos'] as num?)?.toInt(),
      instrucciones: json['instrucciones']?.toString(),
      materiales: _stringList(json['materiales']),
      puntuacion: (json['puntuacion'] as num?)?.toInt() ?? 0,
      motivos: _stringList(json['motivos']),
      consejos: _stringList(json['consejos']),
    );
  }
}

class SugerenciasFamilia {
  final String ninoId;
  final String ninoNombre;
  final String dificultadEstimada;
  final double confianzaModelo;
  final bool perfilCompleto;
  final List<String> camposPerfilUsados;
  final List<SugerenciaActividad> sugerencias;
  final int totalCatalogo;
  final String nota;

  const SugerenciasFamilia({
    required this.ninoId,
    required this.ninoNombre,
    required this.dificultadEstimada,
    required this.confianzaModelo,
    required this.perfilCompleto,
    required this.camposPerfilUsados,
    required this.sugerencias,
    required this.totalCatalogo,
    required this.nota,
  });

  factory SugerenciasFamilia.fromJson(Map<String, dynamic> json) {
    final rawItems = json['sugerencias'];
    final items = <SugerenciaActividad>[
      if (rawItems is List)
        for (final item in rawItems)
          SugerenciaActividad.fromJson(_toMap(item)),
    ];
    return SugerenciasFamilia(
      ninoId: json['nino_id']?.toString() ?? '',
      ninoNombre: json['nino_nombre']?.toString() ?? '',
      dificultadEstimada: json['dificultad_estimada']?.toString() ?? '',
      confianzaModelo: (json['confianza_modelo'] as num?)?.toDouble() ?? 0,
      perfilCompleto: json['perfil_completo'] == true,
      camposPerfilUsados: _stringList(json['campos_perfil_usados']),
      sugerencias: items,
      totalCatalogo: (json['total_catalogo'] as num?)?.toInt() ?? 0,
      nota: json['nota']?.toString() ?? '',
    );
  }
}

Future<SugerenciasFamilia> _cargar(Dio dio, String ninoId) async {
  try {
    final response =
        await dio.get('/api/familia/ninos/$ninoId/sugerencias');
    return SugerenciasFamilia.fromJson(_toMap(response.data));
  } on DioException catch (e) {
    final detail = e.response?.data is Map
        ? (e.response!.data['detail']?.toString())
        : null;
    throw Exception(detail ?? 'No se pudieron cargar las sugerencias.');
  }
}

/// Sugerencias personalizadas de actividades para el panel del padre.
final sugerenciasFamiliaProvider = FutureProvider.autoDispose
    .family<SugerenciasFamilia, String>((ref, ninoId) async {
  return _cargar(ref.read(dioProvider), ninoId);
});
