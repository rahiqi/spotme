import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spotme/core/theme.dart';
import 'package:spotme/features/location/location_service.dart';
import 'package:spotme/features/map/map_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Register remote crash reporting inside the main isolate
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    sendErrorToBackend("Main Isolate FlutterError: ${details.exception}", details.stack?.toString());
  };

  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    sendErrorToBackend("Main Isolate PlatformDispatcher Error: $error", stack.toString());
    return true;
  };

  // Initialize background location tracking services
  await initializeBackgroundService();
  
  runApp(
    const ProviderScope(
      child: SpotMeApp(),
    ),
  );
}

class SpotMeApp extends StatelessWidget {
  const SpotMeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SpotMe Live',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: AppTheme.darkTheme,
      home: const MapScreen(),
    );
  }
}
