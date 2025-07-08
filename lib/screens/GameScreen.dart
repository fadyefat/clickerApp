// ✅ النسخة المصححة بالكامل من GameScreen.dart
import 'package:flutter/material.dart';
import 'package:reown_appkit/base/appkit_base_impl.dart';
import 'package:reown_appkit/modal/appkit_modal_impl.dart';
import 'package:reown_appkit/modal/widgets/public/appkit_modal_connect_button.dart';
import 'ShopScreen.dart';
import 'UpgradeScreen.dart';

class GameScreen extends StatefulWidget {
  final ReownAppKit appKit;
  final ReownAppKitModal appKitModal;

  const GameScreen({
    super.key,
    required this.appKit,
    required this.appKitModal,
  });

  @override
  _GameScreenState createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  int _score = 0;
  int _tokenAmount = 0;
  double _beeScale = 1.0;
  Color backgroundColor = Colors.white;

  void _onTap() {
    setState(() {
      _score += 1;
      _beeScale = 0.8;
    });

    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        setState(() {
          _beeScale = 1.0;
        });
      }
    });
  }

  String formatNumber(int number) {
    if (number >= 1000000000) {
      return '${(number / 1000000000).toStringAsFixed(1)}B';
    } else if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    } else {
      return number.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.orangeAccent,
        title: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Text(
                  'Score: ${formatNumber(_score)}',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ),
              Row(
                children: [
                  const Icon(Icons.monetization_on, color: Colors.amber, size: 18),
                  const SizedBox(width: 4),
                  Text(
                    formatNumber(_tokenAmount),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: AppKitModalConnectButton(appKit: widget.appKitModal),
              ),
            ],
          ),
        ),
      ),
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: GestureDetector(
                  onTap: _onTap,
                  child: AnimatedScale(
                    scale: _beeScale,
                    duration: const Duration(milliseconds: 100),
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: Colors.pink.shade100,
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Text("🐝", style: TextStyle(fontSize: 32)),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 24.0, top: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ShopScreen(
                            tokenAmount: _tokenAmount,
                            onColorSelected: (Color newColor) {
                              setState(() => backgroundColor = newColor);
                            },
                            appKit: widget.appKit,
                            appKitModal: widget.appKitModal,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.storefront),
                    label: const Text('Shop'),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => UpgradeScreen(tokenAmount: _tokenAmount),
                        ),
                      );
                    },
                    icon: const Icon(Icons.upgrade),
                    label: const Text('Upgrade'),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      // TODO: تحويل السكور إلى توكن
                    },
                    icon: const Icon(Icons.sync_alt),
                    label: const Text('Transfer'),
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}
