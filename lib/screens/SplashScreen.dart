import 'package:flutter/material.dart';
import 'package:reown_appkit/base/appkit_base_impl.dart';
import '../walletConnection/wallet_service.dart';

class SplashScreen extends StatelessWidget {
  final ReownAppKit appKit;

  const SplashScreen({super.key, required this.appKit});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.pink.shade100,
      body: Center(
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => WalletLoginPage(appKit: appKit),
              ),
            );
          },
          child: const Text("Connect Wallet", style: TextStyle(fontSize: 20)),
        ),
      ),
    );
  }
}
