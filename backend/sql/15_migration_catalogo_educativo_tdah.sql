-- ============================================================
-- SendaIA — Migración 15: Catálogo de actividades orientadas al aprendizaje (TDAH)
-- ============================================================
-- Incorpora actividades educativas con propósito pedagógico claro
-- para el acompañamiento parental en casa:
-- 1. Comprensión lectora
-- 2. Expresión escrita
-- 3. Razonamiento lógico
-- 4. Análisis
-- 5. Autonomía
-- 6. Pausas activas y autorregulación (complementarias)
-- ============================================================

BEGIN;

INSERT INTO actividades (id, tipo, nombre, instrucciones, nivel_dificultad, duracion_estimada, recursos_multimedia, activo)
VALUES
  -- ── 1. Comprensión lectora ────────────────────────────────────────────────
  (
    'bbbbbbbb-0001-0000-0000-000000000001',
    'Comprensión lectora',
    'Lectura en postas: ¿Quién hizo qué?',
    'Lee junto a tu hijo un párrafo breve (1 a 2 minutos). Luego, túrnense para responder tres preguntas concretas: ¿quién aparece?, ¿dónde ocurre? y ¿qué pasó primero? Fomenta que señale las palabras clave en el texto.',
    'Bajo',
    300,
    '{"materiales": ["Cuento o lectura corta de 1 página", "Resaltador o lápiz de color"]}'::jsonb,
    TRUE
  ),
  (
    'bbbbbbbb-0001-0000-0000-000000000002',
    'Comprensión lectora',
    'El final misterioso',
    'Lean una historia breve deteniéndose justo antes del desenlace. Pídele al niño que imagine dos finales posibles y explique por qué cree que ocurriría cada uno. Luego lean el final real y comparen.',
    'Medio',
    600,
    '{"materiales": ["Fábula o cuento infantil corto", "Tarjeta o cuaderno"]}'::jsonb,
    TRUE
  ),
  (
    'bbbbbbbb-0001-0000-0000-000000000003',
    'Comprensión lectora',
    'Cazador de ideas principales',
    'Selecciona una noticia o texto informativo breve. Guía al niño para encontrar la idea más importante de cada párrafo y anotarla en una sola frase usando sus propias palabras.',
    'Alto',
    720,
    '{"materiales": ["Texto informativo o de ciencias de 2 párrafos", "Notas adhesivas (post-its)"]}'::jsonb,
    TRUE
  ),

  -- ── 2. Expresión escrita ──────────────────────────────────────────────────
  (
    'bbbbbbbb-0002-0000-0000-000000000001',
    'Expresión escrita',
    'La oración misteriosa de tres palabras',
    'Escribe tres palabras relacionadas con sus intereses (ej. cohete, luna, veloz). Invita al niño a crear y escribir una oración completa que use las tres palabras. Si le cuesta, puede decirla primero en voz alta.',
    'Bajo',
    360,
    '{"materiales": ["Hojas pautadas o cuaderno", "Lápiz y borrador"]}'::jsonb,
    TRUE
  ),
  (
    'bbbbbbbb-0002-0000-0000-000000000002',
    'Expresión escrita',
    'Organizador visual: Antes, Durante y Después',
    'Dibuja tres casillas en una hoja. Pídele al niño que dibuje o escriba en una frase qué hizo en la mañana (antes), qué hace ahora (durante) y qué hará luego (después). Ayuda a estructurar la coherencia temporal.',
    'Medio',
    600,
    '{"materiales": ["Hoja blanca", "Regla o plantilla de 3 columnas", "Plumones"]}'::jsonb,
    TRUE
  ),
  (
    'bbbbbbbb-0002-0000-0000-000000000003',
    'Expresión escrita',
    'Minirrelato con conectores',
    'Escriban un relato corto de tres líneas usando los conectores: "Al inicio...", "De pronto...", "Finalmente...". El padre modela la primera línea y el niño completa las dos siguientes.',
    'Alto',
    720,
    '{"materiales": ["Cuaderno de apuntes", "Lista de conectores temporales"]}'::jsonb,
    TRUE
  ),

  -- ── 3. Razonamiento lógico ────────────────────────────────────────────────
  (
    'bbbbbbbb-0003-0000-0000-000000000001',
    'Razonamiento lógico',
    'Secuencias y patrones con objetos',
    'Usa botones, fichas, lápices o frutas para armar un patrón (ej. rojo-azul-rojo-?). Pídele que descubra la regla y continúe la secuencia. Luego inviértanse los roles y que el niño diseñe el reto.',
    'Bajo',
    300,
    '{"materiales": ["Objetos cotidianos de 2 o 3 colores o tamaños"]}'::jsonb,
    TRUE
  ),
  (
    'bbbbbbbb-0003-0000-0000-000000000002',
    'Razonamiento lógico',
    'Problemas matemáticos en tres pasos',
    'Plantea un problema cotidiano de suma o resta (ej. compras o puntos de un juego). Resuélvanlo dividiéndolo: 1) ¿Qué datos tenemos?, 2) ¿Qué nos preguntan?, 3) ¿Qué operación usamos? Usa material concreto como apoyo.',
    'Medio',
    600,
    '{"materiales": ["Fichas o monedas de juguete", "Pizarra pequeña o papel"]}'::jsonb,
    TRUE
  ),
  (
    'bbbbbbbb-0003-0000-0000-000000000003',
    'Razonamiento lógico',
    'Descifra el código numérico',
    'Presenta una pista numérica lógica (ej. "Es un número menor que 20, termina en par y es mayor que 12"). El niño debe descartar opciones y justificar cuál es el número correcto.',
    'Alto',
    720,
    '{"materiales": ["Tabla numérica del 1 al 50", "Tarjetas de pistas"]}'::jsonb,
    TRUE
  ),

  -- ── 4. Análisis ───────────────────────────────────────────────────────────
  (
    'bbbbbbbb-0004-0000-0000-000000000001',
    'Análisis',
    'Encuentra las 5 diferencias visuales',
    'Observen dos imágenes o dos grupos de objetos con pequeñas diferencias. Anima al niño a realizar un rastreo visual ordenado (de arriba a abajo, de izquierda a derecha) marcando cada diferencia encontrada.',
    'Bajo',
    360,
    '{"materiales": ["Láminas de diferencias impresas o dos fotos familiares similares"]}'::jsonb,
    TRUE
  ),
  (
    'bbbbbbbb-0004-0000-0000-000000000002',
    'Análisis',
    'Comparando dos mundos: semejanzas y diferencias',
    'Elige dos elementos conocidos (ej. bicicleta vs. auto, perro vs. gato). Dibujen dos círculos entrelazados (diagrama de Venn) y anoten 2 cosas que tienen en común y 2 diferencias clave.',
    'Medio',
    600,
    '{"materiales": ["Hoja de papel", "Diagrama de Venn dibujado", "Lápices"]}'::jsonb,
    TRUE
  ),
  (
    'bbbbbbbb-0004-0000-0000-000000000003',
    'Análisis',
    'Causa y efecto: ¿Por qué ocurrió?',
    'Lee una situación de la vida diaria o escolar (ej. "Mateo no guardó sus cuadernos en la noche"). Pregúntale: ¿cuál fue la causa?, ¿qué consecuencia trajo? y ¿qué decisión alternativa habría evitado el problema?',
    'Alto',
    720,
    '{"materiales": ["Tarjetas con 3 situaciones cotidianas"]}'::jsonb,
    TRUE
  ),

  -- ── 5. Autonomía ──────────────────────────────────────────────────────────
  (
    'bbbbbbbb-0005-0000-0000-000000000001',
    'Autonomía',
    'Mesa despejada: La regla de los 3 objetos',
    'Antes de iniciar las tareas escolares, acompaña al niño a revisar su espacio de estudio. Solo deben quedar en la mesa 3 cosas: el cuaderno de la tarea, la cartuchera y un vaso de agua. Todo lo demás se guarda.',
    'Bajo',
    240,
    '{"materiales": ["Mesa de estudio", "Caja organizadora o estante"]}'::jsonb,
    TRUE
  ),
  (
    'bbbbbbbb-0005-0000-0000-000000000002',
    'Autonomía',
    'Checklist visual de tareas del día',
    'Elaboren juntos una lista visual de 3 tareas escolares o domésticas con casillas para marcar (check). El niño revisa la lista de forma independiente y marca cada tarea al concluirla.',
    'Medio',
    480,
    '{"materiales": ["Pizarra blanca con imanes o cartulina con stickers"]}'::jsonb,
    TRUE
  ),
  (
    'bbbbbbbb-0005-0000-0000-000000000003',
    'Autonomía',
    'Reto Pomodoro adaptado: 15 min de foco',
    'Acuerden una tarea concreta a completar en un bloque de 15 minutos cronometrados con alarma visual. Si termina antes o mantiene la atención durante el bloque, se gana una pausa activa de 5 minutos.',
    'Alto',
    900,
    '{"materiales": ["Temporizador o reloj visible", "Tarea escolar asignada"]}'::jsonb,
    TRUE
  ),

  -- ── 6. Pausas activas y autorregulación (complementarias) ─────────────────
  (
    'bbbbbbbb-0006-0000-0000-000000000001',
    'Pausas y autorregulación',
    'Pausa activa: El robot y la gelatina',
    'Estrategia de pausa motora de 3 minutos: Pídele al niño que tense los músculos como un robot rígido durante 5 segundos y luego los suelte por completo sacudiéndose como una gelatina. Repetir 3 veces para liberar tensión motora.',
    'Bajo',
    180,
    '{"materiales": ["Espacio libre para ponerse de pie"]}'::jsonb,
    TRUE
  ),
  (
    'bbbbbbbb-0006-0000-0000-000000000002',
    'Pausas y autorregulación',
    'Respiración del triángulo para reiniciar la atención',
    'Dibuja un triángulo en el aire con el dedo: sube inhalando en 3 segundos, sostén el aire 3 segundos en la cima y baja exhalando en 3 segundos. Practiquen 4 ciclos juntos antes de retomar una tarea difícil.',
    'Bajo',
    180,
    '{"materiales": ["Ninguno (técnica corporal)"]}'::jsonb,
    TRUE
  )
ON CONFLICT (id) DO UPDATE SET
  tipo = EXCLUDED.tipo,
  nombre = EXCLUDED.nombre,
  instrucciones = EXCLUDED.instrucciones,
  nivel_dificultad = EXCLUDED.nivel_dificultad,
  duracion_estimada = EXCLUDED.duracion_estimada,
  recursos_multimedia = EXCLUDED.recursos_multimedia,
  activo = TRUE;

COMMIT;
