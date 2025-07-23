import 'package:flutter/material.dart';

class UpgradeScreen extends StatefulWidget {
  final int tokenAmount;
  final int currentScore;
  final Function(int newScore, Map<String, int> abilities)? onPurchase;

  const UpgradeScreen({
    super.key,
    required this.tokenAmount,
    required this.currentScore,
    this.onPurchase,
  });

  @override
  State<UpgradeScreen> createState() => _UpgradeScreenState();
}

class _UpgradeScreenState extends State<UpgradeScreen> {
  late int _currentScore;
  Map<String, int> _ownedAbilities = {
    'double_tap': 0,      // +1 extra point per tap
    'power_click': 0,     // +2 extra points per tap
    'mega_boost': 0,      // +5 extra points per tap
    'auto_clicker': 0,    // +10 points per second (passive)
  };

  final List<Map<String, dynamic>> _availableAbilities = [
    {
      'id': 'double_tap',
      'name': 'Double Tap',
      'description': 'Each tap gives +1 extra point',
      'basePrice': 100,
      'icon': Icons.touch_app,
      'color': Colors.blue,
      'maxLevel': 10,
    },
    {
      'id': 'power_click',
      'name': 'Power Click',
      'description': 'Each tap gives +2 extra points',
      'basePrice': 500,
      'icon': Icons.bolt,
      'color': Colors.orange,
      'maxLevel': 5,
    },
    {
      'id': 'mega_boost',
      'name': 'Mega Boost',
      'description': 'Each tap gives +5 extra points',
      'basePrice': 2000,
      'icon': Icons.rocket_launch,
      'color': Colors.red,
      'maxLevel': 3,
    },
    {
      'id': 'auto_clicker',
      'name': 'Auto Clicker',
      'description': 'Automatically generates +10 points per second',
      'basePrice': 5000,
      'icon': Icons.autorenew,
      'color': Colors.green,
      'maxLevel': 2,
    },
  ];

  @override
  void initState() {
    super.initState();
    _currentScore = widget.currentScore;
  }

  int _getAbilityPrice(Map<String, dynamic> ability) {
    final String abilityId = ability['id'];
    final int currentLevel = _ownedAbilities[abilityId] ?? 0;
    final int basePrice = ability['basePrice'];

    // Price increases exponentially with each level
    return (basePrice * (1.5 * (currentLevel + 1))).round();
  }

  int _getTotalClickBonus() {
    int bonus = 0;
    bonus += (_ownedAbilities['double_tap'] ?? 0) * 1;
    bonus += (_ownedAbilities['power_click'] ?? 0) * 2;
    bonus += (_ownedAbilities['mega_boost'] ?? 0) * 5;
    return bonus;
  }

  void _purchaseAbility(Map<String, dynamic> ability) {
    final String abilityId = ability['id'];
    final int currentLevel = _ownedAbilities[abilityId] ?? 0;
    final int maxLevel = ability['maxLevel'];
    final int price = _getAbilityPrice(ability);

    if (currentLevel >= maxLevel) {
      _showMessage('${ability['name']} is already at maximum level!', Colors.orange);
      return;
    }

    if (_currentScore < price) {
      _showMessage('Not enough score to purchase ${ability['name']}!', Colors.red);
      return;
    }

    setState(() {
      _currentScore -= price;
      _ownedAbilities[abilityId] = currentLevel + 1;
    });

    // Notify parent widget about the purchase
    if (widget.onPurchase != null) {
      widget.onPurchase!(_currentScore, Map.from(_ownedAbilities));
    }

    _showMessage('${ability['name']} upgraded to level ${currentLevel + 1}!', Colors.green);
  }

  void _showMessage(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _buildAbilityCard(Map<String, dynamic> ability) {
    final String abilityId = ability['id'];
    final int currentLevel = _ownedAbilities[abilityId] ?? 0;
    final int maxLevel = ability['maxLevel'];
    final int price = _getAbilityPrice(ability);
    final bool canAfford = _currentScore >= price;
    final bool isMaxLevel = currentLevel >= maxLevel;

    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              ability['color'].withOpacity(0.1),
              ability['color'].withOpacity(0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: ability['color'].withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      ability['icon'],
                      color: ability['color'],
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ability['name'],
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          ability['description'],
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Level: $currentLevel/$maxLevel',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      if (!isMaxLevel)
                        Text(
                          'Cost: $price points',
                          style: TextStyle(
                            color: canAfford ? Colors.green : Colors.red,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                  ElevatedButton(
                    onPressed: isMaxLevel ? null : (canAfford ? () => _purchaseAbility(ability) : null),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isMaxLevel
                          ? Colors.grey
                          : (canAfford ? ability['color'] : Colors.grey[400]),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      isMaxLevel ? 'MAX' : (canAfford ? 'BUY' : 'Too Expensive'),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              if (currentLevel > 0) ...[
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: currentLevel / maxLevel,
                  backgroundColor: Colors.grey[300],
                  valueColor: AlwaysStoppedAnimation(ability['color']),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final int clickBonus = _getTotalClickBonus();
    final int autoClickerLevel = _ownedAbilities['auto_clicker'] ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Upgrades'),
        backgroundColor: Colors.orangeAccent,
        foregroundColor: Colors.white,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Row(
              children: [
                const Icon(Icons.star, color: Colors.amber),
                const SizedBox(width: 4),
                Text(
                  '$_currentScore',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Stats Card
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    colors: [
                      Colors.blue.withOpacity(0.1),
                      Colors.purple.withOpacity(0.1),
                    ],
                  ),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Your Current Stats',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildStatItem(
                          'Points per Tap',
                          '${1 + clickBonus}',
                          Icons.touch_app,
                          Colors.blue,
                        ),
                        _buildStatItem(
                          'Auto Points/sec',
                          '${autoClickerLevel * 10}',
                          Icons.autorenew,
                          Colors.green,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Available Upgrades',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ..._availableAbilities.map((ability) => _buildAbilityCard(ability)),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}