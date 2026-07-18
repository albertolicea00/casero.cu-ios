# 🏠 CASERO.cu — iOS

[![License: MIT](https://img.shields.io/badge/Licencia-MIT-yellow.svg)](LICENSE)
[![Plataforma: iOS](https://img.shields.io/badge/Plataforma-iOS-000000?logo=apple)](https://developer.apple.com/ios/)
[![Lenguaje: Swift](https://img.shields.io/badge/Lenguaje-Swift-F05138?logo=swift)](https://swift.org)
[![UI: SwiftUI](https://img.shields.io/badge/UI-SwiftUI-007AFF?logo=swift)](https://developer.apple.com/xcode/swiftui/)
[![PRs: Bienvenidos](https://img.shields.io/badge/PRs-bienvenidos-brightgreen)](CONTRIBUTING.md)

[See the English version](README.md)

Cliente nativo iOS para que los arrendadores de casas particulares en Cuba reporten sus huéspedes a las autoridades. 🇨🇺

> ⚠️ **Proyecto no oficial.** No está afiliado con CIDP-MININT ni ninguna entidad gubernamental. Se conecta al portal oficial usando las credenciales del propio arrendador, igual que lo haría un navegador.
>
> 🛡️ **Aviso:** No nos responsabilizamos por cambios en `casero.rem.cu`, los códigos USSD/SMS, o cualquier problema derivado del uso de este software. Úselo bajo su propio riesgo. Siempre verifique los registros de huéspedes por los canales oficiales.

---

## ✨ Funcionalidades

- 📋 **Registro de huéspedes** por dos vías:
  - 📞 **Códigos USSD / SMS** — funciona sin conexión a internet
  - 🌐 **API del portal web** — se autentica contra `casero.rem.cu` y replica las peticiones del navegador
- 👥 Lista de huéspedes activos y registrados, con acompañantes
- 📱 Gestión de vías de comunicación (teléfonos y correos)

## 🛠 Stack Tecnológico

| Capa | Opción |
|------|--------|
| Lenguaje | Swift |
| UI | SwiftUI |
| Dependencias | Swift Package Manager |
| Red | Portal ASP.NET MVC (token antifalsificación + cookies de sesión) |

## 🚀 Primeros Pasos

```bash
git clone https://github.com/albertolicea00/casero.cu-ios.git
cd casero.cu-ios
open CaseroCU.xcodeproj
```

Compilar desde CLI:

```bash
xcodebuild -scheme CaseroCU -destination 'platform=iOS Simulator,name=iPhone 15' build
```

> 🔐 El material de firma (`*.p12`, `*.mobileprovision`, `*.p8`) nunca se sube al repositorio.

## 🔒 Nota sobre TLS

El portal sirve un certificado que no pasa la validación estándar. La app usa **certificate pinning** mediante `URLSessionDelegate` — no se deshabilita ATS globalmente. Vea [CLAUDE.md](CLAUDE.md) para el flujo de peticiones invertido.

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

## 📄 Licencia

[MIT](LICENSE) © 2026 Alberto Licea