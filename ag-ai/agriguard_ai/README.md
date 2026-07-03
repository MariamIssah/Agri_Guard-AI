# AgriGuard AI — Flutter Mobile Application

**APK Download:** [AgriGuard-AI.apk](../../AgriGuard-AI.apk) ← Install this on your Android phone  
**Live API:** https://agriguard-ai-production.up.railway.app  
**ML Pipeline Docs:** [ag-ai/README.md](../README.md)

---

## How to Install the App on Your Phone

### Option A — Install APK (Recommended — No Setup Required)

1. Download [AgriGuard-AI.apk](../../AgriGuard-AI.apk) from the root of this repository
2. Transfer to your Android phone (email, WhatsApp, USB, or Google Drive)
3. On your phone: go to **Settings → Security → Install unknown apps**
   - On Android 8+: enable "Allow from this source" for your file manager app
4. Open the APK file and tap **Install**
5. Open **AgriGuard AI** — it connects to the live cloud API automatically
6. Tap **Register** to create an account as a Farmer or Buyer

> The app connects to `https://agriguard-ai-production.up.railway.app` by default.  
> No local server or Wi-Fi hotspot required.

---

## App Screens

### Farmer Flow
| Screen | Description |
|---|---|
| Register / Login | Create farmer or buyer account |
| Farmer Dashboard | Overview — farms, recent predictions, diary entries |
| Farm Management | Add and view registered farms (crop, region, district, area) |
| Yield Prediction | Input farm details → get AI yield prediction with confidence interval |
| Crop Diary | Daily log of farm activities (planting, watering, fertilizing, pest events) |
| Post-Harvest Submit | Submit actual harvest yield — feeds the continuous learning pipeline |
| Disease Advisor | Enter crop symptoms → get disease diagnosis and treatment recommendation |

### Buyer Flow
| Screen | Description |
|---|---|
| Buyer Dashboard | Regional supply overview |
| Regional Forecast | 32-crop × region supply forecast for procurement planning |
| Harvest Actuals | View farmer-submitted real yields in your region |

### Disease Screens
| Screen | Description |
|---|---|
| Text Symptom Tab | Describe symptoms in text → instant diagnosis (works on cloud) |
| Image Upload Tab | Upload leaf/stem photo for CNN diagnosis (local API only) |

### Admin
| Screen | Description |
|---|---|
| Admin Dashboard | Platform stats, user counts, model performance |
| Model Comparison | Random Forest vs Gradient Boosting metrics side by side |
| Retrain Model | Trigger model retrain with accumulated farmer data |
| User Management | View all registered users |

---

## How the App Connects to the API

The app uses a single base URL for all API calls. This is configured in two files:

### `lib/config/api_config.dart`
```dart
static const backendBaseUrl = String.fromEnvironment(
  'AGRI_GUARD_BACKEND_URL',
  defaultValue: 'https://agriguard-ai-production.up.railway.app',
);
```

### `lib/services/api_key_service.dart`
```dart
static const _productionUrl = 'https://agriguard-ai-production.up.railway.app';

/// Always returns the production Railway URL.
String get effectiveBackendUrl => _productionUrl;
```

Every API call in the app goes through `ApiKeyService.effectiveBackendUrl` — so all 13 endpoints automatically point to Railway when the APK is installed on a real device.

### Example API Call (Yield Prediction)

```dart
// lib/services/prediction_service.dart
Future<PredictionResult> predict(PredictionRequest req) async {
  final url = Uri.parse('${apiKeyService.effectiveBackendUrl}/api/get-prediction');
  final response = await http.post(
    url,
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode(req.toJson()),
  );
  if (response.statusCode == 200) {
    return PredictionResult.fromJson(jsonDecode(response.body));
  }
  throw Exception('Prediction failed: ${response.statusCode}');
}
```

### Authenticated Requests

After login the API returns a token stored in memory. Authenticated requests include it as a header:

```dart
headers: {
  'Content-Type': 'application/json',
  'Authorization': 'Bearer $token',
}
```

---

## Build From Source

### Prerequisites

- Flutter 3.x (`flutter --version`)
- Android Studio or VS Code with Flutter extension
- Android device with USB debugging OR Android emulator

### Steps

```bash
# From repo root
cd Agri_Guard-AI/ag-ai/agriguard_ai

# Get dependencies
flutter pub get

# Run on connected device (uses Railway API by default)
flutter run

# Build release APK pointing to Railway
flutter build apk --release \
  --dart-define=AGRI_GUARD_BACKEND_URL=https://agriguard-ai-production.up.railway.app

# APK output path:
# build/app/outputs/flutter-apk/app-release.apk
```

### Run with Local API (Development)

```bash
# First set up ADB tunnel so phone can reach your PC's API
adb reverse tcp:8002 tcp:8002

# Run pointing to local API
flutter run --dart-define=AGRI_GUARD_BACKEND_URL=http://127.0.0.1:8002
```

---

## Key Flutter Dependencies

```yaml
# pubspec.yaml
dependencies:
  flutter:
    sdk: flutter
  http: ^1.2.2             # REST API calls
  provider: ^6.1.2         # State management
  shared_preferences: ^2.3.3  # Local storage (API key settings)
  image_picker: ^1.1.2     # Disease image upload
  fl_chart: ^0.70.2        # Yield trend charts
  intl: ^0.19.0            # Date formatting
```

---

## Folder Structure

```
agriguard_ai/lib/
├── config/
│   └── api_config.dart        ← Backend URL and API key defaults
├── models/
│   ├── prediction_result.dart ← Yield prediction response model
│   ├── farm.dart              ← Farm data model
│   └── user.dart              ← User/auth model
├── screens/
│   ├── auth/
│   │   ├── login_screen.dart
│   │   └── register_screen.dart
│   ├── farmer/
│   │   ├── farmer_dashboard.dart
│   │   ├── prediction_screen.dart
│   │   ├── farm_management_screen.dart
│   │   ├── diary_screen.dart
│   │   └── post_harvest_screen.dart
│   ├── buyer/
│   │   ├── buyer_dashboard.dart
│   │   ├── regional_forecast_screen.dart
│   │   └── harvest_actuals_screen.dart
│   ├── disease_screen.dart    ← Text + image disease diagnosis
│   └── admin/
│       ├── admin_dashboard.dart
│       ├── model_comparison_screen.dart
│       └── retrain_screen.dart
├── services/
│   ├── api_key_service.dart   ← Manages backend URL (hardcoded to Railway)
│   ├── auth_service.dart      ← Login, register, token storage
│   ├── prediction_service.dart← Yield prediction API calls
│   └── disease_service.dart   ← Disease advisory API calls
└── main.dart                  ← App entry point, route definitions
```

---

## Troubleshooting

**"Could not connect to server"**  
The app is trying to reach Railway. Check your internet connection. If Railway is down, check https://railway.app/status.

**"Image diagnosis is not available on the cloud server"**  
This is expected. The CNN image model (PyTorch ResNet18) requires 2GB+ and is not available on the Railway free tier. Use the **Text Symptom** tab instead — it works fully on cloud.

**Login not working after reinstalling**  
If you previously had a version pointing to `http://127.0.0.1:8002`, the latest APK hardcodes the Railway URL and will work correctly. Register a new account if your previous account was on a local database only.

**App asks for "unknown sources" permission**  
This is normal for APK files not downloaded from the Google Play Store. Go to **Settings → Security → Install unknown apps** and allow your file manager or browser to install the APK.
