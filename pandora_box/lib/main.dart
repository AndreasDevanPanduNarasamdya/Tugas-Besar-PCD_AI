import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart'; // REQUIRED: Add this dependency
import 'bloc/scan_bloc.dart';
import 'storage/scan_repository.dart'; // REQUIRED: Import your repo
import 'ui/theme/app_theme.dart';
import 'ui/screens/welcome_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Initialize Hive and your repository
  await Hive.initFlutter();
  final scanRepo = ScanRepository();
  await scanRepo.init();

  // 2. Lock to portrait orientation
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // 3. Full screen immersive
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: AppTheme.darkBackground,
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  runApp(const PandoraBoxApp());
}

class PandoraBoxApp extends StatelessWidget {
  const PandoraBoxApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ScanBloc(),
      child: MaterialApp(
        title: 'Pandora Box',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: const WelcomeScreen(),
      ),
    );
  }
}
