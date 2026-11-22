# 🏠 CASERO.cu — iOS
Cliente nativo iOS para que los arrendadores de casas particulares en Cuba reporten sus huéspedes a las autoridades. 🇨🇺

[![License: MIT](https://img.shields.io/badge/Licencia-MIT-yellow.svg)](LICENSE)
[![Plataforma: iOS](https://img.shields.io/badge/Plataforma-iOS-000000?logo=apple)](https://developer.apple.com/ios/)
[![Lenguaje: Swift](https://img.shields.io/badge/Lenguaje-Swift-F05138?logo=swift)](https://swift.org)
[![UI: SwiftUI](https://img.shields.io/badge/UI-SwiftUI-007AFF?logo=swift)](https://developer.apple.com/xcode/swiftui/)
[![PRs: Bienvenidos](https://img.shields.io/badge/PRs-bienvenidos-brightgreen)](CONTRIBUTING.md)

[See the English version](README.md)

## ⚠️ Disclaimer

> [!WARNING]
> **Unofficial project.** Not affiliated with CIDP-MININT or any government entity. Talks to the official portal using the host's own credentials, the same way a browser does. We are not responsible for changes to `casero.rem.cu`, USSD/SMS codes, or any issues arising from using this software. Use at your own risk. Always verify guest registrations through official channels.
---

## Estado de la implementación

La app incluye inicio de sesión en el portal (con Face ID / código para usar las
credenciales guardadas), listas de huéspedes paginadas, datos sin conexión,
fotos, exportaciones CSV/PDF, interfaz y manual de usuario en español e inglés.
La política de privacidad, los términos y el EULA están en el
[sitio web](https://casero-cu.vercel.app/privacy.html).

Registro de huéspedes: búsqueda por pasaporte, nombre, carné de identidad (CI) y
CI temporal; confirmación de la persona, fechas (entrada hasta 7 días atrás),
revisión antes de enviar, ID de estancia en el resultado y PDF antes, después y
si falla. El formato de envío está confirmado con capturas del portal y ya se
envió un registro real desde la app (issue #2, cerrado). Vea el
[contrato de registro](AGENTS.md#registration--confirmed).

La app muestra, solo para consulta, los teléfonos y correos registrados del
arrendador; para añadirlos o eliminarlos abre la página oficial del portal en
Safari. También muestra, solo para consulta, el perfil del portal (nombre, CI,
usuario, dirección); el cambio de contraseña se hace en la página de perfil del
portal.

Ayuda dentro de la app: la ayuda oficial del portal (con enlaces a cada página
del portal) y un resumen sin conexión de la guía de Cubatrámite sobre el
reporte. Registrar y Huéspedes explican qué hacen y avisan que están en beta.

El reporte por SMS a **7344** usa el prefijo **HC**, los días de estancia, los
reportes de acompañantes y el intercambio de confirmación por separado. La
asociación del teléfono se hace llamando al **18808**. El usuario revisa y envía
cada mensaje desde iOS.

La verificación con el portal real desde Cuba y la distribución siguen
pendientes. Vea la [lista de verificación](ARCHITECTURE.md#release-checklist).

## 🛠 Stack Tecnológico

| Capa | Opción |
|------|--------|
| Lenguaje | Swift |
| UI | SwiftUI |
| Dependencias | Swift Package Manager |
| Red | Portal ASP.NET MVC (token antifalsificación + cookies de sesión) |

## 🏗 ¿Por qué aplicaciones nativas independientes? (iOS vs Android)

En lugar de utilizar una tecnología híbrida o multiplataforma (como Flutter o React Native), CASERO.cu mantiene bases de código nativas e independientes:

- **Permisos y libertad en Android:** Android permite un nivel más profundo de integración con el sistema operativo (automatización de llamadas/USSD, tareas en segundo plano e integración con el hardware), lo que permite extender el funcionamiento de la app según las necesidades.
- **Restricciones del Sandbox de iOS:** iOS aplica un sandbox más estricto y con menores libertades de API, por lo que la app en iOS se mantiene acotada a lo que la plataforma permite de forma oficial.
- **Experiencia optimizada:** El desarrollo nativo en Swift/SwiftUI para iOS y Kotlin/Jetpack Compose para Android garantiza el máximo rendimiento, una interfaz acorde a cada sistema y el cumplimiento de requerimientos de seguridad nativos (como certificate pinning y background workers).

## 🚀 Primeros Pasos

```bash
git clone https://github.com/albertolicea00/casero.cu-ios.git
cd casero.cu-ios
brew install xcodegen
xcodegen generate
open CaseroCu.xcodeproj
```

Compilar desde CLI:

```bash
xcodebuild -scheme CaseroCu -destination 'generic/platform=iOS Simulator' build
```

> 🔐 El material de firma (`*.p12`, `*.mobileprovision`, `*.p8`) nunca se sube al repositorio.

## 🔒 Nota sobre TLS

El portal sirve un certificado que no pasa la validación estándar. La app usa **certificate pinning** mediante `URLSessionDelegate` — no se deshabilita ATS globalmente. Vea [AGENTS.md](ARCHITECTURE.md#pinned-tls-certificate) para saber qué es el certificado y cómo renovarlo, y [AGENTS.md](AGENTS.md#portal-api-reference) para el flujo de peticiones obtenido por ingeniería inversa.

## 🤝 Contribuir

Vea [CONTRIBUTING.md](CONTRIBUTING.md), [SECURITY.md](SECURITY.md) y [Código de Conducta](CODE_OF_CONDUCT.md). Usamos [Conventional Commits](https://www.conventionalcommits.org/).

### 🐛 Reportar Bugs

¿Encontró un bug? Abra un issue en el repo correspondiente:
- **Bugs específicos de iOS** → [abrir aquí](https://github.com/albertolicea00/casero.cu-ios/issues)
- **Bugs específicos de Android** → [abrir aquí](https://github.com/albertolicea00/casero.cu-apk/issues)
- **Problemas core / multiplataforma** (cambios en la API, flujo de autenticación, etc.) → abrir en cualquiera de los dos, lo trackingeamos en ambos

## 📦 Repos Relacionados

- [casero.cu-ios](https://github.com/albertolicea00/casero.cu-ios) — Cliente iOS (este repo)
- [casero.cu-apk](https://github.com/albertolicea00/casero.cu-apk) — Cliente Android
- [casero.cu-web](https://github.com/albertolicea00/casero.cu-web) — Cliente Web 

## 📄 Licencia

[MIT](LICENSE) © 2026 Alberto Licea
