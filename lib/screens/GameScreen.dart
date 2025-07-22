import 'dart:async';
import 'package:flutter/material.dart';
import 'package:reown_appkit/reown_appkit.dart';
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
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  int _score = 0;
  int _tokenAmount = 0;
  double _beeScale = 1.0;
  Color backgroundColor = Colors.white;

  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  String? _walletAddress;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _setupWalletListener();
    _loadWalletInfo();
  }

  void _initAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.85,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  void _setupWalletListener() {
    widget.appKitModal.onModalDisconnect.subscribe((ModalDisconnect? event) {
      if (mounted && event != null) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    });
  }

  Future<void> _loadWalletInfo() async {
    try {
      final session = widget.appKitModal.session;
      if (session != null) {
        final address = session.getAddress(
          ReownAppKitModalNetworks.getNamespaceForChainId(
            widget.appKitModal.selectedChain?.chainId ?? 'eip155:1',
          ),
        );
        if (mounted) {
          setState(() {
            _walletAddress = address;
          });
        }
      }
    } catch (e) {
      print('Error loading wallet info: $e');
    }
  }

  void _onTap() {
    setState(() {
      _score += 1;
      _tokenAmount = (_score * 0.1).round();
    });

    _animationController.forward().then((_) {
      _animationController.reverse();
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

  String _formatAddress(String? address) {
    if (address == null || address.length < 10) return 'Not connected';
    return '${address.substring(0, 6)}...${address.substring(address.length - 4)}';
  }

  Future<void> _transferTokens() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Token transfer functionality will be implemented soon!'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.orangeAccent,
        elevation: 0,
        toolbarHeight: 60,
        titleSpacing: 8,
        title: Row(
          children: [
            // Score container - flexible and constrained
            Flexible(
              flex: 2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  'Score: ${formatNumber(_score)}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            const SizedBox(width: 6),
            // Token container - flexible and constrained
            Flexible(
              flex: 2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.monetization_on, color: Colors.orange, size: 16),
                    const SizedBox(width: 2),
                    Flexible(
                      child: Text(
                        formatNumber(_tokenAmount),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          // Wallet button with fixed width to prevent overflow
          Container(
            width: 100,
            height: 32, // تصغير الارتفاع
            margin: const EdgeInsets.only(right: 8),
            child: FittedBox( // لتصغير حجم الزر والمحتوى تلقائيًا
              child: AppKitModalConnectButton(appKit: widget.appKitModal),
            ),
          ),
        ],
      ),
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.95),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Wallet Address:',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _formatAddress(_walletAddress),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: GestureDetector(
                  onTap: _onTap,
                  child: AnimatedBuilder(
                    animation: _scaleAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _scaleAnimation.value,
                        child: Container(
                          width: 150,
                          height: 150,
                          decoration: BoxDecoration(
                            gradient: RadialGradient(
                              colors: [
                                Colors.yellow.shade200,
                                Colors.orange.shade300,
                              ],
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.orange.withOpacity(0.4),
                                blurRadius: 20,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: Center(
                            child:  Image.asset(
                              'ChatGPT Image Jul 22, 2025, 11_53_56 AM.png',
                              height: 30,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: Row(
                children: [
                  _buildActionButton(
                    icon: Icons.storefront,
                    label: 'Shop',
                    onPressed: () async {
                      final result = await Navigator.push<Color>(
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
                      if (result != null) {
                        setState(() => backgroundColor = result);
                      }
                    },
                  ),
                  const SizedBox(width: 12),
                  _buildActionButton(
                    icon: Icons.upgrade,
                    label: 'Upgrade',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => UpgradeScreen(
                            tokenAmount: _tokenAmount,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 12),
                  _buildActionButton(
                    icon: Icons.sync_alt,
                    label: 'Transfer',
                    onPressed: _transferTokens,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return Expanded(
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        label: Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.orange,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 4,
        ),
      ),
    );
  }
}