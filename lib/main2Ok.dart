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
      title: 'NeshanPishro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.teal,
        fontFamily: 'Vazir',
        visualDensity: VisualDensity.adaptivePlatformDensity,
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
            backgroundColor: Colors.teal.shade600,
            foregroundColor: Colors.white,
            elevation: 4,
            shadowColor: Colors.teal.withOpacity(0.3),
          ),
        ),
        scaffoldBackgroundColor: Colors.grey[100],
        appBarTheme: AppBarTheme(
          elevation: 2,
          centerTitle: true,
          backgroundColor: Colors.teal.shade700,
          titleTextStyle: const TextStyle(
            fontFamily: 'Vazir',
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Colors.teal,
          foregroundColor: Colors.white,
          elevation: 6,
          shape: CircleBorder(),
        ),
        cardTheme: CardThemeData(
          elevation: 6,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          color: Colors.white,
          shadowColor: Colors.teal.withOpacity(0.2),
        ),
      ),
      home: const PermissionRequestScreen(),
    );
  }
}

class PermissionRequestScreen extends StatefulWidget {
  const PermissionRequestScreen({super.key});

  @override
  State<PermissionRequestScreen> createState() =>
      _PermissionRequestScreenState();
}

class _PermissionRequestScreenState extends State<PermissionRequestScreen> {
  bool _isChecking = true;

  @override
  void initState() {
    super.initState();
    Future.microtask(_checkPermissions);
  }

  Future<void> _checkPermissions() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse) {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const TaskSelectionScreen()),
        );
      }
    } else {
      setState(() {
        _isChecking = false;
      });
    }
  }

  Future<void> _requestPermission() async {
    setState(() {
      _isChecking = true;
    });
    LocationPermission permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse) {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const TaskSelectionScreen()),
        );
      }
    } else {
      setState(() {
        _isChecking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: _isChecking
            ? const CircularProgressIndicator.adaptive()
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'برای استفاده از اپلیکیشن، لطفاً دسترسی به مکان را فعال کنید',
                    style: TextStyle(
                      fontFamily: 'Vazir',
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _requestPermission,
                    child: const Text('درخواست دسترسی'),
                  ),
                ],
              ),
      ),
    );
  }
}

class TaskSelectionScreen extends StatefulWidget {
  const TaskSelectionScreen({super.key});

  @override
  State<TaskSelectionScreen> createState() => _TaskSelectionScreenState();
}

class _TaskSelectionScreenState extends State<TaskSelectionScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _animations = List.generate(
      3,
      (index) => Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _controller,
          curve: Interval(
            index * 0.2,
            (index + 1) * 0.2,
            curve: Curves.easeOutCubic,
          ),
        ),
      ),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _showAppInfo() {
    showDialog(
      context: context,
      builder: (context) => Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Transform.scale(
              scale: Tween<double>(begin: 0.8, end: 1.0)
                  .animate(
                    CurvedAnimation(
                      parent: _controller,
                      curve: Curves.easeOutBack,
                    ),
                  )
                  .value,
              child: FadeTransition(
                opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
                  CurvedAnimation(parent: _controller, curve: Curves.easeIn),
                ),
                child: child,
              ),
            );
          },
          child: Container(
            width: MediaQuery.of(context).size.width * 0.8,
            constraints: BoxConstraints(
              minHeight: 200,
              maxHeight: MediaQuery.of(context).size.height * 0.5,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.teal.shade600, Colors.teal.shade400],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'نشان پیشرو',
                      style: TextStyle(
                        fontFamily: 'Vazir',
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'نسخه: 1.0',
                      style: TextStyle(
                        fontFamily: 'Vazir',
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                        color: Colors.white70,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    AnimatedScaleButton(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.teal.shade700,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 40,
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 6,
                          shadowColor: Colors.teal.withOpacity(0.4),
                        ),
                        child: const Text(
                          'بستن',
                          style: TextStyle(
                            fontFamily: 'Vazir',
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    _controller.forward();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('انتخاب تسک'),
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: _showAppInfo,
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.teal.shade50, Colors.grey.shade100],
          ),
        ),
        child: SingleChildScrollView(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
                FadeTransition(
                  opacity: _animations[0],
                  child: _buildAnimatedButton(
                    context,
                    'تسک ۱: نمایش آدرس',
                    () => Navigator.push(
                      context,
                      PageRouteBuilder(
                        pageBuilder: (context, animation, secondaryAnimation) =>
                            const Task1Screen(),
                        transitionsBuilder:
                            (context, animation, secondaryAnimation, child) {
                              return FadeTransition(
                                opacity: animation,
                                child: child,
                              );
                            },
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                FadeTransition(
                  opacity: _animations[1],
                  child: _buildAnimatedButton(
                    context,
                    'تسک ۲: اعلان نزدیکی',
                    () => Navigator.push(
                      context,
                      PageRouteBuilder(
                        pageBuilder: (context, animation, secondaryAnimation) =>
                            const Task2Screen(),
                        transitionsBuilder:
                            (context, animation, secondaryAnimation, child) {
                              return FadeTransition(
                                opacity: animation,
                                child: child,
                              );
                            },
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                FadeTransition(
                  opacity: _animations[2],
                  child: _buildAnimatedButton(
                    context,
                    'تسک ۳: مسیر یابی',
                    () => Navigator.push(
                      context,
                      PageRouteBuilder(
                        pageBuilder: (context, animation, secondaryAnimation) =>
                            const Task3Screen(),
                        transitionsBuilder:
                            (context, animation, secondaryAnimation, child) {
                              return FadeTransition(
                                opacity: animation,
                                child: child,
                              );
                            },
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
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
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        child: Card(
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.teal.shade200, width: 1),
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                colors: [Colors.teal.shade600, Colors.teal.shade400],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: ElevatedButton(
                onPressed: onPressed,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 70),
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  text,
                  style: const TextStyle(
                    fontFamily: 'Vazir',
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
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
      end: 1.05,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => _controller.forward(),
      onExit: (_) => _controller.reverse(),
      child: GestureDetector(
        onTapDown: (_) => _controller.forward(),
        onTapUp: (_) => _controller.reverse(),
        onTapCancel: () => _controller.reverse(),
        child: ScaleTransition(scale: _scaleAnimation, child: widget.child),
      ),
    );
  }
}

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
  Stream<Position>? _positionStream;
  final latlng.LatLng _fallbackPosition = const latlng.LatLng(36.2970, 59.6062);
  DateTime? _lastErrorTime;

  @override
  void initState() {
    super.initState();
    Future.microtask(_checkPermissionsAndGetLocation);
  }

  @override
  void dispose() {
    _positionStream?.listen((_) {}).cancel();
    _positionStream = null;
    super.dispose();
  }

  Future<void> _checkPermissionsAndGetLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        await _showEnableGpsDialog();
      }
      setState(() {
        _isLoading = false;
      });
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (context) => const PermissionRequestScreen(),
            ),
            (route) => false,
          );
        }
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => const PermissionRequestScreen(),
          ),
          (route) => false,
        );
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

            _positionStream = Geolocator.getPositionStream(
              locationSettings: const LocationSettings(
                accuracy: LocationAccuracy.high,
                distanceFilter: 5,
              ),
            );
            _positionStream!.listen((Position position) {
              if (mounted) {
                final newPosition = latlng.LatLng(
                  position.latitude,
                  position.longitude,
                );
                if (_currentPosition == null ||
                    Geolocator.distanceBetween(
                          _currentPosition!.latitude,
                          _currentPosition!.longitude,
                          newPosition.latitude,
                          newPosition.longitude,
                        ) >
                        5) {
                  setState(() {
                    _currentPosition = newPosition;
                  });
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      _mapController.move(_currentPosition!, 15.0);
                    }
                  });
                }
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

  Future<void> _showEnableGpsDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'فعال‌سازی GPS',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        content: const Text(
          'لطفاً GPS را فعال کنید تا از این قابلیت استفاده کنید.',
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await Geolocator.openLocationSettings();
              if (mounted) {
                await _checkPermissionsAndGetLocation();
              }
            },
            child: const Text(
              'فعال کردن',
              style: TextStyle(color: Colors.teal, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _centerOnCurrentLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      if (mounted) {
        final now = DateTime.now();
        if (_lastErrorTime == null ||
            now.difference(_lastErrorTime!).inSeconds >= 5) {
          _lastErrorTime = now;
          await _showEnableGpsDialog();
        }
      }
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(const Duration(seconds: 5));
      if (mounted) {
        final newPosition = latlng.LatLng(
          position.latitude,
          position.longitude,
        );
        if (_currentPosition == null ||
            Geolocator.distanceBetween(
                  _currentPosition!.latitude,
                  _currentPosition!.longitude,
                  newPosition.latitude,
                  newPosition.longitude,
                ) >
                5) {
          setState(() {
            _currentPosition = newPosition;
          });
          _mapController.move(_currentPosition!, 15.0);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('موقعیت کنونی به‌روزرسانی شد')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        final now = DateTime.now();
        if (_lastErrorTime == null ||
            now.difference(_lastErrorTime!).inSeconds >= 5) {
          _lastErrorTime = now;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('خطا در دریافت موقعیت کنونی: $e')),
          );
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
        headers: {'User-Agent': 'com.example.neshanpishro/1.0'},
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
            title: const Text(
              'آدرس نقطه انتخاب شده',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            content: Text(
              detailedAddress.isEmpty ? 'آدرس یافت نشد' : detailedAddress,
              style: const TextStyle(fontSize: 16),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'بستن',
                  style: TextStyle(
                    color: Colors.teal,
                    fontWeight: FontWeight.w600,
                  ),
                ),
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator.adaptive())
          : _currentPosition == null
          ? const Center(
              child: Text(
                'در انتظار فعال‌سازی GPS...',
                style: TextStyle(
                  fontFamily: 'Vazir',
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
            )
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
                  userAgentPackageName: 'com.example.neshanpishro',
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
                        color: Colors.redAccent,
                        size: 40,
                        shadows: [
                          Shadow(
                            blurRadius: 4,
                            color: Colors.black26,
                            offset: Offset(2, 2),
                          ),
                        ],
                      ),
                    ),
                    if (_selectedPoint != null)
                      Marker(
                        point: _selectedPoint!,
                        width: 40,
                        height: 40,
                        child: const Icon(
                          Icons.location_on,
                          color: Colors.blueAccent,
                          size: 40,
                          shadows: [
                            Shadow(
                              blurRadius: 4,
                              color: Colors.black26,
                              offset: Offset(2, 2),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _centerOnCurrentLocation,
        child: const Icon(Icons.my_location, size: 28),
        tooltip: 'موقعیت کنونی',
      ),
    );
  }
}

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
  Stream<Position>? _positionStream;
  final latlng.LatLng _fallbackPosition = const latlng.LatLng(36.2970, 59.6062);
  DateTime? _lastErrorTime;

  @override
  void initState() {
    super.initState();
    Future.microtask(_checkPermissionsAndStartTracking);
  }

  @override
  void dispose() {
    _positionStream?.listen((_) {}).cancel();
    _positionStream = null;
    super.dispose();
  }

  Future<void> _checkPermissionsAndStartTracking() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        await _showEnableGpsDialog();
      }
      setState(() {
        _isLoading = false;
      });
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (context) => const PermissionRequestScreen(),
            ),
            (route) => false,
          );
        }
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => const PermissionRequestScreen(),
          ),
          (route) => false,
        );
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

            _positionStream = Geolocator.getPositionStream(
              locationSettings: const LocationSettings(
                accuracy: LocationAccuracy.high,
                distanceFilter: 5,
              ),
            );
            _positionStream!.listen((Position position) {
              if (mounted) {
                final newPosition = latlng.LatLng(
                  position.latitude,
                  position.longitude,
                );
                if (_currentPosition == null ||
                    Geolocator.distanceBetween(
                          _currentPosition!.latitude,
                          _currentPosition!.longitude,
                          newPosition.latitude,
                          newPosition.longitude,
                        ) >
                        5) {
                  setState(() {
                    _currentPosition = newPosition;
                  });
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      _mapController.move(_currentPosition!, 15.0);
                    }
                  });
                  _checkProximityToMarkers();
                }
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

  Future<void> _showEnableGpsDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'فعال‌سازی GPS',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        content: const Text(
          'لطفاً GPS را فعال کنید تا از این قابلیت استفاده کنید.',
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await Geolocator.openLocationSettings();
              if (mounted) {
                await _checkPermissionsAndStartTracking();
              }
            },
            child: const Text(
              'فعال کردن',
              style: TextStyle(color: Colors.teal, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _centerOnCurrentLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      if (mounted) {
        final now = DateTime.now();
        if (_lastErrorTime == null ||
            now.difference(_lastErrorTime!).inSeconds >= 5) {
          _lastErrorTime = now;
          await _showEnableGpsDialog();
        }
      }
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(const Duration(seconds: 5));
      if (mounted) {
        final newPosition = latlng.LatLng(
          position.latitude,
          position.longitude,
        );
        if (_currentPosition == null ||
            Geolocator.distanceBetween(
                  _currentPosition!.latitude,
                  _currentPosition!.longitude,
                  newPosition.latitude,
                  newPosition.longitude,
                ) >
                5) {
          setState(() {
            _currentPosition = newPosition;
          });
          _mapController.move(_currentPosition!, 15.0);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('موقعیت کنونی به‌روزرسانی شد')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        final now = DateTime.now();
        if (_lastErrorTime == null ||
            now.difference(_lastErrorTime!).inSeconds >= 5) {
          _lastErrorTime = now;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('خطا در دریافت موقعیت کنونی: $e')),
          );
        }
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
        'به منطقه ۳۰۰ متری نقطه ${marker.latitude}, ${marker.longitude} رسیدید',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'proximity_channel',
            'Proximity Alerts',
            importance: Importance.high,
            priority: Priority.high,
            showWhen: true,
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
          'به منطقه ۳۰۰ متری نقطه ${marker.latitude}, ${marker.longitude} رسیدید',
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'proximity_channel',
              'Proximity Alerts',
              importance: Importance.high,
              priority: Priority.high,
              showWhen: true,
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator.adaptive())
          : _currentPosition == null
          ? const Center(
              child: Text(
                'در انتظار فعال‌سازی GPS...',
                style: TextStyle(
                  fontFamily: 'Vazir',
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
            )
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
                  userAgentPackageName: 'com.example.neshanpishro',
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
                        color: Colors.redAccent,
                        size: 40,
                        shadows: [
                          Shadow(
                            blurRadius: 4,
                            color: Colors.black26,
                            offset: Offset(2, 2),
                          ),
                        ],
                      ),
                    ),
                    ..._markers.map(
                      (marker) => Marker(
                        point: marker,
                        width: 30,
                        height: 30,
                        child: const Icon(
                          Icons.location_on,
                          color: Colors.blueAccent,
                          size: 30,
                          shadows: [
                            Shadow(
                              blurRadius: 4,
                              color: Colors.black26,
                              offset: Offset(2, 2),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _centerOnCurrentLocation,
        child: const Icon(Icons.my_location, size: 28),
        tooltip: 'موقعیت کنونی',
      ),
    );
  }
}

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
  Stream<Position>? _positionStream;
  String _selectedMode = 'car';
  final latlng.LatLng _fallbackPosition = const latlng.LatLng(36.2970, 59.6062);
  final String _apiKey =
      'eyJvcmciOiI1YjNjZTM1OTc4NTExMTAwMDFjZjYyNDgiLCJpZCI6ImRkNzBlMjg5ZDEyZTQ5MDQ5ZjZjN2ZiNTE1ZGEyZWMyIiwiaCI6Im11cm11cjY0In0=';
  DateTime? _lastErrorTime;

  @override
  void initState() {
    super.initState();
    Future.microtask(_checkPermissionsAndGetLocation);
  }

  @override
  void dispose() {
    _positionStream?.listen((_) {}).cancel();
    _positionStream = null;
    super.dispose();
  }

  Future<void> _checkPermissionsAndGetLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        await _showEnableGpsDialog();
      }
      setState(() {
        _isLoading = false;
      });
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (context) => const PermissionRequestScreen(),
            ),
            (route) => false,
          );
        }
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => const PermissionRequestScreen(),
          ),
          (route) => false,
        );
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

            _positionStream = Geolocator.getPositionStream(
              locationSettings: const LocationSettings(
                accuracy: LocationAccuracy.high,
                distanceFilter: 5,
              ),
            );
            _positionStream!.listen((Position position) {
              if (mounted) {
                final newPosition = latlng.LatLng(
                  position.latitude,
                  position.longitude,
                );
                if (_currentPosition == null ||
                    Geolocator.distanceBetween(
                          _currentPosition!.latitude,
                          _currentPosition!.longitude,
                          newPosition.latitude,
                          newPosition.longitude,
                        ) >
                        5) {
                  setState(() {
                    _currentPosition = newPosition;
                  });
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      _mapController.move(_currentPosition!, 15.0);
                    }
                  });
                }
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

  Future<void> _showEnableGpsDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'فعال‌سازی GPS',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        content: const Text(
          'لطفاً GPS را فعال کنید تا از این قابلیت استفاده کنید.',
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await Geolocator.openLocationSettings();
              if (mounted) {
                await _checkPermissionsAndGetLocation();
              }
            },
            child: const Text(
              'فعال کردن',
              style: TextStyle(color: Colors.teal, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _centerOnCurrentLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      if (mounted) {
        final now = DateTime.now();
        if (_lastErrorTime == null ||
            now.difference(_lastErrorTime!).inSeconds >= 5) {
          _lastErrorTime = now;
          await _showEnableGpsDialog();
        }
      }
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(const Duration(seconds: 5));
      if (mounted) {
        final newPosition = latlng.LatLng(
          position.latitude,
          position.longitude,
        );
        if (_currentPosition == null ||
            Geolocator.distanceBetween(
                  _currentPosition!.latitude,
                  _currentPosition!.longitude,
                  newPosition.latitude,
                  newPosition.longitude,
                ) >
                5) {
          setState(() {
            _currentPosition = newPosition;
          });
          _mapController.move(_currentPosition!, 15.0);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('موقعیت کنونی به‌روزرسانی شد')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        final now = DateTime.now();
        if (_lastErrorTime == null ||
            now.difference(_lastErrorTime!).inSeconds >= 5) {
          _lastErrorTime = now;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('خطا در دریافت موقعیت کنونی: $e')),
          );
        }
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
              'User-Agent': 'com.example.neshanpishro/1.0',
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator.adaptive())
          : _currentPosition == null
          ? const Center(
              child: Text(
                'در انتظار فعال‌سازی GPS...',
                style: TextStyle(
                  fontFamily: 'Vazir',
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
            )
          : Column(
              children: [
                Container(
                  margin: const EdgeInsets.all(12),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.teal.withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
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
                            child: Text(
                              value == 'car' ? 'ماشین' : 'پیاده',
                              style: const TextStyle(
                                fontFamily: 'Vazir',
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          );
                        })
                        .toList(),
                    style: const TextStyle(
                      fontFamily: 'Vazir',
                      fontSize: 16,
                      color: Colors.black87,
                    ),
                    isExpanded: true,
                    underline: const SizedBox(),
                    icon: const Icon(Icons.arrow_drop_down, color: Colors.teal),
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
                        userAgentPackageName: 'com.example.neshanpishro',
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
                              color: Colors.redAccent,
                              size: 40,
                              shadows: [
                                Shadow(
                                  blurRadius: 4,
                                  color: Colors.black26,
                                  offset: Offset(2, 2),
                                ),
                              ],
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
                                shadows: [
                                  Shadow(
                                    blurRadius: 4,
                                    color: Colors.black26,
                                    offset: Offset(2, 2),
                                  ),
                                ],
                              ),
                            ),
                          if (_destination != null)
                            Marker(
                              point: _destination!,
                              width: 40,
                              height: 40,
                              child: const Icon(
                                Icons.location_pin,
                                color: Colors.blueAccent,
                                size: 40,
                                shadows: [
                                  Shadow(
                                    blurRadius: 4,
                                    color: Colors.black26,
                                    offset: Offset(2, 2),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      PolylineLayer(
                        polylines: [
                          if (_polylinePoints.isNotEmpty)
                            Polyline(
                              points: _polylinePoints,
                              strokeWidth: 6.0,
                              color: _selectedMode == 'foot'
                                  ? Colors.redAccent
                                  : Colors.blueAccent,
                              borderStrokeWidth: 1.0,
                              borderColor: Colors.white,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _centerOnCurrentLocation,
        child: const Icon(Icons.my_location, size: 28),
        tooltip: 'موقعیت کنونی',
      ),
    );
  }
}
