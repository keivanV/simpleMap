import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlng;
import 'package:geolocator/geolocator.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:apishro/permission_request_screen.dart';
import 'package:apishro/task_help_dialog.dart';
import 'package:cached_network_image/cached_network_image.dart';

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
  bool _isInternetConnected = false;
  StreamSubscription<Position>? _positionSubscription;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  final latlng.LatLng _fallbackPosition = const latlng.LatLng(36.2970, 59.6062);
  DateTime? _lastErrorTime;
  DateTime? _lastLocationFetchTime;
  latlng.LatLng? _lastValidPosition;
  static const int _maxAttempts = 7;
  static const Duration _initialRetryDelay = Duration(milliseconds: 500);
  static const Duration _timeoutDuration = Duration(seconds: 15);
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await _initializeNotifications();
      await _checkInternetOnEntry();
      _startInternetMonitoring();
      if (_isInternetConnected) {
        await _loadMarkers();
        await _checkPermissionsAndStartTracking();
      }
    });
  }

  Future<void> _initializeNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);
    await _flutterLocalNotificationsPlugin.initialize(initializationSettings);

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'proximity_channel',
      'Proximity Alerts',
      description: 'Notifications for proximity alerts',
      importance: Importance.high,
    );
    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);
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
    _connectivitySubscription?.cancel();
    _positionSubscription = null;
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
          await _checkPermissionsAndStartTracking();
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
          await _checkPermissionsAndStartTracking();
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
                  await _checkPermissionsAndStartTracking();
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

  Future<void> _checkPermissionsAndStartTracking() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) await _showEnableGpsDialog();
      setState(() => _isLoading = false);
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
                'دسترسی به مکان رد شد. لطفاً دسترسی را از تنظیمات فعال کنید.',
                style: TextStyle(fontFamily: 'Vazir'),
              ),
            ),
          );
          await Geolocator.openLocationSettings();
        }
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'دسترسی به مکان برای همیشه رد شده است. لطفاً از تنظیمات دستگاه دسترسی را فعال کنید.',
              style: TextStyle(fontFamily: 'Vazir'),
            ),
          ),
        );
        await Geolocator.openLocationSettings();
      }
      return;
    }

    // Proceed with either 'whileInUse' or 'always' permission
    if (permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always) {
      await _fetchAndTrackLocation();
    }
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
          await _checkProximityToMarkers();

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
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) _mapController.move(_currentPosition!, 15.0);
                    });
                    _checkProximityToMarkers();
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
                  await _checkPermissionsAndStartTracking();
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
                await _checkPermissionsAndStartTracking();
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

  Future<void> _centerOnCurrentLocation() async {
    if (_isGpsDialogOpen || _isFetchingLocation || !_isInternetConnected) {
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
          await _checkProximityToMarkers();
          return;
        }
      } catch (e) {
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
                  style: TextStyle(fontFamily: 'Vazir'),
                ),
              ),
            );
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
                    style: TextStyle(fontFamily: 'Vazir'),
                  ),
                ),
              );
            }
          }
          return;
        }
        await Future.delayed(retryDelay);
        retryDelay = Duration(milliseconds: retryDelay.inMilliseconds * 2);
        attempt++;
      }
    }
  }

  Future<void> _checkProximityToMarkers() async {
    if (_currentPosition == null || !_isInternetConnected) return;

    const double proximityThreshold = 300; // meters
    final distance = const latlng.Distance();

    for (int i = 0; i < _markers.length; i++) {
      final marker = _markers[i];
      final distanceToMarker = distance(_currentPosition!, marker);

      if (distanceToMarker <= proximityThreshold) {
        if (!_notifiedMarkers.contains(i) && mounted) {
          setState(() {
            if (i < _activeMarkers.length) {
              _activeMarkers[i] = true;
            }
          });
          await _saveMarkers();
          await _flutterLocalNotificationsPlugin.show(
            i,
            'نزدیک شدن به نقطه',
            'شما به نقطه ${i + 1} در موقعیت (${marker.latitude.toStringAsFixed(4)}, ${marker.longitude.toStringAsFixed(4)}) نزدیک شده‌اید!',
            const NotificationDetails(
              android: AndroidNotificationDetails(
                'proximity_channel',
                'Proximity Alerts',
                channelDescription: 'Notifications for proximity alerts',
                importance: Importance.high,
                priority: Priority.high,
              ),
            ),
          );
          setState(() {
            _notifiedMarkers.add(i);
          });
        }
      } else {
        if (i < _activeMarkers.length && _activeMarkers[i]) {
          setState(() {
            _activeMarkers[i] = false;
          });
          await _saveMarkers();
        }
        if (_notifiedMarkers.contains(i)) {
          setState(() {
            _notifiedMarkers.remove(i);
          });
        }
      }
    }
  }

  Future<void> _checkProximityToNewMarker(latlng.LatLng marker) async {
    if (_currentPosition == null || !_isInternetConnected) return;

    const double proximityThreshold = 300; // meters
    final distance = const latlng.Distance();
    final distanceToMarker = distance(_currentPosition!, marker);

    if (distanceToMarker <= proximityThreshold && mounted) {
      final index = _markers.length - 1;
      setState(() {
        if (index < _activeMarkers.length) {
          _activeMarkers[index] = true;
        }
      });
      await _saveMarkers();
      await _flutterLocalNotificationsPlugin.show(
        index,
        'نزدیک شدن به نقطه جدید',
        'شما به نقطه جدید ${index + 1} در موقعیت (${marker.latitude.toStringAsFixed(4)}, ${marker.longitude.toStringAsFixed(4)}) نزدیک هستید!',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'proximity_channel',
            'Proximity Alerts',
            channelDescription: 'Notifications for proximity alerts',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
      );
      setState(() {
        _notifiedMarkers.add(index);
      });
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
              'برای انتخاب نقاط، روی نقشه ضربه بزنید تا نقاط ذخیره شوند. اگر به نقاط ذخیره‌شده نزدیک شوید، دایره اطراف آن‌ها قرمز شده و اعلان دریافت خواهید کرد. نقاط و وضعیت آن‌ها تا زمان حذف دستی ذخیره می‌مانند. می‌توانید نقاط را از لیست حذف کنید. موقعیت مکانی شما در هر ۱ متر به‌روزرسانی خواهد شد.',
        ),
      ),
    );
  }

  void _showMarkersList() {
    if (!_isInternetConnected) return;
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: const EdgeInsets.all(16),
          constraints: const BoxConstraints(maxHeight: 400),
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
      ),
    );
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('نقطه حذف شد', style: TextStyle(fontFamily: 'Vazir')),
        ),
      );
    }
  }

  void _addMarker(latlng.LatLng point) async {
    if (!_isInternetConnected) {
      await _showInternetRequiredDialog();
      return;
    }
    setState(() {
      _markers.add(point);
      _activeMarkers.add(false);
    });
    _saveMarkers();
    _checkProximityToNewMarker(point);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تسک دوم', style: TextStyle(fontFamily: 'Vazir')),
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
                        await _loadMarkers();
                        await _checkPermissionsAndStartTracking();
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
          : FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _currentPosition!,
                initialZoom: 15.0,
                onTap: _isInternetConnected
                    ? (tapPosition, point) => _addMarker(point)
                    : null,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  additionalOptions: const {
                    'userAgent': 'com.example.neshanpishro/1.0',
                  },
                  tileProvider: CachedNetworkTileProvider(),
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
      floatingActionButton: _isInternetConnected
          ? FloatingActionButton(
              onPressed:
                  (_isGpsDialogOpen ||
                      _isFetchingLocation ||
                      !_isInternetConnected)
                  ? null
                  : _centerOnCurrentLocation,
              child: const Icon(Icons.my_location, size: 28),
              tooltip: 'موقعیت کنونی',
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
