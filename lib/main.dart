import 'package:flutter/material.dart';
import 'package:reown_appkit/reown_appkit.dart';
import 'screens/SplashScreen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final appKit = await ReownAppKit.createInstance(
    projectId: '47a573f8635bdc22adf4030bdca85210',
    metadata: const PairingMetadata(
      name: 'Clicker',
      description: 'Clicker bee',
      url: 'https://github.com/',
      icons: ['https://raw.githubusercontent.com/.../metamask-fox.svg'],
      redirect: Redirect(
        native: 'electionx://callback',
        universal: 'https://yourapp.com/electionx',
      ),
    ),
  );

  runApp(MyApp(appKit: appKit));
}

class MyApp extends StatelessWidget {
  final ReownAppKit appKit;
  const MyApp({super.key, required this.appKit});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Clicker Bee',
      theme: ThemeData.light(),
      home: SplashScreen(appKit: appKit),
    );
  }
}
