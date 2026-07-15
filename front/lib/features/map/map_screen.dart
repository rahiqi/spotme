import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spotme/core/theme.dart';
import 'package:spotme/features/location/location_service.dart';
import 'package:spotme/core/config.dart';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'package:spotme/features/auth/telegram_login_screen.dart';
import 'dart:ui';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final MapController _mapController = MapController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _wsController = TextEditingController();
  String _selectedAvatarSeed = "Explorer";
  String? _tempCustomAvatarBase64;
  bool _showWizard = false;
  String _mapThemePref = 'system';
  bool _isChatPanelOpen = false;
  final TextEditingController _chatInputController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadProfileSettings();
  }

  @override
  void dispose() {
    _chatInputController.dispose();
    _chatScrollController.dispose();
    _nameController.dispose();
    _wsController.dispose();
    super.dispose();
  }

  Future<void> _loadProfileSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final nameVal = prefs.getString('name') ?? '';
    final avatarUrl = prefs.getString('avatar_url') ?? '';
    setState(() {
      _nameController.text = nameVal;
      _wsController.text = prefs.getString('ws_url') ?? AppConfig.defaultWsUrl;
      _selectedAvatarSeed = prefs.getString('avatar_seed') ?? 'Explorer';
      _showWizard = nameVal.isEmpty;
      _mapThemePref = prefs.getString('map_theme') ?? 'system';
      if (avatarUrl.startsWith('data:image/')) {
        _tempCustomAvatarBase64 = avatarUrl;
        _selectedAvatarSeed = "custom";
      }
    });
    if (nameVal.isNotEmpty) {
      _centerOnCurrentLocation();
    }
  }

  Future<void> _saveProfileSettings() async {
    final name = _nameController.text.trim();
    final wsUrl = _wsController.text.trim();
    final avatarUrl = _selectedAvatarSeed == "custom"
        ? (_tempCustomAvatarBase64 ?? '')
        : 'https://api.dicebear.com/7.x/bottts/png?seed=$_selectedAvatarSeed';

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('name', name);
    await prefs.setString('ws_url', wsUrl);
    await prefs.setString('avatar_seed', _selectedAvatarSeed);
    await prefs.setString('avatar_url', avatarUrl);

    // Update notifier configuration
    await ref.read(spotMeProvider.notifier).updateProfile(
      name: name,
      avatarUrl: avatarUrl,
      wsUrl: wsUrl,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated successfully!'),
          backgroundColor: AppTheme.primaryColor,
        ),
      );
    }
  }

  void _showProfileDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Profile & Connection Settings'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _handleTelegramLogin(setDialogState),
                      icon: const Icon(Icons.telegram, color: Color(0xFF229ED9)),
                      label: const Text('Sync with Telegram'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF229ED9),
                        side: const BorderSide(color: Color(0xFF229ED9)),
                        minimumSize: const Size(double.infinity, 44),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: AppTheme.surfaceColor,
                      backgroundImage: _getAvatarProvider(
                        _selectedAvatarSeed == "custom"
                            ? (_tempCustomAvatarBase64 ?? '')
                            : 'https://api.dicebear.com/7.x/bottts/png?seed=$_selectedAvatarSeed'
                      ),
                      child: _getAvatarProvider(
                        _selectedAvatarSeed == "custom"
                            ? (_tempCustomAvatarBase64 ?? '')
                            : 'https://api.dicebear.com/7.x/bottts/png?seed=$_selectedAvatarSeed'
                      ) == null ? const Icon(Icons.person, size: 40) : null,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextButton.icon(
                          onPressed: () {
                            setDialogState(() {
                              _selectedAvatarSeed = DateTime.now().millisecondsSinceEpoch.toString();
                              _tempCustomAvatarBase64 = null;
                            });
                          },
                          icon: const Icon(Icons.refresh, color: AppTheme.secondaryColor),
                          label: const Text('Randomize Robot', style: TextStyle(color: AppTheme.secondaryColor, fontSize: 12)),
                        ),
                        const SizedBox(width: 8),
                        TextButton.icon(
                          onPressed: () => _pickCustomAvatar(setDialogState),
                          icon: const Icon(Icons.photo_library, color: AppTheme.primaryColor),
                          label: const Text('Upload Photo', style: TextStyle(color: AppTheme.primaryColor, fontSize: 12)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Display Name',
                        prefixIcon: Icon(Icons.person, color: AppTheme.primaryColor),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    _saveProfileSettings();
                    Navigator.pop(context);
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildTelegramPin(String? avatarUrl, Color color) {
    return SizedBox(
      width: 60,
      height: 70,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          // Pulsing outer ring
          Positioned(
            top: 0,
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: color.withOpacity(0.15), width: 4),
              ),
            ),
          ),
          // Rotated pointer at the bottom to form the pin triangle
          Positioned(
            top: 36,
            child: Transform.rotate(
              angle: 3.14159 / 4,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: color,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 4,
                      offset: const Offset(1, 1),
                    )
                  ],
                ),
              ),
            ),
          ),
          // Main Avatar Circle
          Positioned(
            top: 2,
            child: Container(
              width: 46,
              height: 46,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Container(
                decoration: const BoxDecoration(
                  color: AppTheme.backgroundColor,
                  shape: BoxShape.circle,
                ),
                clipBehavior: Clip.antiAlias,
                child: _buildAvatarImage(avatarUrl, color, 24),
              ),
            ),
          ),
        ],
      ),
    );
  }

  ImageProvider? _getAvatarProvider(String? url) {
    if (url == null || url.isEmpty) {
      return null;
    }
    if (url.startsWith('data:image/')) {
      try {
        final base64Data = url.split(',')[1];
        return MemoryImage(base64Decode(base64Data));
      } catch (_) {
        return null;
      }
    }
    return NetworkImage(url);
  }

  Widget _buildAvatarImage(String? avatarUrl, Color fallbackColor, double iconSize) {
    if (avatarUrl == null || avatarUrl.isEmpty) {
      return Icon(Icons.person, color: fallbackColor, size: iconSize);
    }
    if (avatarUrl.startsWith('data:image/')) {
      try {
        final base64Data = avatarUrl.split(',')[1];
        return Image.memory(
          base64Decode(base64Data),
          fit: BoxFit.cover,
        );
      } catch (_) {
        return Icon(Icons.person, color: fallbackColor, size: iconSize);
      }
    }
    return Image.network(
      avatarUrl,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => Icon(
        Icons.person,
        color: fallbackColor,
        size: iconSize,
      ),
    );
  }

  Future<void> _pickCustomAvatar(StateSetter setDialogState) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 150,
        maxHeight: 150,
        imageQuality: 80,
      );
      if (image != null) {
        final bytes = await image.readAsBytes();
        final base64Str = base64Encode(bytes);
        setDialogState(() {
          _selectedAvatarSeed = "custom";
          _tempCustomAvatarBase64 = "data:image/jpeg;base64,$base64Str";
        });
      }
    } catch (e) {
      debugPrint("Error picking avatar: $e");
    }
  }

  Future<void> _handleTelegramLogin(StateSetter setDialogState) async {
    String wsUrl = _wsController.text.trim();
    String authUrl = 'http://10.0.2.2:3000/auth/telegram';
    if (!wsUrl.contains('10.0.2.2') && !wsUrl.contains('localhost')) {
      authUrl = wsUrl
          .replaceFirst('wss://api.', 'https://')
          .replaceFirst('ws://api.', 'http://')
          .replaceFirst('/ws', '/auth/telegram');
    }

    final result = await Navigator.push<Map<String, String>>(
      context,
      MaterialPageRoute(
        builder: (context) => TelegramLoginScreen(loginUrl: authUrl),
      ),
    );

    if (result != null) {
      final name = result['name'];
      final photoUrl = result['photo_url'];
      if (name != null && name.isNotEmpty) {
        setDialogState(() {
          _nameController.text = name;
          if (photoUrl != null && photoUrl.isNotEmpty) {
            _selectedAvatarSeed = "custom";
            _tempCustomAvatarBase64 = photoUrl;
          }
        });
      }
    }
  }

  Future<void> _centerOnCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 5),
      );
      if (mounted) {
        _mapController.move(LatLng(position.latitude, position.longitude), 15);
      }
    } catch (e) {
      try {
        final lastPosition = await Geolocator.getLastKnownPosition();
        if (lastPosition != null && mounted) {
          _mapController.move(LatLng(lastPosition.latitude, lastPosition.longitude), 15);
        }
      } catch (_) {}
    }
  }

  void _centerOnLocation(double lat, double lng) {
    _mapController.move(LatLng(lat, lng), 15);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(spotMeProvider);
    final notifier = ref.read(spotMeProvider.notifier);

    // Watch for incoming sharing requests reactively
    ref.listen<SpotMeState>(spotMeProvider, (previous, next) {
      if (previous?.incomingRequest == null && next.incomingRequest != null) {
        final req = next.incomingRequest!;
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) {
            return AlertDialog(
              title: const Text('Location Sharing Request'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundImage: _getAvatarProvider(req['requester_profile_image_url'] ?? ''),
                    child: _getAvatarProvider(req['requester_profile_image_url'] ?? '') == null
                        ? const Icon(Icons.person)
                        : null,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '${req['requester_name']} wants to share live location with you.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              ),
              actions: [
                OutlinedButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                    notifier.rejectShare(req['requester_id']);
                  },
                  child: const Text('Decline'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                    notifier.acceptShare(req['requester_id']);
                  },
                  child: const Text('Accept'),
                ),
              ],
            );
          },
        );
      }

      // Auto-center on partner when they publish location for the first time
      if (previous?.partnerLatitude == null && next.partnerLatitude != null) {
        _centerOnLocation(next.partnerLatitude!, next.partnerLongitude!);
      }
    });

    // Prepare map markers
    final List<Marker> markers = [];
    LatLng? userCenter;

    // We can get user location if presence is online, but wait, does Geolocator give us coordinates?
    // Let's see: we can run Geolocator.getLastKnownPosition or display user marker on map.
    // In our state we don't have user's own lat/lng directly stored for UI because geolocator sends it directly to background.
    // Let's modify the notifier/state later to store latest user coordinates, or we can get it from Geolocator directly on UI.
    // Wait, let's keep it simple: we can render the partner's location on the map, and if the user is online,
    // let's fetch user's location via Geolocator stream on the UI thread too! That's very clean and keeps map interactive.
    // Wait, the Geolocator is already running in background, but we can also listen to Geolocator position changes in the UI
    // using a simple StreamBuilder or another position stream, OR we can let the service invoke location changes to the UI
    // as well! Yes! Let's modify `location_service.dart` to broadcast our own location updates to the UI, OR let's just listen to Geolocator on UI thread as well.
    // Actually, listening to Geolocator stream on UI thread is extremely easy:
    // we can use a StreamProvider or simply StreamBuilder.
    // Let's see: let's build a StreamBuilder for Geolocator.getPositionStream to show the user on the map.

    return Scaffold(
      body: Stack(
        children: [
          // 1. Live Map View (CartoDB Dark Matter Theme)
          StreamBuilder<Position>(
            stream: Geolocator.getPositionStream(
              locationSettings: const LocationSettings(
                accuracy: LocationAccuracy.high,
                distanceFilter: 5,
              ),
            ),
            builder: (context, snapshot) {
              LatLng? userLatLng;
              if (snapshot.hasData) {
                userLatLng = LatLng(snapshot.data!.latitude, snapshot.data!.longitude);
                userCenter = userLatLng;
                markers.add(
                  Marker(
                    point: userLatLng,
                    width: 60,
                    height: 70,
                    child: _buildTelegramPin(
                      'https://api.dicebear.com/7.x/bottts/png?seed=$_selectedAvatarSeed',
                      AppTheme.primaryColor,
                    ),
                  ),
                );
              }

              // Add Partner Marker if sharing location
              if (state.isSharing && state.partnerLatitude != null && state.partnerLongitude != null) {
                final partnerLatLng = LatLng(state.partnerLatitude!, state.partnerLongitude!);
                markers.add(
                  Marker(
                    point: partnerLatLng,
                    width: 60,
                    height: 70,
                    child: _buildTelegramPin(
                      state.activePartner?['partner_profile_image_url'] ?? state.activePartner?['profile_image_url'],
                      AppTheme.secondaryColor,
                    ),
                  ),
                );
              }

              final isDarkMode = _mapThemePref == 'dark' || 
                  (_mapThemePref == 'system' && Theme.of(context).brightness == Brightness.dark);
              final mapUrl = isDarkMode
                  ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png'
                  : 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png';

              return FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: userCenter ?? const LatLng(0, 0),
                  initialZoom: 13,
                ),
                children: [
                  TileLayer(
                    urlTemplate: mapUrl,
                    subdomains: const ['a', 'b', 'c', 'd'],
                    userAgentPackageName: 'com.spotme',
                  ),
                  if (state.isSharing && userLatLng != null && state.partnerLatitude != null && state.partnerLongitude != null)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: [userLatLng, LatLng(state.partnerLatitude!, state.partnerLongitude!)],
                          color: AppTheme.primaryColor.withOpacity(0.6),
                          strokeWidth: 4,
                          isDotted: true,
                        ),
                      ],
                    ),
                  MarkerLayer(markers: markers),
                ],
              );
            },
          ),

          // 2. Top Bar (Overlay)
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Glowing Connection Status Indicator
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceColor.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Colors.white.withOpacity(0.08)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: state.isConnected ? Colors.green : Colors.red,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: state.isConnected ? Colors.green : Colors.red,
                              blurRadius: 8,
                              spreadRadius: 1,
                            )
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        state.isConnected ? 'Connected' : 'Offline',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),

                // Profile / Settings Button
                GestureDetector(
                  onTap: _showProfileDialog,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.primaryColor, width: 2),
                    ),
                    child: CircleAvatar(
                      radius: 20,
                      backgroundColor: AppTheme.surfaceColor,
                      backgroundImage: _getAvatarProvider(
                        _selectedAvatarSeed == "custom"
                            ? (_tempCustomAvatarBase64 ?? '')
                            : 'https://api.dicebear.com/7.x/bottts/png?seed=$_selectedAvatarSeed'
                      ),
                      child: _getAvatarProvider(
                        _selectedAvatarSeed == "custom"
                            ? (_tempCustomAvatarBase64 ?? '')
                            : 'https://api.dicebear.com/7.x/bottts/png?seed=$_selectedAvatarSeed'
                      ) == null ? const Icon(Icons.person) : null,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 3. Right Overlay - Discover Users Panel
          Positioned(
            right: 16,
            top: MediaQuery.of(context).padding.top + 80,
            bottom: state.isSharing ? 220 : 120,
            width: 70,
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor.withOpacity(0.8),
                borderRadius: BorderRadius.circular(35),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  const Tooltip(
                    message: "Nearby Users",
                    child: Icon(Icons.radar, color: AppTheme.primaryColor),
                  ),
                  const SizedBox(height: 8),
                  const Divider(color: Colors.white10),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: state.onlineUsers.length,
                      itemBuilder: (context, index) {
                        final user = state.onlineUsers[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: GestureDetector(
                            onTap: () {
                              notifier.requestShare(user['user_id']);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Request sent to ${user['name']}'),
                                  backgroundColor: AppTheme.primaryColor,
                                ),
                              );
                            },
                            child: Tooltip(
                              message: "Share with ${user['name']}",
                              child: CircleAvatar(
                                radius: 22,
                                backgroundColor: AppTheme.backgroundColor,
                                backgroundImage: _getAvatarProvider(user['profile_image_url'] ?? ''),
                                child: _getAvatarProvider(user['profile_image_url'] ?? '') == null
                                    ? const Icon(Icons.person)
                                    : null,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 4. Bottom Controls (Active Share or Start Button)
          Positioned(
            left: 16,
            right: 16,
            bottom: 30,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: state.isSharing
                  ? (_isChatPanelOpen
                      ? _buildChatPanel(state, notifier)
                      : Container(
                          key: const ValueKey('active_share_card'),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceColor.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primaryColor.withOpacity(0.15),
                                blurRadius: 20,
                                spreadRadius: 2,
                              )
                            ],
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 26,
                                backgroundImage: _getAvatarProvider(state.activePartner?['partner_profile_image_url'] ?? ''),
                                child: _getAvatarProvider(state.activePartner?['partner_profile_image_url'] ?? '') == null
                                    ? const Icon(Icons.person)
                                    : null,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text(
                                      'Live Sharing Active',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppTheme.secondaryColor,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      state.activePartner?['partner_name'] ?? 'Partner',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed: () {
                                  if (state.partnerLatitude != null && state.partnerLongitude != null) {
                                    _centerOnLocation(state.partnerLatitude!, state.partnerLongitude!);
                                  }
                                },
                                icon: const Icon(Icons.gps_fixed, color: AppTheme.primaryColor),
                              ),
                              const SizedBox(width: 4),
                              Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  IconButton(
                                    onPressed: () => _openChatPanel(),
                                    icon: const Icon(Icons.chat_bubble_outline, color: AppTheme.primaryColor),
                                  ),
                                  if (state.hasUnreadMessages)
                                    Positioned(
                                      right: 6,
                                      top: 6,
                                      child: Container(
                                        width: 8,
                                        height: 8,
                                        decoration: const BoxDecoration(
                                          color: Colors.red,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: () => notifier.endShare(),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.accentColor,
                                  shadowColor: AppTheme.accentColor.withOpacity(0.4),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                ),
                                child: const Text('End'),
                              ),
                            ],
                          ),
                        ))
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            FloatingActionButton(
                              heroTag: 'mapThemeBtn',
                              onPressed: () async {
                                final prefs = await SharedPreferences.getInstance();
                                String nextTheme = 'system';
                                if (_mapThemePref == 'system') {
                                  nextTheme = 'light';
                                } else if (_mapThemePref == 'light') {
                                  nextTheme = 'dark';
                                } else {
                                  nextTheme = 'system';
                                }
                                await prefs.setString('map_theme', nextTheme);
                                setState(() {
                                  _mapThemePref = nextTheme;
                                });
                              },
                              backgroundColor: AppTheme.surfaceColor,
                              foregroundColor: AppTheme.primaryColor,
                              shape: const CircleBorder(),
                              child: Icon(
                                _mapThemePref == 'system'
                                    ? Icons.brightness_auto
                                    : _mapThemePref == 'light'
                                        ? Icons.light_mode
                                        : Icons.dark_mode,
                              ),
                            ),
                            FloatingActionButton(
                              heroTag: 'centerLocBtn',
                              onPressed: () async {
                                if (await notifier.requestLocationPermission()) {
                                  try {
                                    final pos = await Geolocator.getCurrentPosition();
                                    _centerOnLocation(pos.latitude, pos.longitude);
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Failed to get location: $e'),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                  }
                                } else {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Location permission is required to center on your location.'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                }
                              },
                              backgroundColor: AppTheme.surfaceColor,
                              foregroundColor: AppTheme.primaryColor,
                              shape: const CircleBorder(),
                              child: const Icon(Icons.my_location),
                            ),
                          ],
                        ),
                        // Start Presence Button
                        GestureDetector(
                          onTap: () async {
                            if (state.isPresenceOnline) {
                              notifier.stopPresence();
                            } else {
                              final success = await notifier.startPresence();
                              if (!success && context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Location permissions (including "Allow all the time") are required to stream location.'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          },
                          child: Container(
                            height: 60,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: state.isPresenceOnline
                                    ? [AppTheme.accentColor, AppTheme.accentColor.withOpacity(0.8)]
                                    : [AppTheme.primaryColor, AppTheme.secondaryColor],
                              ),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: (state.isPresenceOnline ? AppTheme.accentColor : AppTheme.primaryColor)
                                      .withOpacity(0.4),
                                  blurRadius: 15,
                                  offset: const Offset(0, 5),
                                )
                              ],
                            ),
                            child: Center(
                              child: Text(
                                state.isPresenceOnline ? 'Stop Sharing Presence' : 'Share My Location',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          
          // 4. Welcome Profile Setup Wizard Overlay
          if (_showWizard)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.85),
                child: Center(
                  child: SingleChildScrollView(
                    child: Container(
                      width: MediaQuery.of(context).size.width * 0.85,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceColor,
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: Colors.white.withOpacity(0.08)),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryColor.withOpacity(0.1),
                            blurRadius: 30,
                            spreadRadius: 5,
                          )
                        ],
                      ),
                      child: StatefulBuilder(
                        builder: (context, setWizardState) {
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 90,
                                height: 90,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: AppTheme.primaryColor, width: 2),
                                ),
                                child: ClipOval(
                                  child: _buildAvatarImage(
                                    _selectedAvatarSeed == "custom"
                                        ? (_tempCustomAvatarBase64 ?? '')
                                        : 'https://api.dicebear.com/7.x/bottts/png?seed=$_selectedAvatarSeed',
                                    Colors.grey,
                                    40,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  TextButton.icon(
                                    onPressed: () {
                                      setWizardState(() {
                                        _selectedAvatarSeed = DateTime.now().millisecondsSinceEpoch.toString();
                                        _tempCustomAvatarBase64 = null;
                                      });
                                    },
                                    icon: const Icon(Icons.refresh, color: AppTheme.secondaryColor),
                                    label: const Text('Randomize Robot', style: TextStyle(color: AppTheme.secondaryColor, fontSize: 12)),
                                  ),
                                  const SizedBox(width: 8),
                                  TextButton.icon(
                                    onPressed: () => _pickCustomAvatar(setWizardState),
                                    icon: const Icon(Icons.photo_library, color: AppTheme.primaryColor),
                                    label: const Text('Upload Photo', style: TextStyle(color: AppTheme.primaryColor, fontSize: 12)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 32),
                              ElevatedButton.icon(
                                onPressed: () => _handleTelegramLogin(setWizardState),
                                icon: const Icon(Icons.telegram, color: Colors.white),
                                label: const Text('Login with Telegram'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF229ED9),
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size(double.infinity, 50),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                              const Row(
                                children: [
                                  Expanded(child: Divider(color: Colors.white10)),
                                  Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 12),
                                    child: Text('OR', style: TextStyle(color: Colors.grey, fontSize: 10)),
                                  ),
                                  Expanded(child: Divider(color: Colors.white10)),
                                ],
                              ),
                              const SizedBox(height: 20),
                              TextField(
                                controller: _nameController,
                                style: const TextStyle(color: Colors.white),
                                decoration: const InputDecoration(
                                  labelText: 'Display Name',
                                  labelStyle: TextStyle(color: Colors.grey),
                                  prefixIcon: Icon(Icons.person, color: AppTheme.primaryColor),
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(height: 32),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryColor,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  minimumSize: const Size(double.infinity, 50),
                                ),
                                onPressed: () async {
                                  final name = _nameController.text.trim();
                                  if (name.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Please enter a display name')),
                                    );
                                    return;
                                  }
                                  final prefs = await SharedPreferences.getInstance();
                                  await prefs.setString('name', name);
                                  await prefs.setString('avatar_seed', _selectedAvatarSeed);
                                  await prefs.setString('ws_url', _wsController.text.trim());
                                  
                                  // Update notifier configuration
                                  await notifier.updateProfile(
                                    name: name,
                                    avatarUrl: 'https://api.dicebear.com/7.x/bottts/png?seed=$_selectedAvatarSeed',
                                    wsUrl: _wsController.text.trim(),
                                  );

                                  setState(() {
                                    _showWizard = false;
                                  });
                                  _centerOnCurrentLocation();
                                },
                                child: const Text(
                                  'Get Started',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          );
                        }
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // --- Chat Panel Implementation ---

  Widget _buildChatPanel(SpotMeState state, SpotMeNotifier notifier) {
    return Container(
      key: const ValueKey('chat_panel_card'),
      height: MediaQuery.of(context).size.height * 0.45,
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor.withOpacity(0.92),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.25)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 20,
            spreadRadius: 2,
          )
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Column(
          children: [
            // Chat Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.06))),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundImage: _getAvatarProvider(state.activePartner?['partner_profile_image_url'] ?? ''),
                    child: _getAvatarProvider(state.activePartner?['partner_profile_image_url'] ?? '') == null
                        ? const Icon(Icons.person, size: 16)
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          state.activePartner?['partner_name'] ?? 'Partner',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        const Text(
                          'Live Chat',
                          style: TextStyle(color: AppTheme.secondaryColor, fontSize: 10, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white60, size: 18),
                    onPressed: () {
                      setState(() {
                        _isChatPanelOpen = false;
                      });
                      notifier.setChatOpen(false);
                    },
                  ),
                ],
              ),
            ),

            // Chat Messages list
            Expanded(
              child: state.chatMessages.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.chat_bubble_outline, color: Colors.white24, size: 30),
                          SizedBox(height: 8),
                          Text(
                            'No messages yet',
                            style: TextStyle(color: Colors.white24, fontSize: 12),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: _chatScrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      itemCount: state.chatMessages.length,
                      itemBuilder: (context, index) {
                        final msg = state.chatMessages[index];
                        final isSelf = msg.senderId == state.userId;
                        return _buildChatBubble(msg, isSelf);
                      },
                    ),
            ),

            // Chat Input bar
            Container(
              padding: EdgeInsets.only(
                left: 16,
                right: 8,
                top: 4,
                bottom: 4 + MediaQuery.of(context).viewInsets.bottom * 0.05,
              ),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.white.withOpacity(0.06))),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _chatInputController,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendChatMessage(notifier),
                      decoration: const InputDecoration(
                        hintText: 'Type a message...',
                        hintStyle: TextStyle(color: Colors.white24, fontSize: 13),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send, color: AppTheme.primaryColor, size: 20),
                    onPressed: () => _sendChatMessage(notifier),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatBubble(ChatMessage msg, bool isSelf) {
    final bubbleColor = isSelf 
        ? AppTheme.primaryColor.withOpacity(0.18) 
        : Colors.white.withOpacity(0.06);
    final align = isSelf ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final bubbleAlign = isSelf ? MainAxisAlignment.end : MainAxisAlignment.start;
    final timeStr = _formatTimestamp(msg.timestamp);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        mainAxisAlignment: bubbleAlign,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(14),
                  topRight: const Radius.circular(14),
                  bottomLeft: Radius.circular(isSelf ? 14 : 3),
                  bottomRight: Radius.circular(isSelf ? 3 : 14),
                ),
                border: Border.all(
                  color: isSelf 
                      ? AppTheme.primaryColor.withOpacity(0.3) 
                      : Colors.white.withOpacity(0.04),
                ),
              ),
              child: Column(
                crossAxisAlignment: align,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    msg.content,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    timeStr,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.35),
                      fontSize: 8,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(int ms) {
    try {
      final date = DateTime.fromMillisecondsSinceEpoch(ms);
      final hour = date.hour.toString().padLeft(2, '0');
      final minute = date.minute.toString().padLeft(2, '0');
      return '$hour:$minute';
    } catch (_) {
      return '';
    }
  }

  void _openChatPanel() {
    setState(() {
      _isChatPanelOpen = true;
    });
    ref.read(spotMeProvider.notifier).setChatOpen(true);
    _scrollToBottom();
  }

  void _sendChatMessage(SpotMeNotifier notifier) {
    final text = _chatInputController.text.trim();
    if (text.isEmpty) return;
    notifier.sendChatMessage(text);
    _chatInputController.clear();
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScrollController.hasClients) {
        _chatScrollController.animateTo(
          _chatScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
        );
      }
    });
  }
}
