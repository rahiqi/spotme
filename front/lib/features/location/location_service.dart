import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform, HttpClient;
import 'dart:ui' show DartPluginRegistrant;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:spotme/core/config.dart';

// Chat Message Model
class ChatMessage {
  final String id;
  final String senderId;
  final String receiverId;
  final String content;
  final int timestamp; // Milliseconds since epoch

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.content,
    required this.timestamp,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] ?? '',
      senderId: json['sender_id'] ?? '',
      receiverId: json['receiver_id'] ?? '',
      content: json['content'] ?? '',
      timestamp: (json['timestamp'] ?? 0) as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sender_id': senderId,
      'receiver_id': receiverId,
      'content': content,
      'timestamp': timestamp,
    };
  }
}

// State definition
class SpotMeState {
  final bool isConnected;
  final String? userId;
  final List<dynamic> onlineUsers;
  final Map<String, dynamic>? activePartner;
  final double? partnerLatitude;
  final double? partnerLongitude;
  final bool isSharing;
  final Map<String, dynamic>? incomingRequest;
  final bool isPresenceOnline;
  final List<ChatMessage> chatMessages;
  final bool hasUnreadMessages;
  final bool isChatOpen;

  SpotMeState({
    this.isConnected = false,
    this.userId,
    this.onlineUsers = const [],
    this.activePartner,
    this.partnerLatitude,
    this.partnerLongitude,
    this.isSharing = false,
    this.incomingRequest,
    this.isPresenceOnline = false,
    this.chatMessages = const [],
    this.hasUnreadMessages = false,
    this.isChatOpen = false,
  });

  SpotMeState copyWith({
    bool? isConnected,
    String? userId,
    List<dynamic>? onlineUsers,
    Map<String, dynamic>? activePartner,
    double? partnerLatitude,
    double? partnerLongitude,
    bool? isSharing,
    Map<String, dynamic>? incomingRequest,
    bool? isPresenceOnline,
    List<ChatMessage>? chatMessages,
    bool? hasUnreadMessages,
    bool? isChatOpen,
  }) {
    return SpotMeState(
      isConnected: isConnected ?? this.isConnected,
      userId: userId ?? this.userId,
      onlineUsers: onlineUsers ?? this.onlineUsers,
      activePartner: activePartner ?? this.activePartner,
      partnerLatitude: partnerLatitude ?? this.partnerLatitude,
      partnerLongitude: partnerLongitude ?? this.partnerLongitude,
      isSharing: isSharing ?? this.isSharing,
      incomingRequest: incomingRequest ?? this.incomingRequest,
      isPresenceOnline: isPresenceOnline ?? this.isPresenceOnline,
      chatMessages: chatMessages ?? this.chatMessages,
      hasUnreadMessages: hasUnreadMessages ?? this.hasUnreadMessages,
      isChatOpen: isChatOpen ?? this.isChatOpen,
    );
  }
}

// State notifier for UI binding
class SpotMeNotifier extends StateNotifier<SpotMeState> {
  final _service = FlutterBackgroundService();
  
  bool get _isMobile => !kIsWeb && (Platform.isAndroid || Platform.isIOS);
  StreamSubscription? _statusSub;
  StreamSubscription? _authSub;
  StreamSubscription? _usersSub;
  StreamSubscription? _userOnlineSub;
  StreamSubscription? _userOfflineSub;
  StreamSubscription? _reqIncomingSub;
  StreamSubscription? _acceptedSub;
  StreamSubscription? _streamSub;
  StreamSubscription? _endedSub;
  StreamSubscription? _chatMessageSub;
  StreamSubscription? _chatHistorySub;

  SpotMeNotifier() : super(SpotMeState()) {
    _initListeners();
  }

  void _initListeners() {
    if (!_isMobile) return;
    _statusSub = _service.on('ws_status').listen((event) {
      state = state.copyWith(isConnected: event?['connected'] ?? false);
    });

    _authSub = _service.on('auth_success').listen((event) {
      state = state.copyWith(userId: event?['user_id']);
    });

    _usersSub = _service.on('online_users_list').listen((event) {
      state = state.copyWith(onlineUsers: event?['users'] ?? []);
    });

    _userOnlineSub = _service.on('user_online').listen((event) {
      if (event == null) return;
      final newList = List.from(state.onlineUsers);
      newList.removeWhere((u) => u['user_id'] == event['user_id']);
      newList.add(event);
      state = state.copyWith(onlineUsers: newList);
    });

    _userOfflineSub = _service.on('user_offline').listen((event) {
      if (event == null) return;
      final newList = List.from(state.onlineUsers);
      newList.removeWhere((u) => u['user_id'] == event['user_id']);
      state = state.copyWith(onlineUsers: newList);
    });

    _reqIncomingSub = _service.on('share_request_incoming').listen((event) {
      state = state.copyWith(incomingRequest: event);
    });

    _acceptedSub = _service.on('share_accepted').listen((event) {
      if (event == null) return;
      state = state.copyWith(
        activePartner: event,
        isSharing: true,
        incomingRequest: null,
      );
      getChatHistory(event['partner_id']);
    });

    _streamSub = _service.on('location_stream').listen((event) {
      if (event == null) return;
      state = state.copyWith(
        partnerLatitude: event['latitude'],
        partnerLongitude: event['longitude'],
      );
    });

    _endedSub = _service.on('share_ended').listen((event) {
      state = state.copyWith(
        activePartner: null,
        partnerLatitude: null,
        partnerLongitude: null,
        isSharing: false,
        chatMessages: const [],
        hasUnreadMessages: false,
        isChatOpen: false,
      );
    });

    _chatMessageSub = _service.on('chat_message').listen((event) {
      if (event == null) return;
      final msg = ChatMessage.fromJson(Map<String, dynamic>.from(event));
      final updatedList = List<ChatMessage>.from(state.chatMessages)..add(msg);
      state = state.copyWith(
        chatMessages: updatedList,
        hasUnreadMessages: !state.isChatOpen,
      );
    });

    _chatHistorySub = _service.on('chat_history').listen((event) {
      if (event == null) return;
      final list = (event['messages'] as List?) ?? [];
      final messages = list
          .map((m) => ChatMessage.fromJson(Map<String, dynamic>.from(m)))
          .toList();
      state = state.copyWith(
        chatMessages: messages,
      );
    });
  }

  void sendChatMessage(String content) {
    final partner = state.activePartner;
    final selfId = state.userId;
    if (partner == null || selfId == null || content.trim().isEmpty) return;

    final receiverId = partner['partner_id'];
    final tempId = DateTime.now().millisecondsSinceEpoch.toString();
    final localMsg = ChatMessage(
      id: tempId,
      senderId: selfId,
      receiverId: receiverId,
      content: content,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );

    state = state.copyWith(
      chatMessages: List<ChatMessage>.from(state.chatMessages)..add(localMsg),
    );

    if (_isMobile) {
      _service.invoke('send_chat', {
        'receiver_id': receiverId,
        'content': content,
      });
    }
  }

  void getChatHistory(String partnerId) {
    if (_isMobile) {
      _service.invoke('get_chat_history', {
        'partner_id': partnerId,
        'limit': 50,
      });
    }
  }

  void setChatOpen(bool isOpen) {
    state = state.copyWith(
      isChatOpen: isOpen,
      hasUnreadMessages: isOpen ? false : state.hasUnreadMessages,
    );
  }

  Future<void> updateProfile({required String name, required String avatarUrl, required String wsUrl}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('name', name);
    await prefs.setString('avatar_url', avatarUrl);
    await prefs.setString('ws_url', wsUrl);

    if (!_isMobile) return;

    // Guard starting the foreground service with permissions on Android 14+
    if (await requestLocationPermission()) {
      final isRunning = await _service.isRunning();
      if (!isRunning) {
        await _service.startService();
      } else {
        // Notify running service of profile update
        _service.invoke('set_profile', {
          'name': name,
          'avatar_url': avatarUrl,
          'ws_url': wsUrl,
        });
      }
    }
  }

  Future<bool> startPresence() async {
    if (!_isMobile) return false;
    
    // Request permission on UI thread
    if (!await requestLocationPermission()) {
      return false;
    }

    final isRunning = await _service.isRunning();
    if (!isRunning) {
      await _service.startService();
    }

    _service.invoke('start_presence');
    state = state.copyWith(isPresenceOnline: true);
    return true;
  }

  void stopPresence() {
    if (_isMobile) _service.invoke('stop_presence');
    state = state.copyWith(
      isPresenceOnline: false,
      activePartner: null,
      partnerLatitude: null,
      partnerLongitude: null,
      isSharing: false,
    );
  }

  void requestShare(String targetId) {
    if (_isMobile) _service.invoke('share_request', {'target_id': targetId});
  }

  void acceptShare(String requesterId) {
    if (_isMobile) _service.invoke('accept_share', {'requester_id': requesterId});
    state = state.copyWith(incomingRequest: null);
  }

  void rejectShare(String requesterId) {
    if (_isMobile) _service.invoke('reject_share', {'requester_id': requesterId});
    state = state.copyWith(incomingRequest: null);
  }

  void endShare() {
    if (_isMobile && state.activePartner != null) {
      _service.invoke('end_share', {'target_id': state.activePartner!['partner_id']});
    }
    state = state.copyWith(
      activePartner: null,
      partnerLatitude: null,
      partnerLongitude: null,
      isSharing: false,
    );
  }

  Future<bool> requestLocationPermission() async {
    // Request notification permission for Android 13+ FGS notifications
    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }

    var status = await Permission.location.status;
    if (status.isDenied) {
      status = await Permission.location.request();
      if (status.isDenied) return false;
    }

    var backgroundStatus = await Permission.locationAlways.status;
    if (backgroundStatus.isDenied) {
      // Request always permission for background tracking
      backgroundStatus = await Permission.locationAlways.request();
    }

    return status.isGranted || status.isLimited;
  }

  @override
  void dispose() {
    _statusSub?.cancel();
    _authSub?.cancel();
    _usersSub?.cancel();
    _userOnlineSub?.cancel();
    _userOfflineSub?.cancel();
    _reqIncomingSub?.cancel();
    _acceptedSub?.cancel();
    _streamSub?.cancel();
    _endedSub?.cancel();
    _chatMessageSub?.cancel();
    _chatHistorySub?.cancel();
    super.dispose();
  }
}

final spotMeProvider = StateNotifierProvider<SpotMeNotifier, SpotMeState>((ref) {
  return SpotMeNotifier();
});

// Initialization method for background service
Future<void> initializeBackgroundService() async {
  try {
    final service = FlutterBackgroundService();

    // Create Android Notification Channel
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'my_foreground', // id
      'SpotMe Live Tracking', // title
      description: 'Provides real-time location streaming status.',
      importance: Importance.low,
    );

    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    if (!kIsWeb && Platform.isAndroid) {
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: 'my_foreground',
        initialNotificationTitle: 'SpotMe Live',
        initialNotificationContent: 'Connecting...',
        foregroundServiceNotificationId: 888,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: (service) {},
        onBackground: (service) => false,
      ),
    );
  } catch (e) {
    debugPrint("Failed to initialize background service (expected in unit tests): $e");
  }
}

void sendErrorToBackend(String message, String? stackTrace) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    String? wsUrl = prefs.getString('ws_url');
    if (wsUrl != null) {
      final httpUrl = wsUrl.replaceAll('ws://', 'http://').replaceAll('wss://', 'https://').replaceAll('/ws', '/log');
      final client = HttpClient();
      final request = await client.postUrl(Uri.parse(httpUrl));
      request.headers.set('content-type', 'application/json');
      request.add(utf8.encode(jsonEncode({
        'message': message,
        'stack_trace': stackTrace ?? '',
      })));
      await request.close();
    }
  } catch (e) {
    debugPrint("Failed to send log to backend: $e");
  }
}

// Background Isolate Entry Point
@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  WidgetsFlutterBinding.ensureInitialized();

  // Register remote crash reporting inside the background isolate
  FlutterError.onError = (FlutterErrorDetails details) {
    sendErrorToBackend("Background Isolate FlutterError: ${details.exception}", details.stack?.toString());
  };

  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });
    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });
  }

  final prefs = await SharedPreferences.getInstance();
  WebSocketChannel? channel;
  StreamSubscription<Position>? positionSubscription;
  bool isPresenceStarted = false;

  String wsUrl = prefs.getString('ws_url') ?? AppConfig.defaultWsUrl;
  String? userId = prefs.getString('user_id');
  String? name = prefs.getString('name');
  String? avatarUrl = prefs.getString('avatar_url');

  void sendWsMessage(String type, Map<String, dynamic> payload) {
    if (channel != null) {
      try {
        final msg = jsonEncode({'type': type, 'payload': payload});
        channel!.sink.add(msg);
      } catch (e) {
        debugPrint("Error sending message: $e");
      }
    }
  }

  void startLocationStreaming() {
    positionSubscription?.cancel();
    positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen((Position position) {
      // Update foreground notification info
      if (service is AndroidServiceInstance) {
        service.setForegroundNotificationInfo(
          title: "SpotMe Live",
          content: "Broadcasting location...",
        );
      }

      sendWsMessage('location_update', {
        'latitude': position.latitude,
        'longitude': position.longitude,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });

      sendWsMessage('start_presence', {
        'latitude': position.latitude,
        'longitude': position.longitude,
      });
    });
  }

  void stopLocationStreaming() {
    positionSubscription?.cancel();
    positionSubscription = null;
    if (service is AndroidServiceInstance) {
      service.setForegroundNotificationInfo(
        title: "SpotMe Online",
        content: "$name is active",
      );
    }
  }

  void connect() {
    if (channel != null) return;
    if (name == null || name!.isEmpty) {
      service.invoke('ws_status', {'connected': false});
      return;
    }

    try {
      channel = IOWebSocketChannel.connect(
        Uri.parse(wsUrl),
        connectTimeout: const Duration(seconds: 10),
      );

      // Send auth frame immediately
      sendWsMessage('auth', {
        'user_id': userId,
        'name': name!,
        'profile_image_url': avatarUrl ?? '',
      });

      service.invoke('ws_status', {'connected': true});
      if (service is AndroidServiceInstance) {
        service.setForegroundNotificationInfo(
          title: "SpotMe Online",
          content: "$name is active",
        );
      }

      channel!.stream.listen((message) {
        try {
          final data = jsonDecode(message);
          final String type = data['type'];
          final payload = data['payload'];

          if (type == 'auth_success') {
            userId = payload['user_id'];
            prefs.setString('user_id', userId!);
          }

          if (type == 'share_accepted') {
            startLocationStreaming();
          }

          if (type == 'share_ended') {
            if (!isPresenceStarted) {
              stopLocationStreaming();
            }
          }

          service.invoke(type, payload);
        } catch (e) {
          debugPrint("Failed to decode message: $e");
        }
      }, onDone: () {
        channel = null;
        service.invoke('ws_status', {'connected': false});
        if (service is AndroidServiceInstance) {
          service.setForegroundNotificationInfo(
            title: "SpotMe Disconnected",
            content: "Reconnecting...",
          );
        }
        Future.delayed(const Duration(seconds: 5), () {
          connect();
        });
      }, onError: (e) {
        channel = null;
        service.invoke('ws_status', {'connected': false});
        Future.delayed(const Duration(seconds: 5), () {
          connect();
        });
      });
    } catch (e) {
      channel = null;
      service.invoke('ws_status', {'connected': false});
      Future.delayed(const Duration(seconds: 5), connect);
    }
  }

  connect();

  service.on('set_profile').listen((event) {
    name = event?['name'];
    avatarUrl = event?['avatar_url'];
    wsUrl = event?['ws_url'] ?? wsUrl;
    
    if (name != null) prefs.setString('name', name!);
    if (avatarUrl != null) prefs.setString('avatar_url', avatarUrl!);
    prefs.setString('ws_url', wsUrl);

    if (channel != null) {
      channel!.sink.close();
      channel = null;
    }
    connect();
  });

  service.on('start_presence').listen((event) async {
    isPresenceStarted = true;
    connect(); // Ensure we connect if profile is now available
    startLocationStreaming();
  });

  service.on('stop_presence').listen((event) {
    isPresenceStarted = false;
    stopLocationStreaming();
    sendWsMessage('stop_presence', {});
    
    if (service is AndroidServiceInstance) {
      service.setForegroundNotificationInfo(
        title: "SpotMe Idle",
        content: "Tap to view map",
      );
    }
  });

  service.on('share_request').listen((event) {
    final targetId = event?['target_id'];
    sendWsMessage('share_request', {'target_id': targetId});
  });

  service.on('accept_share').listen((event) {
    final requesterId = event?['requester_id'];
    sendWsMessage('accept_share', {'requester_id': requesterId});
  });

  service.on('reject_share').listen((event) {
    final requesterId = event?['requester_id'];
    sendWsMessage('reject_share', {'requester_id': requesterId});
  });

  service.on('end_share').listen((event) {
    final targetId = event?['target_id'];
    sendWsMessage('end_share', {'target_id': targetId});
  });

  service.on('send_chat').listen((event) {
    final receiverId = event?['receiver_id'];
    final content = event?['content'];
    if (receiverId != null && content != null) {
      sendWsMessage('send_chat', {
        'receiver_id': receiverId,
        'content': content,
      });
    }
  });

  service.on('get_chat_history').listen((event) {
    final partnerId = event?['partner_id'];
    final limit = event?['limit'];
    if (partnerId != null) {
      sendWsMessage('get_chat_history', {
        'partner_id': partnerId,
        'limit': limit,
      });
    }
  });
}
