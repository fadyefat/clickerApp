import 'package:flutter/material.dart';

class UpgradeScreen extends StatelessWidget {
  final int tokenAmount;

  const UpgradeScreen({required this.tokenAmount});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Upgrades'),
        backgroundColor: Colors.orangeAccent,
        actions: [
          Row(
            children: [
              Icon(Icons.monetization_on, color: Colors.amber),
              SizedBox(width: 4),
              Text('$tokenAmount',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              SizedBox(width: 12),
            ],
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('NFT Boosters',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            SizedBox(height: 16),
            Container(
              height: 150,
              width: double.infinity,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  'Your future NFT boosters will appear here.\nThey will increase your points per tap.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
