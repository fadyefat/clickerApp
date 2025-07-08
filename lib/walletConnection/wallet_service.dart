import 'dart:async';
import 'package:flutter/material.dart';
import 'package:reown_appkit/reown_appkit.dart';
import '../screens/GameScreen.dart';

class WalletLoginPage extends StatefulWidget {
  final ReownAppKit appKit;

  const WalletLoginPage({super.key, required this.appKit});

  @override
  State<WalletLoginPage> createState() => _WalletLoginPageState();
}

class _WalletLoginPageState extends State<WalletLoginPage> {
  ReownAppKitModal? _appKitModal;
  Timer? _connectionTimer;
  bool _isConnected = false;

  @override
  void initState() {
    super.initState();
    _initModal();
  }

  Future<void> _initModal() async {
    final modal = ReownAppKitModal(
      appKit: widget.appKit,
      context: context,
      projectId: '47a573f8635bdc22adf4030bdca85210',
      metadata: const PairingMetadata(
        name: 'Clicker',
        description: 'Clicker Bee',
        url: 'https://github.com/',
        icons: ['https://raw.githubusercontent.com/.../metamask-fox.svg'],
        redirect: Redirect(
          native: 'electionx://callback',
          universal: 'https://yourapp.com/electionx',
        ),
      ),
    );

    await modal.init();

    setState(() => _appKitModal = modal);

    _connectionTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      final connected = await modal.isConnected;
      if (connected) {
        _connectionTimer?.cancel();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => GameScreen(
              appKit: widget.appKit,
              appKitModal: modal,
            ),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _connectionTimer?.cancel();
    _appKitModal?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_appKitModal == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("Let's connect your wallet", style: TextStyle(fontSize: 18)),
            const SizedBox(height: 20),
            AppKitModalConnectButton(appKit: _appKitModal!),
          ],
        ),
      ),
    );
  }
}
