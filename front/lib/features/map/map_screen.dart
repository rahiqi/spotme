import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spotme/core/theme.dart';
import 'package:spotme/features/location/location_service.dart';

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

  @override
  void initState() {
    super.initState();
    _loadProfileSettings();
  }

  Future<void> _loadProfileSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _nameController.text = prefs.getString('name') ?? 'User';
      _wsController.text = prefs.getString('ws_url') ?? 'ws://10.0.2.2:8080/ws';
      _selectedAvatarSeed = prefs.getString('avatar_seed') ?? 'Explorer';
    });
  }

  Future<void> _saveProfileSettings() async {
    final name = _nameController.text.trim();
    final wsUrl = _wsController.text.trim();
    if (name.isEmpty || wsUrl.isEmpty) return;

    final avatarUrl = 'https://api.dicebear.com/7.x/bottts/png?seed=$_selectedAvatarSeed';
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('avatar_seed', _selectedAvatarSeed);

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
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: AppTheme.surfaceColor,
                      backgroundImage: NetworkImage(
                        'https://api.dicebear.com/7.x/bottts/png?seed=$_selectedAvatarSeed',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: () {
                        setDialogState(() {
                          _selectedAvatarSeed = DateTime.now().millisecondsSinceEpoch.toString();
                        });
                      },
                      icon: const Icon(Icons.refresh, color: AppTheme.secondaryColor),
                      label: const Text('Randomize Avatar', style: TextStyle(color: AppTheme.secondaryColor)),
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
                    const SizedBox(height: 16),
                    TextField(
                      controller: _wsController,
                      decoration: const InputDecoration(
                        labelText: 'WebSocket Server URL',
                        prefixIcon: Icon(Icons.link, color: AppTheme.primaryColor),
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
                child: avatarUrl != null && avatarUrl.isNotEmpty
                    ? Image.network(
                        avatarUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Icon(
                          Icons.person,
                          color: color,
                          size: 24,
                        ),
                      )
                    : Icon(
                        Icons.person,
                        color: color,
                        size: 24,
                      ),
              ),
            ),
          ),
        ],
      ),
    );
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
                    backgroundImage: NetworkImage(req['requester_profile_image_url'] ?? ''),
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
                    notifier.rejectShare(req['requester_id']);
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('Decline'),
                ),
                ElevatedButton(
                  onPressed: () {
                    notifier.acceptShare(req['requester_id']);
                    Navigator.pop(dialogContext);
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

              return FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: userCenter ?? const LatLng(0, 0),
                  initialZoom: 13,
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
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
                      backgroundImage: NetworkImage(
                        'https://api.dicebear.com/7.x/bottts/png?seed=$_selectedAvatarSeed',
                      ),
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
                                backgroundImage: NetworkImage(user['profile_image_url'] ?? ''),
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
                  ? Container(
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
                            backgroundImage: NetworkImage(state.activePartner?['partner_profile_image_url'] ?? ''),
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
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Map Centering Button
                        Align(
                          alignment: Alignment.centerRight,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 12.0),
                             child: FloatingActionButton(
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
                          ),
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
        ],
      ),
    );
  }
}
