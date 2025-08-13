import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlng;
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:apishro/permission_request_screen.dart';
import 'package:apishro/task_help_dialog.dart';
import 'package:cached_network_image/cached_network_image.dart';

class Task1Screen extends StatefulWidget {
  const Task1Screen({super.key});

  @override
  State<Task1Screen> createState() => _Task1ScreenState();
}

class _Task1ScreenState extends State<Task1Screen> {
  final MapController _mapController = MapController();
  latlng.LatLng? _currentPosition;
  bool _isLoading = true;
  bool _isInternetConnected = false;
  StreamSubscription<Position>? _positionSubscription;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  final latlng.LatLng _fallbackPosition = const latlng.LatLng(36.2970, 59.6062);
  DateTime? _lastErrorTime;
  DateTime? _lastLocationFetchTime;
  latlng.LatLng? _lastValidPosition;
  bool _isFetchingLocation = false;
  bool _isGpsDialogOpen = false;
  static const int _maxAttempts = 7;
  static const Duration _initialRetryDelay = Duration(milliseconds: 500);
  static const Duration _timeoutDuration = Duration(seconds: 15);

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await _checkInternetOnEntry();
      _startInternetMonitoring();
      if (_isInternetConnected) {
        await _checkPermissionsAndGetLocation();
      }
    });
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  Future<void> _checkInternetOnEntry() async {
    final connectivityResults = await Connectivity().checkConnectivity();
    if (!connectivityResults.contains(ConnectivityResult.wifi) &&
        !connectivityResults.contains(ConnectivityResult.mobile) &&
        mounted) {
      setState(() {
        _isLoading = false;
        _isInternetConnected = false;
      });
      await _showInternetRequiredDialog();
    } else {
      setState(() {
        _isInternetConnected = true;
      });
    }
  }

  void _startInternetMonitoring() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      List<ConnectivityResult> results,
    ) async {
      if (!results.contains(ConnectivityResult.wifi) &&
          !results.contains(ConnectivityResult.mobile) &&
          mounted) {
        setState(() {
          _isInternetConnected = false;
        });
        await _showInternetRequiredDialog();
      } else if (mounted) {
        setState(() {
          _isInternetConnected = true;
        });
        if (_currentPosition == null) {
          await _checkPermissionsAndGetLocation();
        }
      }
    });
  }

  Future<bool> _checkInternetConnectivity() async {
    final connectivityResults = await Connectivity().checkConnectivity();
    if (!connectivityResults.contains(ConnectivityResult.wifi) &&
        !connectivityResults.contains(ConnectivityResult.mobile) &&
        mounted) {
      setState(() {
        _isInternetConnected = false;
      });
      return false;
    }
    return true;
  }

  Future<void> _showInternetRequiredDialog() async {
    if (!mounted) return;

    bool isConnected = false;
    StreamSubscription<List<ConnectivityResult>>? connectivitySubscription;

    connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      results,
    ) async {
      if ((results.contains(ConnectivityResult.wifi) ||
              results.contains(ConnectivityResult.mobile)) &&
          mounted) {
        isConnected = true;
        connectivitySubscription?.cancel();
        Navigator.pop(context);
        setState(() {
          _isInternetConnected = true;
        });
        if (_currentPosition == null) {
          await _checkPermissionsAndGetLocation();
        }
      }
    });

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => WillPopScope(
        onWillPop: () async => false,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'اتصال اینترنت مورد نیاز است',
            style: TextStyle(fontFamily: 'Vazir', fontWeight: FontWeight.w600),
          ),
          content: const Text(
            'اتصال اینترنت برقرار نیست. لطفاً اینترنت را وصل کنید.',
            style: TextStyle(fontFamily: 'Vazir', fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                connectivitySubscription?.cancel();
                Navigator.pop(context);
                if (!await _checkInternetConnectivity()) {
                  await _showInternetRequiredDialog();
                } else if (mounted && _currentPosition == null) {
                  await _checkPermissionsAndGetLocation();
                }
              },
              child: const Text(
                'تلاش مجدد',
                style: TextStyle(
                  fontFamily: 'Vazir',
                  color: Colors.teal,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    connectivitySubscription?.cancel();
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

    await _fetchAndTrackLocation();
  }

  Future<void> _fetchAndTrackLocation() async {
    int attempt = 1;
    Duration retryDelay = _initialRetryDelay;

    while (attempt <= _maxAttempts && mounted) {
      try {
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.bestForNavigation,
          timeLimit: _timeoutDuration,
        ).timeout(_timeoutDuration);
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

          _positionSubscription?.cancel();
          _positionSubscription =
              Geolocator.getPositionStream(
                locationSettings: const LocationSettings(
                  accuracy: LocationAccuracy.high,
                  distanceFilter: 1,
                ),
              ).listen(
                (Position position) {
                  if (mounted) {
                    final newPosition = latlng.LatLng(
                      position.latitude,
                      position.longitude,
                    );
                    setState(() {
                      _currentPosition = newPosition;
                      _lastValidPosition = newPosition;
                      _lastLocationFetchTime = DateTime.now();
                    });
                    if (!_isFetchingLocation) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted)
                          _mapController.move(_currentPosition!, 15.0);
                      });
                    }
                  }
                },
                onError: (e) async {
                  if (mounted) {
                    String errorMessage = 'خطا در جریان موقعیت: $e';
                    if (e is TimeoutException) {
                      errorMessage =
                          'عدم دریافت موقعیت در زمان تعیین‌شده. تلاش مجدد...';
                      _positionSubscription?.cancel();
                      await Future.delayed(_initialRetryDelay);
                      _fetchAndTrackLocation();
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          errorMessage,
                          style: const TextStyle(fontFamily: 'Vazir'),
                        ),
                        duration: const Duration(seconds: 4),
                      ),
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
                  style: TextStyle(fontFamily: 'Vazir'),
                ),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'دریافت موقعیت با شکست مواجه شد. استفاده از موقعیت پیش‌فرض (مشهد).',
                  style: TextStyle(fontFamily: 'Vazir'),
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
          return;
        }
        await Future.delayed(retryDelay);
        retryDelay = Duration(milliseconds: retryDelay.inMilliseconds * 2);
        attempt++;
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
      builder: (context) => WillPopScope(
        onWillPop: () async => false,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'فعال‌سازی GPS',
            style: TextStyle(fontFamily: 'Vazir', fontWeight: FontWeight.w600),
          ),
          content: const Text(
            'لطفاً GPS را فعال کنید تا از این قابلیت استفاده کنید.',
            style: TextStyle(fontFamily: 'Vazir', fontSize: 16),
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
                style: TextStyle(
                  fontFamily: 'Vazir',
                  color: Colors.teal,
                  fontWeight: FontWeight.w600,
                ),
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
                  fontFamily: 'Vazir',
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
                style: TextStyle(
                  fontFamily: 'Vazir',
                  color: Colors.teal,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    serviceStatusSubscription?.cancel();
    setState(() {
      _isGpsDialogOpen = false;
    });
  }

  Future<void> _showCurrentLocationAddress() async {
    if (_isFetchingLocation ||
        !_isInternetConnected ||
        _currentPosition == null) {
      if (!_isInternetConnected) {
        await _showInternetRequiredDialog();
      }
      return;
    }

    if (!await _checkInternetConnectivity()) {
      await _showInternetRequiredDialog();
      return;
    }

    setState(() {
      _isFetchingLocation = true;
    });

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

    int attempt = 1;
    Duration retryDelay = _initialRetryDelay;

    while (attempt <= _maxAttempts && mounted) {
      try {
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.bestForNavigation,
          timeLimit: _timeoutDuration,
        ).timeout(_timeoutDuration);
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

          try {
            final response = await http
                .get(
                  Uri.parse(
                    'https://nominatim.openstreetmap.org/reverse?format=json&lat=${newPosition.latitude}&lon=${newPosition.longitude}&zoom=18&addressdetails=1',
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
                address['state'] ?? '',
                address['country'] ?? '',
              ].where((e) => e.isNotEmpty).join(', ');

              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  title: const Text(
                    'موقعیت کنونی شما',
                    style: TextStyle(
                      fontFamily: 'Vazir',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  content: Text(
                    detailedAddress.isEmpty ? 'آدرس یافت نشد' : detailedAddress,
                    style: const TextStyle(fontFamily: 'Vazir', fontSize: 16),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        'بستن',
                        style: TextStyle(
                          fontFamily: 'Vazir',
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
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'آدرس یافت نشد',
                      style: TextStyle(fontFamily: 'Vazir'),
                    ),
                  ),
                );
              }
            }
          } catch (e) {
            if (mounted) {
              setState(() {
                _isInternetConnected = false;
              });
              await _showInternetRequiredDialog();
            }
          }
          return;
        }
      } catch (e) {
        if (attempt == _maxAttempts && mounted) {
          if (_lastValidPosition != null) {
            setState(() {
              _currentPosition = _lastValidPosition;
              _isFetchingLocation = false;
            });
            _mapController.move(_currentPosition!, 15.0);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'دریافت موقعیت جدید ناموفق بود. استفاده از آخرین موقعیت معتبر.',
                  style: TextStyle(fontFamily: 'Vazir'),
                ),
              ),
            );
          } else {
            setState(() {
              _currentPosition = _fallbackPosition;
              _isFetchingLocation = false;
            });
            _mapController.move(_currentPosition!, 15.0);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'دریافت موقعیت با شکست مواجه شد. استفاده از موقعیت پیش‌فرض (مشهد).',
                  style: TextStyle(fontFamily: 'Vazir'),
                ),
              ),
            );
          }
          return;
        }
        await Future.delayed(retryDelay);
        retryDelay = Duration(milliseconds: retryDelay.inMilliseconds * 2);
        attempt++;
      }
    }
  }

  void _showHelpDialog() {
    if (!_isInternetConnected) return;
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Center(
        child: TaskHelpDialog(
          helpText:
              'موقعیت شما به‌صورت خودکار با حرکت به‌روزرسانی می‌شود. برای مشاهده آدرس دقیق موقعیت کنونی خود، روی دکمه "نمایش آدرس کنونی" کلیک کنید.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'نمایش موقعیت',
          style: TextStyle(fontFamily: 'Vazir'),
        ),
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
          : !_isInternetConnected
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'اتصال اینترنت برقرار نیست. لطفاً ابتدا اینترنت را وصل کنید.',
                    style: TextStyle(
                      fontFamily: 'Vazir',
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () async {
                      await _checkInternetOnEntry();
                      if (_isInternetConnected && _currentPosition == null) {
                        await _checkPermissionsAndGetLocation();
                      }
                    },
                    child: const Text(
                      'تلاش مجدد',
                      style: TextStyle(fontFamily: 'Vazir', fontSize: 16),
                    ),
                  ),
                ],
              ),
            )
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
          : Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _currentPosition!,
                    initialZoom: 15.0,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      additionalOptions: const {
                        'userAgent': 'com.example.neshanpishro/1.0',
                      },
                      tileProvider: CachedNetworkTileProvider(),
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
                      ],
                    ),
                  ],
                ),
                Positioned(
                  bottom: 80,
                  left: 16,
                  right: 16,
                  child: ElevatedButton(
                    onPressed: _isFetchingLocation
                        ? null
                        : _showCurrentLocationAddress,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.teal,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'نمایش آدرس کنونی',
                      style: TextStyle(
                        fontFamily: 'Vazir',
                        fontSize: 16,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
      floatingActionButton: _isInternetConnected
          ? FloatingActionButton(
              onPressed: _isFetchingLocation
                  ? null
                  : _showCurrentLocationAddress,
              child: const Icon(Icons.my_location, size: 28),
              tooltip: 'نمایش آدرس کنونی',
            )
          : null,
    );
  }
}

class CachedNetworkTileProvider extends TileProvider {
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    final url = options.urlTemplate!.replaceAllMapped(
      RegExp(r'\{([^{}]*)\}'),
      (match) => match.group(1) == 'x'
          ? coordinates.x.toInt().toString()
          : match.group(1) == 'y'
          ? coordinates.y.toInt().toString()
          : match.group(1) == 'z'
          ? coordinates.z.toInt().toString()
          : match.group(0)!,
    );
    return CachedNetworkImageProvider(
      url,
      headers: {
        'User-Agent': options.additionalOptions['userAgent'] ?? 'unknown',
      },
    );
  }
}
