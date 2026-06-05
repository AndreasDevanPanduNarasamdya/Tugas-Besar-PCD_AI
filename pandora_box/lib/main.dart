import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'bloc/scan_bloc.dart';
import 'config/env_config.dart';
import 'export/obj_exporter.dart';
import 'storage/scan_repository.dart';
import 'ui/screens/welcome_screen.dart';
import 'ui/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EnvConfig.load();

  final repository = ScanRepository();
  await repository.init();

  // We pass the repository into MyApp
  runApp(MyApp(repository: repository));
}

class MyApp extends StatelessWidget {
  final ScanRepository repository;

  // Constructor expects the repository
  const MyApp({super.key, required this.repository});

  @override
  Widget build(BuildContext context) {
    // 1. RepositoryProvider sits at the very top of the tree
    return RepositoryProvider.value(
      value: repository,
      // 2. BlocProvider sits directly below it
      child: BlocProvider(
        create: (_) => ScanBloc(
          repository: repository,
          exporter: ObjExporter(),
        ),
        // 3. MaterialApp sits inside the BlocProvider
        child: MaterialApp(
          title: 'Pandora Box',
          theme: AppTheme.darkTheme,
          home: const WelcomeScreen(),
          debugShowCheckedModeBanner: false,
        ),
      ),
    );
  }
}
