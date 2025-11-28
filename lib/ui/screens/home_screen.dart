import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/recording_manager.dart';
import '../../services/battery_optimization_service.dart';
import '../widgets/recording_button.dart';
import '../widgets/recording_list.dart';
import '../widgets/status_bar.dart';
import 'settings_screen.dart';
import 'search_screen.dart';
import 'calendar_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Start polling for transcription updates
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RecordingManager>().startStatusPolling();
      // Check and request battery optimization exemption on first launch
      BatteryOptimizationService.checkAndRequestBatteryOptimization(context);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final manager = context.read<RecordingManager>();
    if (state == AppLifecycleState.resumed) {
      manager.refreshRecordings();
      manager.startStatusPolling();
    } else if (state == AppLifecycleState.paused) {
      manager.stopStatusPolling();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Panauricon',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
        ),
        centerTitle: false, // Left-aligned
        toolbarHeight: 64, // More space for icons
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CalendarScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SearchScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => context.read<RecordingManager>().refreshRecordings(),
        child: Column(
          children: [
            const StatusBar(),
            const SizedBox(height: 20),
            const RecordingButton(),
            const SizedBox(height: 20),
            const Expanded(
              child: RecordingList(),
            ),
          ],
        ),
      ),
    );
  }
}
