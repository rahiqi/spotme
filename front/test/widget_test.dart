import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spotme/main.dart';

// Mock HttpOverrides to return a successful 200 with a transparent 1x1 PNG for any HTTP requests
class MockHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return MockHttpClient();
  }
}

class MockHttpClient implements HttpClient {
  @override
  Future<HttpClientRequest> getUrl(Uri url) async => MockHttpClientRequest();
  
  @override
  Future<HttpClientRequest> get(String host, int port, String path) async => MockHttpClientRequest();

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class MockHttpClientRequest implements HttpClientRequest {
  @override
  Future<HttpClientResponse> close() async => MockHttpClientResponse();

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class MockHttpClientResponse implements HttpClientResponse {
  @override
  int get statusCode => 200;

  @override
  int get contentLength => 0;

  @override
  HttpClientResponseCompressionState get compressionState => HttpClientResponseCompressionState.notCompressed;

  @override
  HttpHeaders get headers => MockHttpHeaders();

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    // 1x1 transparent PNG
    final bytes = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==');
    return Stream.value(bytes).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class MockHttpHeaders implements HttpHeaders {
  @override
  List<String>? operator [](String name) {
    if (name.toLowerCase() == 'content-type') return ['image/png'];
    return null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Install HTTP overrides globally for the test
  HttpOverrides.global = MockHttpOverrides();

  const MethodChannel geolocatorChannel = MethodChannel('flutter.baseflow.com/geolocator');
  const MethodChannel geolocatorUpdatesChannel = MethodChannel('flutter.baseflow.com/geolocator_updates');
  const MethodChannel backgroundChannel = MethodChannel('id.flutter/background_service');

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(geolocatorChannel, (MethodCall methodCall) async {
      if (methodCall.method == 'checkPermission') {
        return 1; // locationPermission.whileInUse
      }
      if (methodCall.method == 'isLocationServiceEnabled') {
        return true;
      }
      return null;
    });

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(geolocatorUpdatesChannel, (MethodCall methodCall) async {
      return null;
    });

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(backgroundChannel, (MethodCall methodCall) async {
      return null;
    });
  });

  testWidgets('App boots smoke test', (WidgetTester tester) async {
    // Build our app inside ProviderScope
    await tester.pumpWidget(
      const ProviderScope(
        child: SpotMeApp(),
      ),
    );

    // Verify that the app is constructed
    expect(find.byType(SpotMeApp), findsOneWidget);
  });
}
