# ant

A new Flutter project.

## API environment

The app reads its backend URL from `API_BASE_URL` in
`lib/config/api_config.dart`.

Local backend on iOS simulator or macOS:

```sh
flutter run --dart-define=API_BASE_URL=http://localhost:8080
```

Local backend from Android emulator:

```sh
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080
```

Hosted staging backend:

```sh
flutter run --dart-define=API_BASE_URL=https://bodyperfect-backend.onrender.com
```

Render free services can sleep when inactive, so the first API call after idle
time may take longer than normal while the backend wakes up.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
