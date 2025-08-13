import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlng;
import 'package:geolocator/geolocator.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:developer' as developer;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _initializeNotifications();
  runApp(const MyApp());
}

Future<void> _initializeNotifications() async {
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  final InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );
  await FlutterLocalNotificationsPlugin().initialize(initializationSettings);
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'نقشه و موقعیت',
      theme: ThemeData(
        primarySwatch: Colors.teal,
        fontFamily: 'Vazir',
        visualDensity: VisualDensity.adaptivePlatformDensity,
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            backgroundColor: Colors.teal,
            foregroundColor: Colors.white,
          ),
        ),
        scaffoldBackgroundColor: Colors.grey[50],
        appBarTheme: const AppBarTheme(
          elevation: 0,
          centerTitle: true,
          backgroundColor: Colors.teal,
        ),
      ),
      home: const TaskSelectionScreen(),
    );
  }
}

class TaskSelectionScreen extends StatelessWidget {
  const TaskSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('انتخاب تسک')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildAnimatedButton(
              context,
              'تسک 1: نمایش آدرس',
              () => Navigator.push(
                context,
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) =>
                      const Task1Screen(),
                  transitionsBuilder:
                      (context, animation, secondaryAnimation, child) {
                        return FadeTransition(opacity: animation, child: child);
                      },
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildAnimatedButton(
              context,
              'تسک دوم',
              () => Navigator.push(
                context,
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) =>
                      const Task2Screen(),
                  transitionsBuilder:
                      (context, animation, secondaryAnimation, child) {
                        return FadeTransition(opacity: animation, child: child);
                      },
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildAnimatedButton(
              context,
              'تسک سوم: مسیر یابی',
              () => Navigator.push(
                context,
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) =>
                      const Task3Screen(),
                  transitionsBuilder:
                      (context, animation, secondaryAnimation, child) {
                        return FadeTransition(opacity: animation, child: child);
                      },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedButton(
    BuildContext context,
    String text,
    VoidCallback onPressed,
  ) {
    return AnimatedScaleButton(
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: ElevatedButton(
            onPressed: onPressed,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(250, 60),
              backgroundColor: Colors.teal.withOpacity(0.9),
            ),
            child: Text(text, style: const TextStyle(fontSize: 18)),
          ),
        ),
      ),
    );
  }
}

class AnimatedScaleButton extends StatefulWidget {
  final Widget child;
  const AnimatedScaleButton({super.key, required this.child});

  @override
  State<AnimatedScaleButton> createState() => _AnimatedScaleButtonState();
}

class _AnimatedScaleButtonState extends State<AnimatedScaleButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(scale: _scaleAnimation, child: widget.child),
    );
  }
}

// Task 1: Display address for any selected point
class Task1Screen extends StatefulWidget {
  const Task1Screen({super.key});

  @override
  State<Task1Screen> createState() => _Task1ScreenState();
}

class _Task1ScreenState extends State<Task1Screen> {
  final MapController _mapController = MapController();
  latlng.LatLng? _currentPosition;
  latlng.LatLng? _selectedPoint;
  bool _isLoading = true;
  // Fallback location: Mashhad, Iran
  final latlng.LatLng _fallbackPosition = const latlng.LatLng(36.2970, 59.6062);

  @override
  void initState() {
    super.initState();
    Future.microtask(_checkPermissionsAndGetLocation);
  }

  Future<void> _checkPermissionsAndGetLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'لطفا GPS را فعال کنید، استفاده از موقعیت پیش‌فرض (مشهد)',
            ),
          ),
        );
        setState(() {
          _currentPosition = _fallbackPosition;
          _isLoading = false;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _mapController.move(_currentPosition!, 15.0);
          }
        });
      }
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'دسترسی به مکان رد شد، استفاده از موقعیت پیش‌فرض (مشهد)',
              ),
            ),
          );
          setState(() {
            _currentPosition = _fallbackPosition;
            _isLoading = false;
          });
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _mapController.move(_currentPosition!, 15.0);
            }
          });
        }
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'دسترسی به مکان به طور دائم رد شده است، استفاده از موقعیت پیش‌فرض (مشهد)',
            ),
          ),
        );
        setState(() {
          _currentPosition = _fallbackPosition;
          _isLoading = false;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _mapController.move(_currentPosition!, 15.0);
          }
        });
      }
      return;
    }

    // Retry logic for location acquisition
    for (int attempt = 1; attempt <= 3; attempt++) {
      try {
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        ).timeout(const Duration(seconds: 5));
        if (mounted) {
          final newPosition = latlng.LatLng(
            position.latitude,
            position.longitude,
          );
          setState(() {
            _currentPosition = newPosition;
            _isLoading = false;
          });
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _mapController.move(_currentPosition!, 15.0);
            }
          });
          return; // Exit on success
        }
      } catch (e) {
        if (attempt == 3 && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'خطا در دریافت موقعیت پس از $attempt تلاش: $e، استفاده از موقعیت پیش‌فرض (مشهد)',
              ),
            ),
          );
          setState(() {
            _currentPosition = _fallbackPosition;
            _isLoading = false;
          });
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _mapController.move(_currentPosition!, 15.0);
            }
          });
        }
      }
    }
  }

  Future<void> _showAddressPopup(latlng.LatLng point) async {
    setState(() {
      _selectedPoint = point;
    });

    try {
      final response = await http.get(
        Uri.parse(
          'https://nominatim.openstreetmap.org/reverse?format=json&lat=${point.latitude}&lon=${point.longitude}&zoom=18&addressdetails=1',
        ),
        headers: {'User-Agent': 'com.example.apishro/1.0'},
      );
      final data = jsonDecode(response.body);
      if (data['address'] != null && mounted) {
        final address = data['address'];
        String detailedAddress = [
          address['road'] ?? '',
          address['neighbourhood'] ?? '',
          address['suburb'] ?? '',
          address['city'] ?? '',
          address['country'] ?? '',
        ].where((e) => e.isNotEmpty).join(', ');

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text('آدرس نقطه انتخاب شده'),
            content: Text(
              detailedAddress.isEmpty ? 'آدرس یافت نشد' : detailedAddress,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('بستن', style: TextStyle(color: Colors.teal)),
              ),
            ],
          ),
        );
      } else {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('آدرس یافت نشد')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('خطا در دریافت آدرس: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('نمایش آدرس')),
      body: _isLoading || _currentPosition == null
          ? const Center(child: CircularProgressIndicator.adaptive())
          : FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _currentPosition!,
                initialZoom: 15.0,
                onTap: (tapPosition, point) => _showAddressPopup(point),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.apishro',
                  tileProvider: NetworkTileProvider(),
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _currentPosition!,
                      width: 40,
                      height: 40,
                      child: const Icon(
                        Icons.location_pin,
                        color: Colors.red,
                        size: 40,
                      ),
                    ),
                    if (_selectedPoint != null)
                      Marker(
                        point: _selectedPoint!,
                        width: 40,
                        height: 40,
                        child: const Icon(
                          Icons.location_on,
                          color: Colors.blue,
                          size: 40,
                        ),
                      ),
                  ],
                ),
              ],
            ),
    );
  }
}

// Task 2: Proximity alerts for points
class Task2Screen extends StatefulWidget {
  const Task2Screen({super.key});

  @override
  State<Task2Screen> createState() => _Task2ScreenState();
}

class _Task2ScreenState extends State<Task2Screen> {
  final MapController _mapController = MapController();
  latlng.LatLng? _currentPosition;
  List<latlng.LatLng> _markers = [];
  bool _isLoading = true;
  // Fallback location: Mashhad, Iran
  final latlng.LatLng _fallbackPosition = const latlng.LatLng(36.2970, 59.6062);

  @override
  void initState() {
    super.initState();
    Future.microtask(_checkPermissionsAndStartTracking);
  }

  Future<void> _checkPermissionsAndStartTracking() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'لطفا GPS را فعال کنید، استفاده از موقعیت پیش‌فرض (مشهد)',
            ),
          ),
        );
        setState(() {
          _currentPosition = _fallbackPosition;
          _isLoading = false;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _mapController.move(_currentPosition!, 15.0);
          }
        });
      }
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'دسترسی به مکان رد شد، استفاده از موقعیت پیش‌فرض (مشهد)',
              ),
            ),
          );
          setState(() {
            _currentPosition = _fallbackPosition;
            _isLoading = false;
          });
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _mapController.move(_currentPosition!, 15.0);
            }
          });
        }
        return;
      }
    }

    try {
      // Retry logic for location acquisition
      for (int attempt = 1; attempt <= 3; attempt++) {
        try {
          Position position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
          ).timeout(const Duration(seconds: 5));
          if (mounted) {
            setState(() {
              _currentPosition = latlng.LatLng(
                position.latitude,
                position.longitude,
              );
              _isLoading = false;
            });
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _mapController.move(_currentPosition!, 15.0);
              }
            });

            Geolocator.getPositionStream(
              locationSettings: const LocationSettings(
                accuracy: LocationAccuracy.high,
                distanceFilter: 10,
              ),
            ).listen((Position position) {
              if (mounted) {
                setState(() {
                  _currentPosition = latlng.LatLng(
                    position.latitude,
                    position.longitude,
                  );
                });
                _checkProximityToMarkers();
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    _mapController.move(_currentPosition!, 15.0);
                  }
                });
              }
            });
            return; // Exit on success
          }
        } catch (e) {
          if (attempt == 3 && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'خطا در دریافت موقعیت پس از $attempt تلاش: $e، استفاده از موقعیت پیش‌فرض (مشهد)',
                ),
              ),
            );
            setState(() {
              _currentPosition = _fallbackPosition;
              _isLoading = false;
            });
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _mapController.move(_currentPosition!, 15.0);
              }
            });
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'خطا در دریافت موقعیت: $e، استفاده از موقعیت پیش‌فرض (مشهد)',
            ),
          ),
        );
        setState(() {
          _currentPosition = _fallbackPosition;
          _isLoading = false;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _mapController.move(_currentPosition!, 15.0);
          }
        });
      }
    }
  }

  void _addMarker(latlng.LatLng position) {
    setState(() {
      _markers.add(position);
    });
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('نقطه جدید اضافه شد')));
      _checkProximityToNewMarker(position);
    }
  }

  Future<void> _checkProximityToNewMarker(latlng.LatLng marker) async {
    if (_currentPosition == null) return;

    double distance = Geolocator.distanceBetween(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      marker.latitude,
      marker.longitude,
    );
    if (distance <= 300 && mounted) {
      await FlutterLocalNotificationsPlugin().show(
        marker.hashCode,
        'نزدیک شدن به نقطه',
        'به منطقه 300 متری نقطه ${marker.latitude}, ${marker.longitude} رسیدید',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'proximity_channel',
            'Proximity Alerts',
            importance: Importance.high,
          ),
        ),
      );
    }
  }

  Future<void> _checkProximityToMarkers() async {
    if (_currentPosition == null) return;

    for (var marker in _markers) {
      double distance = Geolocator.distanceBetween(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        marker.latitude,
        marker.longitude,
      );
      if (distance <= 300 && mounted) {
        await FlutterLocalNotificationsPlugin().show(
          marker.hashCode,
          'نزدیک شدن به نقطه',
          'به منطقه 300 متری نقطه ${marker.latitude}, ${marker.longitude} رسیدید',
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'proximity_channel',
              'Proximity Alerts',
              importance: Importance.high,
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('اعلان نزدیکی')),
      body: _isLoading || _currentPosition == null
          ? const Center(child: CircularProgressIndicator.adaptive())
          : FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _currentPosition!,
                initialZoom: 15.0,
                onTap: (tapPosition, point) => _addMarker(point),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.apishro',
                  tileProvider: NetworkTileProvider(),
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _currentPosition!,
                      width: 40,
                      height: 40,
                      child: const Icon(
                        Icons.location_pin,
                        color: Colors.red,
                        size: 40,
                      ),
                    ),
                    ..._markers.map(
                      (marker) => Marker(
                        point: marker,
                        width: 30,
                        height: 30,
                        child: const Icon(
                          Icons.location_on,
                          color: Colors.blue,
                          size: 30,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}

// Task 3: Route between two points with mode selection
class Task3Screen extends StatefulWidget {
  const Task3Screen({super.key});

  @override
  State<Task3Screen> createState() => _Task3ScreenState();
}

class _Task3ScreenState extends State<Task3Screen> {
  final MapController _mapController = MapController();
  latlng.LatLng? _currentPosition;
  latlng.LatLng? _origin;
  latlng.LatLng? _destination;
  List<latlng.LatLng> _polylinePoints = [];
  bool _isLoading = true;
  String _selectedMode = 'car'; // Default to car
  // Fallback location: Mashhad, Iran
  final latlng.LatLng _fallbackPosition = const latlng.LatLng(36.2970, 59.6062);
  // OpenRouteService API key
  final String _apiKey =
      'eyJvcmciOiI1YjNjZTM1OTc4NTExMTAwMDFjZjYyNDgiLCJpZCI6ImRkNzBlMjg5ZDEyZTQ5MDQ5ZjZjN2ZiNTE1ZGEyZWMyIiwiaCI6Im11cm11cjY0In0=';

  @override
  void initState() {
    super.initState();
    Future.microtask(_checkPermissionsAndGetLocation);
  }

  Future<void> _checkPermissionsAndGetLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'لطفا GPS را فعال کنید، استفاده از موقعیت پیش‌فرض (مشهد)',
            ),
          ),
        );
        setState(() {
          _currentPosition = _fallbackPosition;
          _isLoading = false;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _mapController.move(_currentPosition!, 15.0);
          }
        });
      }
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'دسترسی به مکان رد شد، استفاده از موقعیت پیش‌فرض (مشهد)',
              ),
            ),
          );
          setState(() {
            _currentPosition = _fallbackPosition;
            _isLoading = false;
          });
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _mapController.move(_currentPosition!, 15.0);
            }
          });
        }
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'دسترسی به مکان به طور دائم رد شده است، استفاده از موقعیت پیش‌فرض (مشهد)',
            ),
          ),
        );
        setState(() {
          _currentPosition = _fallbackPosition;
          _isLoading = false;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _mapController.move(_currentPosition!, 15.0);
          }
        });
      }
      return;
    }

    try {
      for (int attempt = 1; attempt <= 3; attempt++) {
        try {
          Position position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
          ).timeout(const Duration(seconds: 5));
          if (mounted) {
            setState(() {
              _currentPosition = latlng.LatLng(
                position.latitude,
                position.longitude,
              );
              _isLoading = false;
            });
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _mapController.move(_currentPosition!, 15.0);
              }
            });
            return;
          }
        } catch (e) {
          if (attempt == 3 && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'خطا در دریافت موقعیت پس از $attempt تلاش: $e، استفاده از موقعیت پیش‌فرض (مشهد)',
                ),
              ),
            );
            setState(() {
              _currentPosition = _fallbackPosition;
              _isLoading = false;
            });
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _mapController.move(_currentPosition!, 15.0);
              }
            });
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'خطا در دریافت موقعیت: $e، استفاده از موقعیت پیش‌فرض (مشهد)',
            ),
          ),
        );
        setState(() {
          _currentPosition = _fallbackPosition;
          _isLoading = false;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _mapController.move(_currentPosition!, 15.0);
          }
        });
      }
    }
  }

  void _addPoint(latlng.LatLng position) {
    setState(() {
      if (_origin == null) {
        _origin = position;
      } else if (_destination == null) {
        _destination = position;
        _drawRoute();
      } else {
        _origin = position;
        _destination = null;
        _polylinePoints.clear();
      }
    });
  }

  Future<void> _drawRoute() async {
    if (_origin == null || _destination == null) return;

    bool routeFound = false;
    for (int attempt = 1; attempt <= 2; attempt++) {
      routeFound = await _tryDrawRoute(_selectedMode);
      if (routeFound) break;
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        developer.log('Retrying route fetch, attempt $attempt');
      }
    }

    if (!routeFound && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'هیچ مسیری یافت نشد، لطفا نقاط نزدیک به جاده یا مسیر پیاده‌رو انتخاب کنید',
          ),
        ),
      );
    }
  }

  Future<bool> _tryDrawRoute(String vehicle) async {
    try {
      final String profile = vehicle == 'car' ? 'driving-car' : 'foot-walking';
      final String body = jsonEncode({
        'coordinates': [
          [_origin!.longitude, _origin!.latitude],
          [_destination!.longitude, _destination!.latitude],
        ],
        'preference': 'fastest',
        'units': 'm',
        'geometry': true,
        'instructions': false,
        'elevation': false,
        'geometry_simplify': true,
      });

      final response = await http
          .post(
            Uri.parse(
              'https://api.openrouteservice.org/v2/directions/$profile/geojson',
            ),
            headers: {
              'Authorization': _apiKey,
              'Content-Type': 'application/json',
              'User-Agent': 'com.example.apishro/1.0',
            },
            body: body,
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        if (mounted) {
          developer.log(
            'OpenRouteService API error: ${response.statusCode} - ${response.body}',
          );
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'خطای API: ${response.statusCode} - ${response.body}',
              ),
            ),
          );
        }
        return false;
      }

      final data = jsonDecode(response.body);
      developer.log('OpenRouteService response: ${response.body}');

      if (data is Map && data.containsKey('error')) {
        if (mounted) {
          developer.log(
            'OpenRouteService API error message: ${data['error']['message']}',
          );
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('خطای API: ${data['error']['message']}')),
          );
        }
        return false;
      }

      if (data is Map &&
          data['features'] != null &&
          data['features'].isNotEmpty &&
          data['features'][0]['geometry']['coordinates'] != null) {
        final coordinates =
            data['features'][0]['geometry']['coordinates'] as List<dynamic>;
        final List<latlng.LatLng> routePoints = coordinates
            .map<latlng.LatLng>(
              (point) => latlng.LatLng(
                (point[1] as num).toDouble(),
                (point[0] as num).toDouble(),
              ),
            )
            .toList();

        if (routePoints.isEmpty) {
          if (mounted) {
            developer.log(
              'No valid coordinates found in response: ${response.body}',
            );
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('هیچ مختصات معتبری یافت نشد')),
            );
          }
          return false;
        }

        setState(() {
          _polylinePoints = routePoints;
        });

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _mapController.fitCamera(
              CameraFit.coordinates(
                coordinates: [_origin!, _destination!, ..._polylinePoints],
                padding: const EdgeInsets.all(50),
              ),
            );
          }
        });
        return true;
      } else {
        if (mounted) {
          developer.log('Invalid response format: ${response.body}');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('پاسخ نامعتبر از API، لطفا نقاط معتبر انتخاب کنید'),
            ),
          );
        }
        return false;
      }
    } catch (e) {
      if (mounted) {
        developer.log('Error fetching route ($vehicle): $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطا در دریافت مسیر ($vehicle): $e')),
        );
      }
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('مسیر یابی')),
      body: _isLoading || _currentPosition == null
          ? const Center(child: CircularProgressIndicator.adaptive())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: DropdownButton<String>(
                    value: _selectedMode,
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        setState(() {
                          _selectedMode = newValue;
                          _polylinePoints.clear();
                          _origin = null;
                          _destination = null;
                        });
                      }
                    },
                    items: <String>['car', 'foot']
                        .map<DropdownMenuItem<String>>((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value == 'car' ? 'ماشین' : 'پیاده'),
                          );
                        })
                        .toList(),
                    style: const TextStyle(
                      fontFamily: 'Vazir',
                      fontSize: 16,
                      color: Colors.black,
                    ),
                    isExpanded: true,
                  ),
                ),
                Expanded(
                  child: FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _currentPosition!,
                      initialZoom: 15.0,
                      onTap: (tapPosition, point) => _addPoint(point),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.example.apishro',
                        tileProvider: NetworkTileProvider(),
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _currentPosition!,
                            width: 40,
                            height: 40,
                            child: const Icon(
                              Icons.location_pin,
                              color: Colors.red,
                              size: 40,
                            ),
                          ),
                          if (_origin != null)
                            Marker(
                              point: _origin!,
                              width: 40,
                              height: 40,
                              child: const Icon(
                                Icons.location_pin,
                                color: Colors.green,
                                size: 40,
                              ),
                            ),
                          if (_destination != null)
                            Marker(
                              point: _destination!,
                              width: 40,
                              height: 40,
                              child: const Icon(
                                Icons.location_pin,
                                color: Colors.blue,
                                size: 40,
                              ),
                            ),
                        ],
                      ),
                      PolylineLayer(
                        polylines: [
                          if (_polylinePoints.isNotEmpty)
                            Polyline(
                              points: _polylinePoints,
                              strokeWidth: 5.0,
                              color: _selectedMode == 'foot'
                                  ? Colors.red
                                  : Colors.blue,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
