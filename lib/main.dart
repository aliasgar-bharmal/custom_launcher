import 'dart:async';
import 'dart:developer';

import 'package:device_installed_apps/app_info.dart';
import 'package:device_installed_apps/device_installed_apps.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Set system UI to be transparent
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.transparent,
  ));
  WallpaperService.requestLauncherRole();
  runApp(const MyApp());
}

class WallpaperService {
  static Future<bool> ensureStoragePermission() async {
    final storage = Permission.storage; // for < Android 13
    final media = Permission.photos; // for Android 13+

    final storageStatus = await storage.request();
    final mediaStatus = await media.request();

    return storageStatus.isGranted || mediaStatus.isGranted;
  }

  static const _channel = MethodChannel('wallpaper_channel');

  /// Fetches current home screen wallpaper as bytes
  static Future<Uint8List?> fetchWallpaperBytes() async {
    try {
      if (await ensureStoragePermission()) {
        final bytes = await _channel.invokeMethod<Uint8List>('getWallpaper');

        return bytes;
      } else {
        log('Permission denied');
        return null;
      }
    } catch (e) {
      log('Failed to fetch wallpaper: $e');
      return null;
    }
  }

  static const platform = MethodChannel('wallpaper_channel');

  static Future<void> requestLauncherRole() async {
    try {
      final granted = await platform.invokeMethod('requestLauncherRole');
      log("Launcher role granted: $granted");
    } catch (e) {
      log("Error requesting launcher role: $e");
    }
  }
}

Future<List<AppInfo>> getInstalledApps() async {
  try {
    List<AppInfo> apps = await DeviceInstalledApps.getApps(
      includeSystemApps: false,
      includeIcon: true,
    );

    return apps;
  } catch (error) {
    rethrow;
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  void _incrementCounter() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AppListPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: AppClock(),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.apps),
      ),
    );
  }
}

class WallpaperScreen extends StatelessWidget {
  const WallpaperScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: WallpaperService.fetchWallpaperBytes(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return const Center(child: Text('Unable to load wallpaper.'));
        }
        return Image.memory(snapshot.data!);
      },
    );
  }
}

class AppListPage extends StatefulWidget {
  const AppListPage({super.key});

  @override
  State<AppListPage> createState() => AppListPageState();
}

class AppListPageState extends State<AppListPage> {
  List<AppInfo> apps = [];
  @override
  void initState() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        apps = await getInstalledApps();
        setState(() {});
      } catch (e) {
        log(e.toString());
      }
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView.separated(
        itemCount: apps.length,
        itemBuilder: (context, index) {
          return GestureDetector(
            onTap: () {
              DeviceInstalledApps.launchApp(apps[index].bundleId ?? "");
            },
            onDoubleTap: () {
              DeviceInstalledApps.openAppSetting(apps[index].bundleId ?? "");
            },
            child: ListTile(
              title: Text('${apps[index].name}'),
            ),
          );
        },
        separatorBuilder: (context, index) => Padding(
          padding: const EdgeInsets.all(8.0),
          child: Divider(),
        ),
      ),
    );
  }
}

class AppClock extends StatefulWidget {
  const AppClock({super.key});

  @override
  State<AppClock> createState() => _AppClockState();
}

class _AppClockState extends State<AppClock> {
  final ValueNotifier<DateTime> _now = ValueNotifier(DateTime.now());
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _now.value = DateTime.now();
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _now.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TimeUnitText(
            now: _now,
            extractUnit: (dt) =>
                dt.hour.toString().padLeft(2, '0').split('').first,
          ),
          TimeUnitText(
            now: _now,
            extractUnit: (dt) =>
                dt.hour.toString().padLeft(2, '0').split('').last,
          ),
          const TimeSeparator(),
          TimeUnitText(
            now: _now,
            extractUnit: (dt) =>
                dt.minute.toString().padLeft(2, '0').split('').first,
          ),
          TimeUnitText(
            now: _now,
            extractUnit: (dt) =>
                dt.minute.toString().padLeft(2, '0').split('').last,
          ),
          const TimeSeparator(),
          TimeUnitText(
            now: _now,
            extractUnit: (dt) =>
                dt.second.toString().padLeft(2, '0').split('').first,
          ),
          TimeUnitText(
            now: _now,
            extractUnit: (dt) =>
                dt.second.toString().padLeft(2, '0').split('').last,
          ),
        ],
      ),
    );
  }
}

class TimeUnitText extends StatelessWidget {
  final ValueNotifier<DateTime> now;
  final String Function(DateTime) extractUnit;

  const TimeUnitText({
    super.key,
    required this.now,
    required this.extractUnit,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<DateTime>(
      valueListenable: now,
      builder: (_, dateTime, __) {
        final value = extractUnit(dateTime);
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 100),
          transitionBuilder: (child, animation) =>
              FadeTransition(opacity: animation, child: child),
          child: Text(
            value,
            key: ValueKey(value),
            style: const TextStyle(
              fontSize: 40,
              color: Colors.white,
              fontWeight: FontWeight.bold,
              letterSpacing: 2.0,
              shadows: [
                Shadow(
                  blurRadius: 8,
                  color: Colors.blueAccent,
                  offset: Offset(0, 0),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class TimeSeparator extends StatelessWidget {
  const TimeSeparator({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        ':',
        style: TextStyle(fontSize: 40, color: Colors.white),
      ),
    );
  }
}
