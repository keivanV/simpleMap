import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlng;
import 'package:geolocator/geolocator.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator_android/geolocator_android.dart';

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
  bool _isPermanentlyDenied = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(_checkPermissions);
  }

  Future<void> _checkPermissions() async {
    LocationPermission permission = await Geolocator.checkPermission();
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
        _isPermanentlyDenied = permission == LocationPermission.deniedForever;
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
        _isPermanentlyDenied = permission == LocationPermission.deniedForever;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isPermanentlyDenied
                  ? 'دسترسی به مکان به‌طور دائم رد شده است. لطفاً از تنظیمات اپلیکیشن دسترسی را فعال کنید.'
                  : 'لطفاً دسترسی به مکان را فعال کنید تا ادامه دهید.',
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }
      if (_isPermanentlyDenied && mounted) {
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          await Geolocator.openAppSettings();
        }
      }
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
                  Text(
                    _isPermanentlyDenied
                        ? 'دسترسی به مکان به‌طور دائم رد شده است. لطفاً از تنظیمات اپلیکیشن دسترسی را فعال کنید.'
                        : 'برای استفاده از اپلیکیشن، لطفاً دسترسی به مکان را فعال کنید.',
                    style: const TextStyle(
                      fontFamily: 'Vazir',
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  AnimatedScaleButton(
                    child: ElevatedButton(
                      onPressed: _requestPermission,
                      child: Text(
                        _isPermanentlyDenied
                            ? 'باز کردن تنظیمات'
                            : 'درخواست دسترسی',
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class AppInfoDialog extends StatefulWidget {
  const AppInfoDialog({super.key});

  @override
  State<AppInfoDialog> createState() => _AppInfoDialogState();
}

class _AppInfoDialogState extends State<AppInfoDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: FadeTransition(opacity: _fadeAnimation, child: child),
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
    );
  }
}

class TaskHelpDialog extends StatefulWidget {
  final String helpText;

  const TaskHelpDialog({super.key, required this.helpText});

  @override
  State<TaskHelpDialog> createState() => _TaskHelpDialogState();
}

class _TaskHelpDialogState extends State<TaskHelpDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: FadeTransition(opacity: _fadeAnimation, child: child),
        );
      },
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8,
        constraints: BoxConstraints(
          minHeight: 150,
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
                  'راهنمای تسک',
                  style: TextStyle(
                    fontFamily: 'Vazir',
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  widget.helpText,
                  style: const TextStyle(
                    fontFamily: 'Vazir',
                    fontSize: 16,
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
      barrierDismissible: true,
      builder: (context) => const Center(child: AppInfoDialog()),
    );
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
  bool _isCentering = false;
  bool _isGpsDialogOpen = false;
  Stream<Position>? _positionStream;
  final latlng.LatLng _fallbackPosition = const latlng.LatLng(36.2970, 59.6062);
  DateTime? _lastErrorTime;
  DateTime? _lastLocationFetchTime; // زمان آخرین دریافت موقعیت
  latlng.LatLng? _lastValidPosition; // آخرین موقعیت معتبر
  bool _isFetchingLocation = false; // قفل برای جلوگیری از درخواست‌های موازی
  static const int _maxAttempts = 7; // تعداد تلاش‌های بیشتر
  static const Duration _retryDelay = Duration(
    milliseconds: 300,
  ); // تاخیر کمتر بین تلاش‌ها
  static const Duration _cacheValidity = Duration(seconds: 10); // مدت اعتبار کش

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await _checkInternetOnEntry();
      await _checkPermissionsAndGetLocation();
    });
  }

  @override
  void dispose() {
    _positionStream?.listen((_) {}, onError: (_) {}).cancel();
    _positionStream = null;
    super.dispose();
  }

  Future<void> _checkInternetOnEntry() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'اتصال اینترنت برقرار نیست. لطفاً اینترنت را وصل کنید.',
          ),
          duration: Duration(seconds: 5),
        ),
      );
    }
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

    for (int attempt = 1; attempt <= _maxAttempts; attempt++) {
      try {
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.bestForNavigation,
          timeLimit: const Duration(seconds: 8),
        );
        if (mounted) {
          final newPosition = latlng.LatLng(
            position.latitude,
            position.longitude,
          );
          setState(() {
            _currentPosition = newPosition;
            _lastValidPosition = newPosition; // ذخیره در کش
            _lastLocationFetchTime = DateTime.now(); // به‌روزرسانی زمان
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
          _positionStream!.listen(
            (Position position) {
              if (mounted) {
                final newPosition = latlng.LatLng(
                  position.latitude,
                  position.longitude,
                );
                setState(() {
                  _currentPosition = newPosition;
                  _lastValidPosition = newPosition; // به‌روزرسانی کش
                  _lastLocationFetchTime = DateTime.now();
                });
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    _mapController.move(_currentPosition!, 15.0);
                  }
                });
              }
            },
            onError: (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('خطا در جریان موقعیت: $e')),
                );
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PermissionRequestScreen(),
                  ),
                  (route) => false,
                );
              }
            },
          );
          return;
        }
      } catch (e) {
        if (attempt == _maxAttempts && mounted) {
          if (_lastValidPosition != null) {
            setState(() {
              _currentPosition = _lastValidPosition;
              _isLoading = false;
            });
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _mapController.move(_currentPosition!, 15.0);
              }
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'دریافت موقعیت جدید ناموفق بود. استفاده از آخرین موقعیت معتبر.',
                ),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'دریافت موقعیت با شکست مواجه شد. استفاده از موقعیت پیش‌فرض (مشهد).',
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
        await Future.delayed(_retryDelay);
      }
    }
  }

  Future<void> _showEnableGpsDialog() async {
    if (_isGpsDialogOpen) return;
    setState(() {
      _isGpsDialogOpen = true;
    });

    bool serviceEnabled = false;
    StreamSubscription<ServiceStatus>? serviceStatusSubscription;

    serviceStatusSubscription = Geolocator.getServiceStatusStream().listen((
      status,
    ) async {
      if (status == ServiceStatus.enabled && mounted) {
        serviceEnabled = true;
        serviceStatusSubscription?.cancel();
        Navigator.pop(context);
        await _checkPermissionsAndGetLocation();
      }
    });

    Future.delayed(const Duration(seconds: 30), () {
      if (mounted && !serviceEnabled) {
        serviceStatusSubscription?.cancel();
        Navigator.pop(context);
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => const PermissionRequestScreen(),
          ),
          (route) => false,
        );
      }
    });

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
              serviceStatusSubscription?.cancel();
              Navigator.pop(context);
              await Geolocator.openLocationSettings();
              if (mounted && !serviceEnabled) {
                await _checkPermissionsAndGetLocation();
              }
            },
            child: const Text(
              'فعال کردن',
              style: TextStyle(color: Colors.teal, fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(
            onPressed: () {
              serviceStatusSubscription?.cancel();
              Navigator.pop(context);
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (context) => const PermissionRequestScreen(),
                ),
                (route) => false,
              );
            },
            child: const Text(
              'بازگشت',
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _checkPermissionsAndGetLocation();
            },
            child: const Text(
              'تلاش مجدد',
              style: TextStyle(color: Colors.teal, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    serviceStatusSubscription?.cancel();
    setState(() {
      _isGpsDialogOpen = false;
    });
  }

  Future<bool> _checkInternetConnectivity() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'برای دریافت این سرویس اتصال شبکه اینترنت را متصل کنید',
          ),
        ),
      );
      return false;
    }
    return true;
  }

  Future<void> _centerOnCurrentLocation() async {
    // جلوگیری از درخواست‌های موازی
    if (_isGpsDialogOpen || _isFetchingLocation) return;

    setState(() {
      _isFetchingLocation = true;
    });

    // بررسی سرویس GPS
    if (!await Geolocator.isLocationServiceEnabled()) {
      if (mounted) {
        final now = DateTime.now();
        if (_lastErrorTime == null ||
            now.difference(_lastErrorTime!).inSeconds >= 5) {
          _lastErrorTime = now;
          await _showEnableGpsDialog();
        }
      }
      setState(() {
        _isFetchingLocation = false;
      });
      return;
    }

    // بررسی کش موقعیت
    if (_lastValidPosition != null &&
        _lastLocationFetchTime != null &&
        DateTime.now().difference(_lastLocationFetchTime!) < _cacheValidity) {
      if (mounted) {
        setState(() {
          _currentPosition = _lastValidPosition;
          _isFetchingLocation = false;
        });
        _mapController.move(_currentPosition!, 15.0);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('موقعیت کنونی از حافظه نمایش داده شد')),
        );
      }
      return;
    }

    // تلاش برای دریافت موقعیت جدید
    for (int attempt = 1; attempt <= _maxAttempts; attempt++) {
      try {
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.bestForNavigation, // دقت بالاتر
          timeLimit: const Duration(seconds: 8), // زمان انتظار کمتر
        );
        if (mounted) {
          final newPosition = latlng.LatLng(
            position.latitude,
            position.longitude,
          );
          setState(() {
            _currentPosition = newPosition;
            _lastValidPosition = newPosition; // ذخیره در کش
            _lastLocationFetchTime = DateTime.now(); // به‌روزرسانی زمان
            _isFetchingLocation = false;
          });
          _mapController.move(_currentPosition!, 15.0);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('موقعیت کنونی با موفقیت به‌روزرسانی شد'),
            ),
          );
          return;
        }
      } catch (e) {
        if (mounted) {
          developer.log('Attempt $attempt failed: $e');
        }
        if (attempt == _maxAttempts) {
          // در صورت شکست تمام تلاش‌ها
          if (_lastValidPosition != null && mounted) {
            // استفاده از آخرین موقعیت معتبر
            setState(() {
              _currentPosition = _lastValidPosition;
              _isFetchingLocation = false;
            });
            _mapController.move(_currentPosition!, 15.0);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'دریافت موقعیت جدید ناموفق بود. استفاده از آخرین موقعیت معتبر.',
                ),
              ),
            );
          } else {
            // استفاده از موقعیت پیش‌فرض
            if (mounted) {
              setState(() {
                _currentPosition = _fallbackPosition;
                _isFetchingLocation = false;
              });
              _mapController.move(_currentPosition!, 15.0);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'دریافت موقعیت با شکست مواجه شد. استفاده از موقعیت پیش‌فرض (مشهد).',
                  ),
                ),
              );
            }
          }
          return;
        }
        await Future.delayed(_retryDelay); // تاخیر کوتاه‌تر بین تلاش‌ها
      }
    }
  }

  Future<void> _showAddressPopup(latlng.LatLng point) async {
    if (!await _checkInternetConnectivity()) {
      return;
    }

    setState(() {
      _selectedPoint = point;
    });

    try {
      final response = await http
          .get(
            Uri.parse(
              'https://nominatim.openstreetmap.org/reverse?format=json&lat=${point.latitude}&lon=${point.longitude}&zoom=18&addressdetails=1',
            ),
            headers: {'User-Agent': 'com.example.neshanpishro/1.0'},
          )
          .timeout(const Duration(seconds: 10));
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'برای دریافت این سرویس اتصال شبکه اینترنت را متصل کنید',
            ),
          ),
        );
      }
    }
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Center(
        child: TaskHelpDialog(
          helpText:
              'با انتخاب هر نقطه روی نقشه می‌توانید از موقعیت آن منطقه با خبر بشید',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('نمایش آدرس'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: 'راهنما',
            onPressed: _showHelpDialog,
          ),
        ],
      ),
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
        onPressed: (_isGpsDialogOpen || _isCentering)
            ? null
            : _centerOnCurrentLocation,
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
  List<bool> _activeMarkers = [];
  Set<int> _notifiedMarkers = {};
  bool _isLoading = true;
  bool _isGpsDialogOpen = false;
  bool _isFetchingLocation = false;
  StreamSubscription<Position>? _positionSubscription;
  final latlng.LatLng _fallbackPosition = const latlng.LatLng(36.2970, 59.6062);
  DateTime? _lastErrorTime;
  DateTime? _lastLocationFetchTime;
  latlng.LatLng? _lastValidPosition;
  static const int _maxAttempts = 7;
  static const Duration _retryDelay = Duration(milliseconds: 300);
  static const Duration _cacheValidity = Duration(seconds: 10);
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await _checkInternetOnEntry();
      await _loadMarkers();
      await _checkPermissionsAndStartTracking();
    });
  }

  Future<void> _initializeNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);
    await _flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  Future<void> _loadMarkers() async {
    final prefs = await SharedPreferences.getInstance();
    final String? markersJson = prefs.getString('markers');
    final String? activeMarkersJson = prefs.getString('activeMarkers');
    if (markersJson != null) {
      final List<dynamic> markersList = jsonDecode(markersJson);
      final List<dynamic> activeMarkersList = activeMarkersJson != null
          ? jsonDecode(activeMarkersJson)
          : [];
      setState(() {
        _markers = markersList
            .map(
              (marker) =>
                  latlng.LatLng(marker['latitude'], marker['longitude']),
            )
            .toList();
        _activeMarkers = activeMarkersList.length == _markers.length
            ? List<bool>.from(activeMarkersList)
            : List.filled(_markers.length, false);
      });
    }
  }

  Future<void> _saveMarkers() async {
    final prefs = await SharedPreferences.getInstance();
    final markersJson = jsonEncode(
      _markers
          .map(
            (marker) => {
              'latitude': marker.latitude,
              'longitude': marker.longitude,
            },
          )
          .toList(),
    );
    final activeMarkersJson = jsonEncode(_activeMarkers);
    await prefs.setString('markers', markersJson);
    await prefs.setString('activeMarkers', activeMarkersJson);
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
    super.dispose();
  }

  Future<void> _checkInternetOnEntry() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'اتصال اینترنت برقرار نیست. لطفاً اینترنت را وصل کنید.',
          ),
          duration: Duration(seconds: 5),
        ),
      );
    }
  }

  Future<void> _checkPermissionsAndStartTracking() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) await _showEnableGpsDialog();
      setState(() => _isLoading = false);
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission != LocationPermission.always) {
      permission = await Geolocator.requestPermission();
      if (permission != LocationPermission.always) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'برای کار در پس‌زمینه، دسترسی همیشه به مکان لازم است.',
              ),
            ),
          );
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

    for (int attempt = 1; attempt <= _maxAttempts; attempt++) {
      try {
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.bestForNavigation,
          timeLimit: const Duration(seconds: 8),
        );
        if (mounted) {
          final newPosition = latlng.LatLng(
            position.latitude,
            position.longitude,
          );
          setState(() {
            _currentPosition = newPosition;
            _lastValidPosition = newPosition;
            _lastLocationFetchTime = DateTime.now();
            _isLoading = false;
          });
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _mapController.move(_currentPosition!, 15.0);
          });
          await _checkProximityToMarkers();

          // Configure location stream without androidSettings
          _positionSubscription =
              Geolocator.getPositionStream(
                locationSettings: const LocationSettings(
                  accuracy: LocationAccuracy.high,
                  distanceFilter: 5,
                  timeLimit: Duration(seconds: 8),
                ),
              ).listen(
                (Position position) {
                  final newPosition = latlng.LatLng(
                    position.latitude,
                    position.longitude,
                  );
                  setState(() {
                    _currentPosition = newPosition;
                    _lastValidPosition = newPosition;
                    _lastLocationFetchTime = DateTime.now();
                  });
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) _mapController.move(_currentPosition!, 15.0);
                  });
                  _checkProximityToMarkers();
                },
                onError: (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('خطا در جریان موقعیت: $e')),
                    );
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const PermissionRequestScreen(),
                      ),
                      (route) => false,
                    );
                  }
                },
              );
          return;
        }
      } catch (e) {
        if (attempt == _maxAttempts && mounted) {
          if (_lastValidPosition != null) {
            setState(() {
              _currentPosition = _lastValidPosition;
              _isLoading = false;
            });
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _mapController.move(_currentPosition!, 15.0);
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'دریافت موقعیت جدید ناموفق بود. استفاده از آخرین موقعیت معتبر.',
                ),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'دریافت موقعیت با شکست مواجه شد. استفاده از موقعیت پیش‌فرض (مشهد).',
                ),
              ),
            );
            setState(() {
              _currentPosition = _fallbackPosition;
              _isLoading = false;
            });
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _mapController.move(_currentPosition!, 15.0);
            });
          }
          await _checkProximityToMarkers();
          return;
        }
        await Future.delayed(_retryDelay);
      }
    }
  }

  Future<void> _showEnableGpsDialog() async {
    if (_isGpsDialogOpen) return;
    setState(() => _isGpsDialogOpen = true);

    bool serviceEnabled = false;
    StreamSubscription<ServiceStatus>? serviceStatusSubscription;

    serviceStatusSubscription = Geolocator.getServiceStatusStream().listen((
      status,
    ) async {
      if (status == ServiceStatus.enabled && mounted) {
        serviceEnabled = true;
        serviceStatusSubscription?.cancel();
        Navigator.pop(context);
        await _checkPermissionsAndStartTracking();
      }
    });

    Future.delayed(const Duration(seconds: 30), () {
      if (mounted && !serviceEnabled) {
        serviceStatusSubscription?.cancel();
        Navigator.pop(context);
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => const PermissionRequestScreen(),
          ),
          (route) => false,
        );
      }
    });

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
              serviceStatusSubscription?.cancel();
              Navigator.pop(context);
              await Geolocator.openLocationSettings();
              if (mounted && !serviceEnabled)
                await _checkPermissionsAndStartTracking();
            },
            child: const Text(
              'فعال کردن',
              style: TextStyle(color: Colors.teal, fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(
            onPressed: () {
              serviceStatusSubscription?.cancel();
              Navigator.pop(context);
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (context) => const PermissionRequestScreen(),
                ),
                (route) => false,
              );
            },
            child: const Text(
              'بازگشت',
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _checkPermissionsAndStartTracking();
            },
            child: const Text(
              'تلاش مجدد',
              style: TextStyle(color: Colors.teal, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    serviceStatusSubscription?.cancel();
    setState(() => _isGpsDialogOpen = false);
  }

  Future<void> _centerOnCurrentLocation() async {
    if (_isGpsDialogOpen || _isFetchingLocation) return;
    setState(() => _isFetchingLocation = true);

    if (!await Geolocator.isLocationServiceEnabled()) {
      if (mounted) {
        final now = DateTime.now();
        if (_lastErrorTime == null ||
            now.difference(_lastErrorTime!).inSeconds >= 5) {
          _lastErrorTime = now;
          await _showEnableGpsDialog();
        }
      }
      setState(() => _isFetchingLocation = false);
      return;
    }

    if (_lastValidPosition != null &&
        _lastLocationFetchTime != null &&
        DateTime.now().difference(_lastLocationFetchTime!) < _cacheValidity) {
      if (mounted) {
        setState(() {
          _currentPosition = _lastValidPosition;
          _isFetchingLocation = false;
        });
        _mapController.move(_currentPosition!, 15.0);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('موقعیت کنونی از حافظه نمایش داده شد')),
        );
        await _checkProximityToMarkers();
      }
      return;
    }

    for (int attempt = 1; attempt <= _maxAttempts; attempt++) {
      try {
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.bestForNavigation,
          timeLimit: const Duration(seconds: 8),
        );
        if (mounted) {
          final newPosition = latlng.LatLng(
            position.latitude,
            position.longitude,
          );
          setState(() {
            _currentPosition = newPosition;
            _lastValidPosition = newPosition;
            _lastLocationFetchTime = DateTime.now();
            _isFetchingLocation = false;
          });
          _mapController.move(_currentPosition!, 15.0);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('موقعیت کنونی با موفقیت به‌روزرسانی شد'),
            ),
          );
          await _checkProximityToMarkers();
          return;
        }
      } catch (e) {
        if (mounted) developer.log('Attempt $attempt failed: $e');
        if (attempt == _maxAttempts) {
          if (_lastValidPosition != null && mounted) {
            setState(() {
              _currentPosition = _lastValidPosition;
              _isFetchingLocation = false;
            });
            _mapController.move(_currentPosition!, 15.0);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'دریافت موقعیت جدید ناموفق بود. استفاده از آخرین موقعیت معتبر.',
                ),
              ),
            );
            await _checkProximityToMarkers();
          } else {
            if (mounted) {
              setState(() {
                _currentPosition = _fallbackPosition;
                _isFetchingLocation = false;
              });
              _mapController.move(_currentPosition!, 15.0);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'دریافت موقعیت با شکست مواجه شد. استفاده از موقعیت پیش‌فرض (مشهد).',
                  ),
                ),
              );
              await _checkProximityToMarkers();
            }
          }
          return;
        }
        await Future.delayed(_retryDelay);
      }
    }
  }

  void _addMarker(latlng.LatLng position) {
    setState(() {
      _markers.add(position);
      _activeMarkers.add(false);
    });
    _saveMarkers();
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('نقطه جدید اضافه شد')));
      _checkProximityToNewMarker(position);
    }
  }

  void _removeMarker(int index) {
    setState(() {
      _markers.removeAt(index);
      _activeMarkers.removeAt(index);
      _notifiedMarkers.remove(index);
      final updatedNotifiedMarkers = <int>{};
      for (var notifiedIndex in _notifiedMarkers) {
        if (notifiedIndex > index) {
          updatedNotifiedMarkers.add(notifiedIndex - 1);
        } else if (notifiedIndex < index) {
          updatedNotifiedMarkers.add(notifiedIndex);
        }
      }
      _notifiedMarkers = updatedNotifiedMarkers;
    });
    _saveMarkers();
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('نقطه حذف شد')));
    }
  }

  Future<void> _checkProximityToNewMarker(latlng.LatLng marker) async {
    if (_currentPosition == null) return;

    final index = _markers.indexOf(marker);
    double distance = Geolocator.distanceBetween(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      marker.latitude,
      marker.longitude,
    );
    if (distance <= 300 && !_notifiedMarkers.contains(index)) {
      setState(() {
        _activeMarkers[index] = true;
      });
      _saveMarkers();
      _notifiedMarkers.add(index);
      await _flutterLocalNotificationsPlugin.show(
        marker.hashCode,
        'نزدیک شدن به نقطه',
        'به شعاع ۳۰۰ متری نقطه شماره ${index + 1} رسیدید',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'proximity_channel',
            'Proximity Alerts',
            importance: Importance.high,
            priority: Priority.high,
            showWhen: true,
            enableVibration: true,
          ),
        ),
      );
    }
  }

  Future<void> _checkProximityToMarkers() async {
    if (_currentPosition == null) return;

    bool needsSave = false;
    for (int i = 0; i < _markers.length; i++) {
      final marker = _markers[i];
      double distance = Geolocator.distanceBetween(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        marker.latitude,
        marker.longitude,
      );
      if (distance <= 300 && !_notifiedMarkers.contains(i)) {
        setState(() {
          _activeMarkers[i] = true;
        });
        needsSave = true;
        _notifiedMarkers.add(i);
        await _flutterLocalNotificationsPlugin.show(
          marker.hashCode,
          'نزدیک شدن به نقطه',
          'به شعاع ۳۰۰ متری نقطه شماره ${i + 1} رسیدید',
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'proximity_channel',
              'Proximity Alerts',
              importance: Importance.high,
              priority: Priority.high,
              showWhen: true,
              enableVibration: true,
            ),
          ),
        );
      } else if (distance > 300 && _notifiedMarkers.contains(i)) {
        setState(() {
          _activeMarkers[i] = false;
        });
        needsSave = true;
        _notifiedMarkers.remove(i);
      }
    }
    if (needsSave) {
      _saveMarkers();
    }
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Center(
        child: TaskHelpDialog(
          helpText:
              'شما می‌توانید بی‌نهایت نقطه در نقشه انتخاب کنید و هر زمان به شعاع ۳۰۰ متری این نقاط رسیدید، دایره اطراف آن‌ها قرمز شده و اعلان دریافت خواهید کرد، حتی اگر برنامه در پس‌زمینه باشد. نقاط و وضعیت آن‌ها تا زمان حذف دستی ذخیره می‌مانند. می‌توانید نقاط را از لیست حذف کنید. موقعیت مکانی شما در هر ۵ متر به‌روزرسانی خواهد شد.',
        ),
      ),
    );
  }

  void _showMarkersList() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'لیست نقاط انتخاب‌شده',
              style: TextStyle(
                fontFamily: 'Vazir',
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            _markers.isEmpty
                ? const Text(
                    'هیچ نقطه‌ای انتخاب نشده است.',
                    style: TextStyle(
                      fontFamily: 'Vazir',
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  )
                : Expanded(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _markers.length,
                      itemBuilder: (context, index) {
                        final marker = _markers[index];
                        final isActive = index < _activeMarkers.length
                            ? _activeMarkers[index]
                            : false;
                        return Card(
                          margin: const EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 16,
                          ),
                          child: ListTile(
                            title: Text(
                              'نقطه ${index + 1} ${isActive ? '(فعال)' : ''}',
                              style: TextStyle(
                                fontFamily: 'Vazir',
                                fontWeight: FontWeight.w600,
                                color: isActive
                                    ? Colors.redAccent
                                    : Colors.black,
                              ),
                            ),
                            subtitle: Text(
                              'عرض جغرافیایی: ${marker.latitude.toStringAsFixed(4)}\nطول جغرافیایی: ${marker.longitude.toStringAsFixed(4)}',
                              style: const TextStyle(fontFamily: 'Vazir'),
                            ),
                            trailing: IconButton(
                              icon: const Icon(
                                Icons.delete,
                                color: Colors.redAccent,
                              ),
                              onPressed: () {
                                _removeMarker(index);
                                Navigator.pop(context);
                                _showMarkersList();
                              },
                            ),
                          ),
                        );
                      },
                    ),
                  ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'بستن',
                style: TextStyle(fontFamily: 'Vazir', fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('اعلان نزدیکی'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.list),
            tooltip: 'لیست نقاط',
            onPressed: _showMarkersList,
          ),
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: 'راهنما',
            onPressed: _showHelpDialog,
          ),
        ],
      ),
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
                CircleLayer(
                  circles: _markers.asMap().entries.map((entry) {
                    int index = entry.key;
                    latlng.LatLng marker = entry.value;
                    bool isActive = index < _activeMarkers.length
                        ? _activeMarkers[index]
                        : false;
                    return CircleMarker(
                      point: marker,
                      radius: 300,
                      useRadiusInMeter: true,
                      color: isActive
                          ? Colors.redAccent.withOpacity(0.3)
                          : Colors.blueAccent.withOpacity(0.3),
                      borderColor: isActive
                          ? Colors.redAccent
                          : Colors.blueAccent,
                      borderStrokeWidth: 2,
                    );
                  }).toList(),
                ),
                MarkerLayer(
                  markers: [
                    if (_currentPosition != null)
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
                    ..._markers.asMap().entries.map((entry) {
                      int index = entry.key;
                      latlng.LatLng marker = entry.value;
                      return Marker(
                        point: marker,
                        width: 30,
                        height: 30,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Icon(
                              Icons.location_on,
                              color:
                                  index < _activeMarkers.length &&
                                      _activeMarkers[index]
                                  ? Colors.redAccent
                                  : Colors.blueAccent,
                              size: 30,
                              shadows: const [
                                Shadow(
                                  blurRadius: 4,
                                  color: Colors.black26,
                                  offset: Offset(2, 2),
                                ),
                              ],
                            ),
                            Positioned(
                              top: 0,
                              child: Text(
                                '${index + 1}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: (_isGpsDialogOpen || _isFetchingLocation)
            ? null
            : _centerOnCurrentLocation,
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
  bool _isCentering = false;
  bool _isGpsDialogOpen = false;
  Stream<Position>? _positionStream;
  String _selectedMode = 'car';
  String _selectionState = 'origin'; // 'origin', 'destination', 'done'
  final latlng.LatLng _fallbackPosition = const latlng.LatLng(36.2970, 59.6062);
  final String _apiKey =
      'eyJvcmciOiI1YjNjZTM1OTc4NTExMTAwMDFjZjYyNDgiLCJpZCI6ImRkNzBlMjg5ZDEyZTQ5MDQ5ZjZjN2ZiNTE1ZGEyZWMyIiwiaCI6Im11cm11cjY0In0=';
  DateTime? _lastErrorTime;
  DateTime? _lastLocationFetchTime; // زمان آخرین دریافت موقعیت
  latlng.LatLng? _lastValidPosition; // آخرین موقعیت معتبر
  bool _isFetchingLocation = false; // قفل برای جلوگیری از درخواست‌های موازی
  static const int _maxAttempts = 7; // تعداد تلاش‌های بیشتر
  static const Duration _retryDelay = Duration(
    milliseconds: 300,
  ); // تاخیر کمتر بین تلاش‌ها
  static const Duration _cacheValidity = Duration(seconds: 10); // مدت اعتبار کش

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await _checkInternetOnEntry();
      await _checkPermissionsAndGetLocation();
    });
  }

  @override
  void dispose() {
    _positionStream?.listen((_) {}, onError: (_) {}).cancel();
    _positionStream = null;
    super.dispose();
  }

  Future<void> _checkInternetOnEntry() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'اتصال اینترنت برقرار نیست. لطفاً اینترنت را وصل کنید.',
          ),
          duration: Duration(seconds: 5),
        ),
      );
    }
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

    for (int attempt = 1; attempt <= _maxAttempts; attempt++) {
      try {
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.bestForNavigation,
          timeLimit: const Duration(seconds: 8),
        );
        if (mounted) {
          final newPosition = latlng.LatLng(
            position.latitude,
            position.longitude,
          );
          setState(() {
            _currentPosition = newPosition;
            _lastValidPosition = newPosition; // ذخیره در کش
            _lastLocationFetchTime = DateTime.now(); // به‌روزرسانی زمان
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
          _positionStream!.listen(
            (Position position) {
              if (mounted) {
                final newPosition = latlng.LatLng(
                  position.latitude,
                  position.longitude,
                );
                setState(() {
                  _currentPosition = newPosition;
                  _lastValidPosition = newPosition; // به‌روزرسانی کش
                  _lastLocationFetchTime = DateTime.now();
                });
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    _mapController.move(_currentPosition!, 15.0);
                  }
                });
              }
            },
            onError: (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('خطا در جریان موقعیت: $e')),
                );
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PermissionRequestScreen(),
                  ),
                  (route) => false,
                );
              }
            },
          );
          return;
        }
      } catch (e) {
        if (attempt == _maxAttempts && mounted) {
          if (_lastValidPosition != null) {
            setState(() {
              _currentPosition = _lastValidPosition;
              _isLoading = false;
            });
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _mapController.move(_currentPosition!, 15.0);
              }
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'دریافت موقعیت جدید ناموفق بود. استفاده از آخرین موقعیت معتبر.',
                ),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'دریافت موقعیت با شکست مواجه شد. استفاده از موقعیت پیش‌فرض (مشهد).',
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
        await Future.delayed(_retryDelay);
      }
    }
  }

  Future<void> _showEnableGpsDialog() async {
    if (_isGpsDialogOpen) return;
    setState(() {
      _isGpsDialogOpen = true;
    });

    bool serviceEnabled = false;
    StreamSubscription<ServiceStatus>? serviceStatusSubscription;

    serviceStatusSubscription = Geolocator.getServiceStatusStream().listen((
      status,
    ) async {
      if (status == ServiceStatus.enabled && mounted) {
        serviceEnabled = true;
        serviceStatusSubscription?.cancel();
        Navigator.pop(context);
        await _checkPermissionsAndGetLocation();
      }
    });

    Future.delayed(const Duration(seconds: 30), () {
      if (mounted && !serviceEnabled) {
        serviceStatusSubscription?.cancel();
        Navigator.pop(context);
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => const PermissionRequestScreen(),
          ),
          (route) => false,
        );
      }
    });

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
              serviceStatusSubscription?.cancel();
              Navigator.pop(context);
              await Geolocator.openLocationSettings();
              if (mounted && !serviceEnabled) {
                await _checkPermissionsAndGetLocation();
              }
            },
            child: const Text(
              'فعال کردن',
              style: TextStyle(color: Colors.teal, fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(
            onPressed: () {
              serviceStatusSubscription?.cancel();
              Navigator.pop(context);
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (context) => const PermissionRequestScreen(),
                ),
                (route) => false,
              );
            },
            child: const Text(
              'بازگشت',
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _checkPermissionsAndGetLocation();
            },
            child: const Text(
              'تلاش مجدد',
              style: TextStyle(color: Colors.teal, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    serviceStatusSubscription?.cancel();
    setState(() {
      _isGpsDialogOpen = false;
    });
  }

  Future<bool> _checkInternetConnectivity() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'برای دریافت این سرویس اتصال شبکه اینترنت را بررسی کنید',
          ),
        ),
      );
      return false;
    }
    return true;
  }

  Future<void> _centerOnCurrentLocation() async {
    // جلوگیری از درخواست‌های موازی
    if (_isGpsDialogOpen || _isFetchingLocation) return;

    setState(() {
      _isFetchingLocation = true;
    });

    // بررسی سرویس GPS
    if (!await Geolocator.isLocationServiceEnabled()) {
      if (mounted) {
        final now = DateTime.now();
        if (_lastErrorTime == null ||
            now.difference(_lastErrorTime!).inSeconds >= 5) {
          _lastErrorTime = now;
          await _showEnableGpsDialog();
        }
      }
      setState(() {
        _isFetchingLocation = false;
      });
      return;
    }

    // بررسی کش موقعیت
    if (_lastValidPosition != null &&
        _lastLocationFetchTime != null &&
        DateTime.now().difference(_lastLocationFetchTime!) < _cacheValidity) {
      if (mounted) {
        setState(() {
          _currentPosition = _lastValidPosition;
          _isFetchingLocation = false;
        });
        _mapController.move(_currentPosition!, 15.0);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('موقعیت کنونی از حافظه نمایش داده شد')),
        );
      }
      return;
    }

    // تلاش برای دریافت موقعیت جدید
    for (int attempt = 1; attempt <= _maxAttempts; attempt++) {
      try {
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.bestForNavigation, // دقت بالاتر
          timeLimit: const Duration(seconds: 8), // زمان انتظار کمتر
        );
        if (mounted) {
          final newPosition = latlng.LatLng(
            position.latitude,
            position.longitude,
          );
          setState(() {
            _currentPosition = newPosition;
            _lastValidPosition = newPosition; // ذخیره در کش
            _lastLocationFetchTime = DateTime.now(); // به‌روزرسانی زمان
            _isFetchingLocation = false;
          });
          _mapController.move(_currentPosition!, 15.0);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('موقعیت کنونی با موفقیت به‌روزرسانی شد'),
            ),
          );
          return;
        }
      } catch (e) {
        if (mounted) {
          developer.log('Attempt $attempt failed: $e');
        }
        if (attempt == _maxAttempts) {
          // در صورت شکست تمام تلاش‌ها
          if (_lastValidPosition != null && mounted) {
            // استفاده از آخرین موقعیت معتبر
            setState(() {
              _currentPosition = _lastValidPosition;
              _isFetchingLocation = false;
            });
            _mapController.move(_currentPosition!, 15.0);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'دریافت موقعیت جدید ناموفق بود. استفاده از آخرین موقعیت معتبر.',
                ),
              ),
            );
          } else {
            // استفاده از موقعیت پیش‌فرض
            if (mounted) {
              setState(() {
                _currentPosition = _fallbackPosition;
                _isFetchingLocation = false;
              });
              _mapController.move(_currentPosition!, 15.0);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'دریافت موقعیت با شکست مواجه شد. استفاده از موقعیت پیش‌فرض (مشهد).',
                  ),
                ),
              );
            }
          }
          return;
        }
        await Future.delayed(_retryDelay); // تاخیر کوتاه‌تر بین تلاش‌ها
      }
    }
  }

  void _addPoint(latlng.LatLng position) {
    setState(() {
      if (_selectionState == 'origin') {
        _origin = position;
        _selectionState = 'destination';
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('مبدا انتخاب شد. لطفاً مقصد را انتخاب کنید.'),
          ),
        );
      } else if (_selectionState == 'destination') {
        _destination = position;
        _selectionState = 'done';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('مقصد انتخاب شد.')));
        _drawRoute();
      } else {
        _origin = position;
        _destination = null;
        _polylinePoints.clear();
        _selectionState = 'destination';
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('مبدا انتخاب شد. لطفاً مقصد را انتخاب کنید.'),
          ),
        );
      }
    });
  }

  Future<void> _drawRoute() async {
    if (_origin == null || _destination == null) return;

    if (!await _checkInternetConnectivity()) {
      return;
    }

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
            'هیچ مسیری یافت نشد. لطفاً نقاط نزدیک به جاده یا مسیر پیاده‌رو انتخاب کنید یا اتصال اینترنت را بررسی کنید.',
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
            const SnackBar(
              content: Text(
                'برای دریافت این سرویس اتصال شبکه اینترنت را متصل کنید',
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
            const SnackBar(
              content: Text(
                'خطای API: لطفاً نقاط دیگری انتخاب کنید یا اتصال اینترنت را بررسی کنید.',
              ),
            ),
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
              const SnackBar(
                content: Text(
                  'هیچ مختصات معتبری یافت نشد. لطفاً نقاط دیگری انتخاب کنید.',
                ),
              ),
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
              content: Text(
                'پاسخ نامعتبر از API. لطفاً نقاط معتبر انتخاب کنید یا اتصال اینترنت را بررسی کنید.',
              ),
            ),
          );
        }
        return false;
      }
    } catch (e) {
      if (mounted) {
        developer.log('Error fetching route ($vehicle): $e');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'برای دریافت این سرویس اتصال شبکه اینترنت را متصل کنید',
            ),
          ),
        );
      }
      return false;
    }
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Center(
        child: TaskHelpDialog(
          helpText:
              'بسته به انتخاب مسیر‌یابی با خودرو یا پیاده، بین مبدا و مقصد مسیر پیشنهادی مشخص می‌شود.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('مسیر یابی'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: 'راهنما',
            onPressed: _showHelpDialog,
          ),
        ],
      ),
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
                  padding: const EdgeInsets.all(8),
                  color: Colors.teal.shade50,
                  child: Text(
                    _selectionState == 'origin'
                        ? 'انتخاب مبدا'
                        : _selectionState == 'destination'
                        ? 'مبدا انتخاب شده - انتخاب مقصد'
                        : 'مبدا و مقصد انتخاب شده‌اند',
                    style: const TextStyle(
                      fontFamily: 'Vazir',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.teal,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12),
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
                          _selectionState = 'origin';
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
        onPressed: (_isGpsDialogOpen || _isCentering)
            ? null
            : _centerOnCurrentLocation,
        child: const Icon(Icons.my_location, size: 28),
        tooltip: 'موقعیت کنونی',
      ),
    );
  }
}
