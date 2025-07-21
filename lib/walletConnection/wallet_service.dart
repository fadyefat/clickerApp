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
  // Remove the subscription variable since subscribe() returns void
  bool _isConnected = false;
  bool _isInitializing = true;

  @override
  void initState() {
    super.initState();
    _initModal();
  }

  Future<void> _initModal() async {
    try {
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

      if (mounted) {
        setState(() {
          _appKitModal = modal;
          _isInitializing = false;
        });

        // Debug: Add print statements to see what's happening
        print('Modal initialized successfully');

        // Listen for connection events - try multiple event types
        modal.onModalConnect.subscribe((ModalConnect? event) {
          print('onModalConnect triggered: $event');
          if (mounted && !_isConnected && event != null) {
            print('Navigating to GameScreen via onModalConnect');
            setState(() => _isConnected = true);
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

        // Also listen to the appKit events directly
        widget.appKit.onSessionConnect.subscribe((SessionConnect? event) {
          print('onSessionConnect triggered: $event');
          if (mounted && !_isConnected && event != null) {
            print('Navigating to GameScreen via onSessionConnect');
            setState(() => _isConnected = true);
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

        // Periodically check connection status
        _startConnectionCheck(modal);

        // Check if already connected
        final isConnected = await modal.isConnected;
        print('Initial connection status: $isConnected');
        if (isConnected && mounted && !_isConnected) {
          print('Already connected, navigating to GameScreen');
          setState(() => _isConnected = true);
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
      }
    } catch (e) {
      print('Error in _initModal: $e');
      if (mounted) {
        setState(() => _isInitializing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to initialize wallet: $e')),
        );
      }
    }
  }

  Timer? _connectionCheckTimer;

  void _startConnectionCheck(ReownAppKitModal modal) {
    _connectionCheckTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      if (!mounted || _isConnected) {
        timer.cancel();
        return;
      }

      try {
        final isConnected = await modal.isConnected;
        print('Periodic connection check: $isConnected');

        if (isConnected && !_isConnected) {
          print('Connection detected via periodic check, navigating to GameScreen');
          timer.cancel();
          setState(() => _isConnected = true);
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
      } catch (e) {
        print('Error checking connection status: $e');
      }
    });
  }

  @override
  void dispose() {
    _connectionCheckTimer?.cancel();
    _appKitModal?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing || _appKitModal == null) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Initializing wallet connection...'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.account_balance_wallet,
              size: 80,
              color: Colors.orange,
            ),
            const SizedBox(height: 24),
            const Text(
              "Let's connect your wallet",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              "Connect your wallet to start playing",
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 32),
            AppKitModalConnectButton(appKit: _appKitModal!),
            const SizedBox(height: 16),
            // Debug button to manually check connection
            ElevatedButton(
              onPressed: () async {
                try {
                  final isConnected = await _appKitModal!.isConnected;
                  print('Manual check - Connected: $isConnected');

                  if (isConnected && !_isConnected) {
                    setState(() => _isConnected = true);
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => GameScreen(
                          appKit: widget.appKit,
                          appKitModal: _appKitModal!,
                        ),
                      ),
                    );
                  } else if (!isConnected) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Wallet not connected. Please connect first.'),
                      ),
                    );
                  }
                } catch (e) {
                  print('Error checking connection: $e');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              child: const Text('Check Connection & Continue'),
            ),
          ],
        ),
      ),
    );
  }
}