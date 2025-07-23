import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:reown_appkit/reown_appkit.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
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

  // Add GlobalKey for screenshot
  final GlobalKey _screenshotKey = GlobalKey();

  // Upgrade system
  Map<String, int> _ownedAbilities = {
    'double_tap': 0,      // +1 extra point per tap
    'power_click': 0,     // +2 extra points per tap
    'mega_boost': 0,      // +5 extra points per tap
    'auto_clicker': 0,    // +10 points per second (passive)
  };

  Timer? _autoClickTimer;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  String? _walletAddress;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _setupWalletListener();
    _loadWalletInfo();
    _loadGameData(); // Load saved data first
    _startAutoClicker();
  }

  // Load game data from SharedPreferences
  Future<void> _loadGameData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      setState(() {
        // Load score and tokens
        _score = prefs.getInt('game_score') ?? 0;
        _tokenAmount = prefs.getInt('game_tokens') ?? 0;

        // Load abilities
        _ownedAbilities['double_tap'] = prefs.getInt('ability_double_tap') ?? 0;
        _ownedAbilities['power_click'] = prefs.getInt('ability_power_click') ?? 0;
        _ownedAbilities['mega_boost'] = prefs.getInt('ability_mega_boost') ?? 0;
        _ownedAbilities['auto_clicker'] = prefs.getInt('ability_auto_clicker') ?? 0;

        // Load background color
        final colorValue = prefs.getInt('background_color');
        if (colorValue != null) {
          backgroundColor = Color(colorValue);
        }
      });

      print('Game data loaded successfully');
    } catch (e) {
      print('Error loading game data: $e');
    }
  }

  // Save game data to SharedPreferences
  Future<void> _saveGameData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Save score and tokens
      await prefs.setInt('game_score', _score);
      await prefs.setInt('game_tokens', _tokenAmount);

      // Save abilities
      await prefs.setInt('ability_double_tap', _ownedAbilities['double_tap'] ?? 0);
      await prefs.setInt('ability_power_click', _ownedAbilities['power_click'] ?? 0);
      await prefs.setInt('ability_mega_boost', _ownedAbilities['mega_boost'] ?? 0);
      await prefs.setInt('ability_auto_clicker', _ownedAbilities['auto_clicker'] ?? 0);

      // Save background color
      await prefs.setInt('background_color', backgroundColor.value);

      print('Game data saved successfully');
    } catch (e) {
      print('Error saving game data: $e');
    }
  }

  // Reset game data (optional - for testing or reset functionality)
  Future<void> _resetGameData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear(); // This clears all SharedPreferences data

      setState(() {
        _score = 0;
        _tokenAmount = 0;
        _ownedAbilities = {
          'double_tap': 0,
          'power_click': 0,
          'mega_boost': 0,
          'auto_clicker': 0,
        };
        backgroundColor = Colors.white;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Game data reset successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Error resetting game data: $e');
    }
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

  void _startAutoClicker() {
    _autoClickTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final int autoClickerLevel = _ownedAbilities['auto_clicker'] ?? 0;
      if (autoClickerLevel > 0 && mounted) {
        setState(() {
          final int autoPoints = autoClickerLevel * 10;
          _score += autoPoints;
          _tokenAmount = (_score * 0.1).round();
        });
        _saveGameData(); // Save after auto-click
      }
    });
  }

  void _onTap() {
    // Calculate total points per tap
    int basePoints = 1;
    int bonusPoints = 0;

    bonusPoints += (_ownedAbilities['double_tap'] ?? 0) * 1;
    bonusPoints += (_ownedAbilities['power_click'] ?? 0) * 2;
    bonusPoints += (_ownedAbilities['mega_boost'] ?? 0) * 5;

    final int totalPoints = basePoints + bonusPoints;

    setState(() {
      _score += totalPoints;
      _tokenAmount = (_score * 0.1).round();
    });

    // Save game data after each tap
    _saveGameData();

    _animationController.forward().then((_) {
      _animationController.reverse();
    });

    // Show floating text for bonus points if any
    if (bonusPoints > 0) {
      _showFloatingText('+$totalPoints');
    }
  }

  void _showFloatingText(String text) {
    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => AnimatedPositioned(
        duration: const Duration(milliseconds: 1000),
        top: MediaQuery.of(context).size.height * 0.3,
        left: MediaQuery.of(context).size.width * 0.5 - 30,
        child: IgnorePointer(
          child: AnimatedOpacity(
            opacity: 0.0,
            duration: const Duration(milliseconds: 1000),
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.green,
                shadows: [
                  Shadow(
                    offset: Offset(1.0, 1.0),
                    blurRadius: 3.0,
                    color: Colors.black54,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(overlayEntry);

    Timer(const Duration(milliseconds: 1000), () {
      overlayEntry.remove();
    });
  }

  void _onAbilityPurchased(int newScore, Map<String, int> abilities) {
    setState(() {
      _score = newScore;
      _ownedAbilities = Map.from(abilities);
      _tokenAmount = (_score * 0.1).round();
    });
    _saveGameData(); // Save after purchase
  }

  // Handle color change from shop
  void _onColorChanged(Color newColor) {
    setState(() {
      backgroundColor = newColor;
    });
    _saveGameData(); // Save color change
  }

  // New method to capture screenshot
  Future<Uint8List?> _captureScreenshot() async {
    try {
      RenderRepaintBoundary boundary = _screenshotKey.currentContext!
          .findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      print('Error capturing screenshot: $e');
      return null;
    }
  }

  // New method to handle Buy Bee functionality
  Future<void> _buyBee() async {
    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return const AlertDialog(
            content: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 20),
                Flexible(
                  child: Text("Taking screenshot and preparing email..."),
                ),
              ],
            ),
          );
        },
      );

      // Capture screenshot
      Uint8List? screenshot = await _captureScreenshot();

      // Close loading dialog
      Navigator.of(context).pop();

      if (screenshot != null) {
        // Save screenshot temporarily
        final directory = await getExternalStorageDirectory();
        final file = File('${directory!.path}/game_screenshot.png');
        await file.writeAsBytes(screenshot);

        // Prepare email content (simplified for better URL handling)
        final String emailSubject = 'Bee Game Purchase Request';
        final String emailBody = 'Hello,\n\n'
            'New bee purchase request from game!\n\n'
            'Wallet: ${_walletAddress ?? 'Not connected'}\n'
            'Score: ${formatNumber(_score)}\n'
            'Tokens: ${formatNumber(_tokenAmount)}\n'
            'Date: ${DateTime.now().toLocal().toString().split('.')[0]}\n\n'
            'Game Stats:\n'
            'Double Tap: ${_ownedAbilities['double_tap'] ?? 0}\n'
            'Power Click: ${_ownedAbilities['power_click'] ?? 0}\n'
            'Mega Boost: ${_ownedAbilities['mega_boost'] ?? 0}\n'
            'Auto Clicker: ${_ownedAbilities['auto_clicker'] ?? 0}\n\n'
            'Screenshot saved to device.\n\n'
            'Best regards,\n'
            'Bee Game App';

        // Try different email approaches
        bool emailLaunched = false;

        // First try: Simple mailto
        try {
          final String mailtoUrl = 'mailto:randomitiesf2k@gmail.com'
              '?subject=${Uri.encodeComponent(emailSubject)}'
              '&body=${Uri.encodeComponent(emailBody)}';

          final Uri mailtoUri = Uri.parse(mailtoUrl);
          if (await canLaunchUrl(mailtoUri)) {
            await launchUrl(mailtoUri);
            emailLaunched = true;
          }
        } catch (e) {
          print('Mailto attempt failed: $e');
        }

        // Second try: Gmail web interface (simplified)
        if (!emailLaunched) {
          try {
            final String gmailUrl = 'https://mail.google.com/mail/u/0/#inbox?compose=new';
            final Uri gmailUri = Uri.parse(gmailUrl);
            if (await canLaunchUrl(gmailUri)) {
              await launchUrl(gmailUri, mode: LaunchMode.externalApplication);
              emailLaunched = true;
            }
          } catch (e) {
            print('Gmail web attempt failed: $e');
          }
        }

        if (emailLaunched) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Email app opened successfully!'),
                  const SizedBox(height: 4),
                  Text('Screenshot saved to: ${file.path}'),
                  const SizedBox(height: 4),
                  const Text('Please manually compose email with user details.'),
                ],
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 6),
            ),
          );
        } else {
          // Show user details dialog if email fails
          _showEmailFailureDialog(file.path);
        }

        // Show confirmation dialog with user info
        _showBuyBeeConfirmation();

      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to capture screenshot. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      Navigator.of(context).pop(); // Close loading dialog if open
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  // Show email failure dialog with user details
  void _showEmailFailureDialog(String screenshotPath) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('📧 Email Setup Needed'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Please manually send this information:'),
                const SizedBox(height: 12),
                const Text('User Details:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                SelectableText('Wallet: ${_walletAddress ?? 'Not connected'}'),
                SelectableText('Score: ${formatNumber(_score)}'),
                SelectableText('Tokens: ${formatNumber(_tokenAmount)}'),
                SelectableText('Date: ${DateTime.now().toLocal().toString().split('.')[0]}'),
                const SizedBox(height: 12),
                const Text('Screenshot saved at:', style: TextStyle(fontWeight: FontWeight.bold)),
                SelectableText(screenshotPath, style: const TextStyle(fontSize: 12)),
                const SizedBox(height: 12),
                const Text('Send to: randomitiesf2k@gmail.com',
                    style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Got it!'),
            ),
          ],
        );
      },
    );
  }

  // Show confirmation dialog after buy bee
  void _showBuyBeeConfirmation() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('🐝 Buy Bee Request Processed!'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Your bee purchase request has been processed!'),
              const SizedBox(height: 16),
              const Text('Your Information:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('Score: ${formatNumber(_score)}'),
              Text('Tokens: ${formatNumber(_tokenAmount)}'),
              Text('Wallet: ${_formatAddress(_walletAddress)}'),
              const SizedBox(height: 16),
              const Text('Screenshot saved to device successfully!',
                  style: TextStyle(color: Colors.green)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
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

  int _getTotalClickBonus() {
    int bonus = 0;
    bonus += (_ownedAbilities['double_tap'] ?? 0) * 1;
    bonus += (_ownedAbilities['power_click'] ?? 0) * 2;
    bonus += (_ownedAbilities['mega_boost'] ?? 0) * 5;
    return bonus;
  }

  @override
  void dispose() {
    _animationController.dispose();
    _autoClickTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final int clickBonus = _getTotalClickBonus();
    final int autoClickerLevel = _ownedAbilities['auto_clicker'] ?? 0;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.orangeAccent,
        elevation: 0,
        toolbarHeight: 60,
        titleSpacing: 8,
        title: Row(
          children: [
            // Score container - flexible and constrained
            Container(
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
            const SizedBox(width: 10),
            // Token container - flexible and constrained
            Flexible(
              flex: 3,
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
            height: 32,
            margin: const EdgeInsets.only(right: 8),
            child: FittedBox(
              child: AppKitModalConnectButton(appKit: widget.appKitModal),
            ),
          ),
          // Add reset button for testing (you can remove this in production)
          IconButton(
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Reset Game'),
                  content: const Text('Are you sure you want to reset all game data?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _resetGameData();
                      },
                      child: const Text('Reset', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );
            },
            icon: const Icon(Icons.refresh, color: Colors.white, size: 20),
          ),
        ],
      ),
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: RepaintBoundary(
          key: _screenshotKey,
          child: Column(
            children: [
              // Wallet info container
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

              // Stats display
              if (clickBonus > 0 || autoClickerLevel > 0)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      if (clickBonus > 0)
                        Column(
                          children: [
                            const Icon(Icons.touch_app, color: Colors.blue, size: 20),
                            Text(
                              '${1 + clickBonus}/tap',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      if (autoClickerLevel > 0)
                        Column(
                          children: [
                            const Icon(Icons.autorenew, color: Colors.green, size: 20),
                            Text(
                              '${autoClickerLevel * 10}/sec',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
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
                              child: Image.asset(
                                'lib/assets/images/ChatGPT Image Jul 22, 2025, 11_53_56 AM.png',
                                height: 250,
                                width: 250,
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
                child: Column(
                  children: [
                    // First row of buttons
                    Row(
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
                                  onColorSelected: _onColorChanged,
                                  appKit: widget.appKit,
                                  appKitModal: widget.appKitModal,
                                ),
                              ),
                            );
                            if (result != null) {
                              _onColorChanged(result);
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
                                  currentScore: _score,
                                  onPurchase: _onAbilityPurchased,
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Second row of buttons
                    Row(
                      children: [
                        _buildActionButton(
                          icon: Icons.sync_alt,
                          label: 'Transfer',
                          onPressed: _transferTokens,
                        ),
                        const SizedBox(width: 12),
                        _buildActionButton(
                          icon: Icons.pets,
                          label: 'Buy Bee',
                          color: Colors.amber,
                          onPressed: _walletAddress != null ? _buyBee : null,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    Color? color,
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
          backgroundColor: color ?? Colors.orange,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 4,
          // Disable button if no wallet connected (for Buy Bee only)
          disabledBackgroundColor: Colors.grey,
          disabledForegroundColor: Colors.white70,
        ),
      ),
    );
  }
}