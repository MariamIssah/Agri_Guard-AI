# AgriGuard AI — Flutter Mobile Application

**APK Download:** [AgriGuard-AI.apk](../../AgriGuard-AI.apk) ← Install this on your Android phone
**Live API:** https://agriguard-ai-production.up.railway.app
**Full Project and ML Pipeline Docs:** [ag-ai/README.md](../README.md)

---

## What Is AgriGuard AI?

AgriGuard AI is an agricultural intelligence mobile application built for Ghanaian smallholder farmers. It gives farmers access to four tools in one app:

1. **Yield Prediction** — Enter your crop, region, farm size, and growing conditions to get a personalised yield forecast with a confidence interval, powered by a Gradient Boosting model trained on 902 real MoFA Ghana records (R²=0.9266)
2. **Disease Diagnosis** — Upload a photo of a sick plant or describe symptoms in text to get an instant diagnosis across 38 disease conditions covering 13 Ghanaian crops, with treatment and prevention recommendations
3. **Farm Diary** — Log daily farm activities including fertiliser applications, pest events, irrigation, and weather observations. These entries feed directly into improving your yield predictions over time
4. **Buyer Marketplace** — Farmers list available harvest for sale; buyers view regional supply forecasts by crop and region for procurement planning

The app serves three user roles: **Farmer**, **Buyer**, and **Admin**.

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
| Register | Create a new farmer account with crop and region details |
| Login | Sign in with email/password or Google account |
| Farmer Dashboard | Overview — recent predictions, farm summary, diary entries |
| Farm Management | Add and manage registered farms (crop, region, district, area) |
| Yield Prediction | Enter farm details → get AI yield forecast with confidence interval |
| Prediction History | View past yield predictions for your farms |
| Crop Diary | Daily log — fertiliser, pest events, irrigation, weather, notes |
| Diary History | View all past diary entries by date and season |
| Post-Harvest Submit | Submit actual harvest yield — feeds the continuous learning pipeline |
| Disease Advisor | Text or image disease diagnosis with treatment recommendations |
| Profile | View and update account information |

### Buyer Flow

| Screen | Description |
|---|---|
| Buyer Dashboard | Regional supply overview for procurement planning |
| Regional Forecast | Crop-by-region supply forecast based on farmer data |
| Harvest Actuals | View farmer-submitted real yields available in your region |
| Buyer Activity | Track your browsing and sourcing activity |

### Disease Diagnosis Screens

| Screen | Description |
|---|---|
| Text Symptom Tab | Describe symptoms in text → instant diagnosis (works fully on cloud) |
| Image Upload Tab | Upload leaf or stem photo for CNN image diagnosis (local API only) |
| Diagnosis Result | Disease name, confidence score, treatment steps, prevention advice |

### Admin Screens

| Screen | Description |
|---|---|
| Admin Dashboard | Platform statistics — users, submissions, model performance |
| Model Comparison | Random Forest vs Gradient Boosting metrics side by side |
| Retrain Model | Trigger model retrain with accumulated farmer harvest data |
| User Management | View, manage, and moderate all registered users |
| Submission Log | View all farmer harvest submissions |
| Diary Log | View all farm diary entries across the platform |

---

## How the App Connects to the API

The app uses a single base URL for all API calls, configured in two files:

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

String get effectiveBackendUrl => _productionUrl;
```

Every API call goes through `ApiKeyService.effectiveBackendUrl` — so all endpoints automatically point to Railway when the APK is installed on a real device.

### Example API Call — Yield Prediction

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

- Flutter 3.x — check with `flutter --version`
- Android Studio or VS Code with the Flutter and Dart extensions installed
- Android device with USB debugging enabled, OR an Android emulator
- The API running locally (see [ag-ai/README.md](../README.md)) or use the live Railway URL

### Steps

```bash
# Navigate to the Flutter app directory
cd Agri_Guard-AI/ag-ai/agriguard_ai

# Install Flutter dependencies
flutter pub get

# Run on connected Android device or emulator (uses Railway API by default)
flutter run

# Build a release APK pointing to the Railway production API
flutter build apk --release \
  --dart-define=AGRI_GUARD_BACKEND_URL=https://agriguard-ai-production.up.railway.app

# The built APK will be at:
# build/app/outputs/flutter-apk/app-release.apk
```

### Run with Local API (Development Mode)

If you are running the FastAPI server locally on port 8002:

```bash
# Allow your Android phone to reach your PC's local API over USB
adb reverse tcp:8002 tcp:8002

# Run the Flutter app pointing to your local API
flutter run --dart-define=AGRI_GUARD_BACKEND_URL=http://127.0.0.1:8002
```

---

## Key Flutter Dependencies

```yaml
# pubspec.yaml
dependencies:
  flutter:
    sdk: flutter
  http: ^1.2.2                 # REST API calls to FastAPI backend
  provider: ^6.1.2             # State management across screens
  shared_preferences: ^2.3.3   # Local storage for settings
  image_picker: ^1.1.2         # Disease image upload from camera or gallery
  fl_chart: ^0.70.2            # Yield trend and comparison charts
  intl: ^0.19.0                # Date and number formatting
```

---

## Folder Structure

```
agriguard_ai/lib/
├── config/
│   └── api_config.dart              ← Backend URL configuration
├── models/
│   ├── prediction_result.dart       ← Yield prediction response model
│   ├── farm.dart                    ← Farm data model
│   └── user.dart                    ← User and authentication model
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
│   ├── disease_screen.dart          ← Text and image disease diagnosis
│   └── admin/
│       ├── admin_dashboard.dart
│       ├── model_comparison_screen.dart
│       └── retrain_screen.dart
├── services/
│   ├── api_key_service.dart         ← Backend URL management
│   ├── auth_service.dart            ← Login, register, Google OAuth, token storage
│   ├── prediction_service.dart      ← Yield prediction API calls
│   └── disease_service.dart         ← Disease advisory API calls
└── main.dart                        ← App entry point and route definitions
```

---

## Troubleshooting

**"Could not connect to server"**
The app is trying to reach the Railway API. Check your internet connection. If Railway is down, check https://railway.app/status. If you are in development mode, make sure your local FastAPI server is running on port 8002 and you have run `adb reverse tcp:8002 tcp:8002`.

**"Image diagnosis is not available on the cloud server"**
This is expected. The CNN image model (PyTorch ResNet18) requires 2GB+ of storage and is not available on the Railway free tier. Use the **Text Symptom** tab instead — it uses the rule-based advisory engine and works fully on the cloud without any additional setup.

**Login not working after reinstalling**
If you previously used a version pointing to `http://127.0.0.1:8002` (local development), the latest APK hardcodes the Railway URL. You may need to register a new account if your previous account was on a local database only.

**App asks for "unknown sources" permission**
This is normal for APK files installed outside the Google Play Store. Go to **Settings → Security → Install unknown apps** and allow your file manager or browser to install the file.

**Prediction returns "model not found"**
This means the ML model has not been trained yet on the server. Run `python "Prediction System/compare_models.py"` locally, or trigger a retrain from the Admin screen using the admin key.
