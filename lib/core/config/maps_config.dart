/// Google Maps API configuration.
///
/// API key is read from platform config (AndroidManifest.xml, Info.plist/AppDelegate).
/// For build-time override, use: flutter run --dart-define=GOOGLE_MAPS_API_KEY=your_key
const String mapsApiKey = String.fromEnvironment(
  'GOOGLE_MAPS_API_KEY',
  defaultValue: 'AIzaSyA6EcL6hrD0iQpwk6ETUQNSieeEBYUR1_U',
);
