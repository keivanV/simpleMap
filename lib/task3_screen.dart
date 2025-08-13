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
import 'dart:developer' as developer;

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
  bool _isGpsDialogOpen = false;
  bool _isFetchingLocation = false;
  bool _isInternetConnected = false;
  StreamSubscription<Position>? _positionSubscription;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  String _selectedMode = 'car';
  String _selectionState = 'origin'; // 'origin', 'destination', 'done'
  final latlng.LatLng _fallbackPosition = const latlng.LatLng(36.2970, 59.6062);
  final String _apiKey =
      'eyJvcmciOiI1YjNjZTM1OTc4NTExMTAwMDFjZjYyNDgiLCJpZCI6ImRkNzBlMjg5ZDEyZTQ5MDQ5ZjZjN2ZiNTE1ZGEyZWMyIiwiaCI6Im11cm11cjY0In0=';
  DateTime? _lastErrorTime;
  DateTime? _lastLocationFetchTime;
  latlng.LatLng? _lastValidPosition;
  static const int _maxAttempts = 7;
  static const Duration _retryDelay = Duration(milliseconds: 300);
  static const Duration _cacheValidity = Duration(seconds: 10);

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
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const PermissionRequestScreen(),
            ),
          );
        }
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const PermissionRequestScreen(),
          ),
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
            _lastValidPosition = newPosition;
            _lastLocationFetchTime = DateTime.now();
            _isLoading = false;
          });
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _mapController.move(_currentPosition!, 15.0);
            }
          });

          _positionSubscription =
              Geolocator.getPositionStream(
                locationSettings: const LocationSettings(
                  accuracy: LocationAccuracy.high,
                  distanceFilter: 5,
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
                      if (mounted && !_isFetchingLocation) {
                        _mapController.move(_currentPosition!, 15.0);
                      }
                    });
                  }
                },
                onError: (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'خطا در جریان موقعیت: $e',
                          style: const TextStyle(fontFamily: 'Vazir'),
                        ),
                      ),
                    );
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const PermissionRequestScreen(),
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
              if (mounted) {
                _mapController.move(_currentPosition!, 15.0);
              }
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
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const PermissionRequestScreen(),
          ),
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
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PermissionRequestScreen(),
                  ),
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

  Future<void> _centerOnCurrentLocation() async {
    if (_isGpsDialogOpen || _isFetchingLocation || !_isInternetConnected)
      return;

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
              content: Text(
                'موقعیت کنونی با موفقیت به‌روزرسانی شد',
                style: TextStyle(fontFamily: 'Vazir'),
              ),
            ),
          );
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
        await Future.delayed(_retryDelay);
      }
    }
  }

  void _addPoint(latlng.LatLng position) async {
    if (!_isInternetConnected) {
      await _showInternetRequiredDialog();
      return;
    }

    setState(() {
      if (_selectionState == 'origin') {
        _origin = position;
        _selectionState = 'destination';
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'مبدا انتخاب شد. لطفاً مقصد را انتخاب کنید.',
              style: TextStyle(fontFamily: 'Vazir'),
            ),
          ),
        );
      } else if (_selectionState == 'destination') {
        _destination = position;
        _selectionState = 'done';
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'مقصد انتخاب شد.',
              style: TextStyle(fontFamily: 'Vazir'),
            ),
          ),
        );
        _drawRoute();
      } else {
        _origin = position;
        _destination = null;
        _polylinePoints.clear();
        _selectionState = 'destination';
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'مبدا انتخاب شد. لطفاً مقصد را انتخاب کنید.',
              style: TextStyle(fontFamily: 'Vazir'),
            ),
          ),
        );
      }
    });
  }

  Future<void> _drawRoute() async {
    if (_origin == null || _destination == null || !_isInternetConnected) {
      if (!_isInternetConnected) {
        await _showInternetRequiredDialog();
      }
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
            style: TextStyle(fontFamily: 'Vazir'),
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
                'خطا در دریافت مسیر. لطفاً اتصال اینترنت را بررسی کنید.',
                style: TextStyle(fontFamily: 'Vazir'),
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
                style: TextStyle(fontFamily: 'Vazir'),
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
                  style: TextStyle(fontFamily: 'Vazir'),
                ),
              ),
            );
          }
          return false;
        }

        if (mounted) {
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
        }
        return true;
      } else {
        if (mounted) {
          developer.log('Invalid response format: ${response.body}');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'پاسخ نامعتبر از API. لطفاً نقاط معتبر انتخاب کنید یا اتصال اینترنت را بررسی کنید.',
                style: TextStyle(fontFamily: 'Vazir'),
              ),
            ),
          );
        }
        return false;
      }
    } catch (e) {
      if (mounted) {
        developer.log('Error fetching route ($vehicle): $e');
        setState(() {
          _isInternetConnected = false;
        });
        await _showInternetRequiredDialog();
      }
      return false;
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
              'بسته به انتخاب مسیر‌یابی با خودرو یا پیاده، بین مبدا و مقصد مسیر پیشنهادی مشخص می‌شود.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('مسیریابی', style: TextStyle(fontFamily: 'Vazir')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
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
                        if (_origin != null && _destination != null) {
                          _drawRoute();
                        }
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
