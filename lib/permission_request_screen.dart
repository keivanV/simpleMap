import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:apishro/task_selection_screen.dart';
import 'package:apishro/animated_scale_button.dart';

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
