# BiyuYA 📷💸

> Escaneá alias de pago con la cámara. Sin tipear. Sin errores.

BiyuYA es una app mobile para Argentina que resuelve un problema cotidiano: tener que tipear manualmente un alias de MercadoPago, Modo u otras billeteras digitales desde un cartel, papelito escrito a mano o pantalla de un comercio.

Apuntás la cámara, la app detecta el alias automáticamente, lo copia al portapapeles y te abre la app de pago directo. Cero tipeo.

---

## ¿Por qué existe esto?

En Argentina pagamos con transferencia en todos lados — la verdulería, el kiosco, el delivery, el flete. Y el 90% de esos comercios tienen el alias escrito en un papel o en un cartel.

El problema: tipear `verduleria.rodriguez.mp` sin equivocarse mientras te apuran en la caja es un deporte de alto riesgo.

A hoy, MercadoPago es la única app de pagos argentina con este feature nativo. El resto no lo tiene. BiyuYA lo trae para todas.

---

## Features

- 📷 **Escáner OCR** — detecta alias impresos, escritos a mano o en pantalla
- 📋 **Copia automática** — el alias se copia al portapapeles al instante
- 🚀 **Apertura directa** — abre la app de pago instalada en un tap
- 🏦 **Multi-app** — soporta las principales billeteras argentinas
- ✅ **Sin internet para pagar** — solo usa red para el OCR
- 🌙 **Splash screen** — animación de entrada con logo y nombre

---

## Apps de pago soportadas

| App | Package |
|-----|---------|
| MercadoPago | `com.mercadopago.wallet` |
| Modo | `com.playdigital.modo` |
| Personal Pay | `ar.com.personalpay` |
| Naranja X | `com.tarjetanaranja.ncuenta` |
| Cuenta DNI | `ar.com.bancoprovincia.CuentaDNI` |
| BBVA | `ar.com.bbva.net` |
| Uala | `ar.com.uala` |
| Brubank | `com.brubank` |
| Macro | `ar.com.macro` |
| Galicia | `ar.com.galicia.bancamovil` |

La app detecta automáticamente cuáles están instaladas y solo muestra esas.

---

## Stack

- **Flutter** — codebase única para Android e iOS
- **Google Cloud Vision API** — OCR en la nube para leer alias impresos y escritos a mano
- **Kotlin MethodChannel** — intents nativos de Android para lanzar cada app de pago
- **CameraX** — captura de frames para el escaneo
- **flutter_dotenv** — manejo seguro de la API key

---

## Arquitectura

```
lib/
├── main.dart                        # Entry point, tema y configuración
├── screens/
│   ├── splash_screen.dart           # Splash animado con logo y nombre
│   └── scanner_screen.dart          # Pantalla principal con cámara y botón escanear
├── widgets/
│   ├── alias_result_sheet.dart      # Bottom sheet con alias detectado y selector de apps
│   └── scanner_overlay.dart        # Overlay visual del recuadro de escaneo
└── services/
    └── ocr_service.dart             # Integración con Google Vision API
```

```
android/
└── app/src/main/kotlin/.../
    └── MainActivity.kt              # MethodChannel: launchApp, getInstalledApps, isAppInstalled
```

---

## Configuración

### Requisitos
- Flutter 3.x+
- Android SDK (API 21+)
- Google Cloud Vision API key

### Setup

```bash
git clone https://github.com/devfedeacosta/biyuyapp
cd biyuyapp
flutter pub get
```

Crear archivo `.env` en la raíz del proyecto:

```
GOOGLE_VISION_API_KEY=tu_api_key_aqui
```

> ⚠️ El archivo `.env` está en `.gitignore` — nunca lo subas al repositorio.

### Correr en Android

```bash
flutter run -d <device_id>
```

### Obtener device ID

```bash
flutter devices
```

---

## Assets

```
assets/
├── icon/
│   └── foreground.png    # Ícono de la app (mano con billete)
└── logos/
    ├── mercadopago.png
    ├── modo.png
    ├── personalpay.png
    ├── naranjax.png
    └── cuentadni.png
```

```
fonts/
├── Outfit-Regular.ttf    # weight: 400
├── Outfit-Bold.ttf       # weight: 700
└── Outfit-ExtraBold.ttf  # weight: 800
```

---

## Permisos Android

```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.QUERY_ALL_PACKAGES" />
```

`QUERY_ALL_PACKAGES` es necesario para detectar qué apps de pago están instaladas en Android 11+.

---

## Flujo de uso

```
1. Usuario abre BiyuYA
2. Splash screen (1s) → pantalla de escaneo
3. Usuario apunta la cámara al alias (cartel, papel, pantalla)
4. Presiona "Escanear"
5. OCR detecta el alias → se copia al portapapeles
6. Bottom sheet muestra las apps instaladas
7. Usuario toca la app → se abre directamente
```

---

## Roadmap

- [ ] Modo offline con ML Kit (reemplazar Google Vision)
- [ ] iOS build y distribución via AltStore
- [ ] Historial de alias escaneados
- [ ] Widget de pantalla de inicio
- [ ] Soporte para CVU además de alias

---

## Autor

**Federico Acosta** — [@devfedeacosta](https://github.com/devfedeacosta)

---

## Licencia

MIT
