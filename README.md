# SendaIA — Aplicativo móvil con IA para el apoyo parental en el aprendizaje de niños con TDAH

Sistema desarrollado para el **Centro Colibrí (2026)**: fortalece el apoyo parental en el
aprendizaje de niños con TDAH mediante un asistente de IA, un perfil de aprendizaje y
recomendaciones para acompañar en casa.

> Nota: SendaIA es una herramienta de apoyo al aprendizaje. No realiza diagnósticos
> automáticos ni sustituye la evaluación profesional.

## Requisitos previos
- Flutter SDK 3.x
- Docker Desktop 4.x
- VS Code
- Git

## Levantar el entorno de desarrollo

### 1. Clonar el repositorio
```bash
git clone https://github.com/Enelie/SendaIA.git
cd SendaIA
git checkout main
```

### 2. Configurar variables de entorno
```bash
# Copia el archivo de ejemplo y edita con tus datos
cp .env.example .env
```

Variables mínimas: `POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_DB`, `JWT_SECRET`,
`CORS_ORIGINS`.

### 3. Levantar base de datos y API
```bash
docker compose up -d
```

Levanta `rimai_postgres` (PostgreSQL 15, puerto 5432) y `rimai_api` (FastAPI, puerto 8000).
El esquema y los datos de ejemplo se aplican automáticamente desde `backend/sql/`
(`01_init.sql` … `13_migration_data_protection_compliance.sql` + seeds).

pgAdmin (perfil `dev`):
```bash
docker compose --profile dev up -d
```

### 4. Abrir la aplicación Flutter
```bash
cd sendaia_app
flutter pub get
flutter run
```

## Accesos locales
| Servicio | URL | Credenciales |
|---|---|---|
| API | http://localhost:8000/health | — |
| pgAdmin | http://localhost:5050 | las de tu `.env` |
| PostgreSQL | localhost:5432 | las de tu `.env` |

Usuarios demo:
| Rol | Email | Contraseña |
|---|---|---|
| Terapeuta | terapeuta@rimai.dev | Rimai2024! |
| Familia 1 | familia1@rimai.dev | Rimai2024! |
| Familia 2 | familia2@rimai.dev | Rimai2024! |

## Conexión desde el emulador o el celular
- Emulador Android: la app detecta el backend automáticamente en `http://10.0.2.2:8000`.
- Celular físico: `adb reverse tcp:8000 tcp:8000`.
- URL manual: `flutter run --dart-define=API_BASE=http://<ip>:8000`.

## Estructura del proyecto
```
SendaIA/
├── backend/            # API FastAPI (adaptadores, dominio, IA, SQL)
│   ├── app/
│   └── sql/            # Esquema, migraciones y seeds
├── sendaia_app/        # Aplicación Flutter (capa adaptadora de entrada)
├── docs/               # Auditorías FURPS y OWASP
├── docker-compose.yml
└── .env
```

## Verificación
```bash
cd sendaia_app
flutter analyze
flutter test
```
