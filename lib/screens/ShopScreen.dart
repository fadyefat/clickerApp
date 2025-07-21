// ... [All your existing imports]
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:reown_appkit/modal/i_appkit_modal_impl.dart';
import 'package:reown_appkit/reown_appkit.dart';
import 'package:web3dart/web3dart.dart';

class ShopScreen extends StatefulWidget {
  final ReownAppKit appKit;
  final int tokenAmount;
  final Function(Color newColor) onColorSelected;
  final IReownAppKitModal appKitModal;

  const ShopScreen({
    super.key,
    required this.appKit,
    required this.tokenAmount,
    required this.onColorSelected,
    required this.appKitModal,
  });

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  final String nftContract = "0x03851Ad34BA72acC9d7564511a071c55a83F35aF";

  List<Map<String, dynamic>> nfts = [];
  bool isLoading = true;
  late DeployedContract deployedContract;

  @override
  void initState() {
    super.initState();
    _loadAbiAndNFTs();
  }

  Future<void> _loadAbiAndNFTs() async {
    try {
      setState(() => isLoading = true);

      if (widget.appKitModal.session == null) {
        setState(() => isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('❌ Please connect your wallet first')),
          );
        }
        return;
      }

      String abiString;
      try {
        abiString = await rootBundle.loadString('lib/assets/ABI/ClickerNft.json');
      } catch (e) {
        abiString = jsonEncode({
          "abi": [
            {
              "inputs": [],
              "name": "TOTAL_TYPES",
              "outputs": [{"internalType": "uint256", "name": "", "type": "uint256"}],
              "stateMutability": "view",
              "type": "function"
            },
            {
              "inputs": [{"internalType": "uint256", "name": "", "type": "uint256"}],
              "name": "nftTypes",
              "outputs": [
                {"internalType": "string", "name": "uri", "type": "string"},
                {"internalType": "uint256", "name": "price", "type": "uint256"},
                {"components": [{"internalType": "uint256", "name": "_value", "type": "uint256"}], "internalType": "struct Counters.Counter", "name": "minted", "type": "tuple"}
              ],
              "stateMutability": "view",
              "type": "function"
            },
            {
              "inputs": [{"internalType": "uint256", "name": "typeId", "type": "uint256"}],
              "name": "buyNFT",
              "outputs": [],
              "stateMutability": "nonpayable",
              "type": "function"
            }
          ]
        });
      }

      final abiJson = json.decode(abiString);
      final abiCode = jsonEncode(abiJson['abi']);

      deployedContract = DeployedContract(
        ContractAbi.fromJson(abiCode, "ClickerNFT"),
        EthereumAddress.fromHex(nftContract),
      );

      final totalRes = await widget.appKitModal.requestReadContract(
        topic: widget.appKitModal.session!.topic,
        chainId: widget.appKitModal.selectedChain!.chainId,
        deployedContract: deployedContract,
        functionName: 'TOTAL_TYPES',
      );

      final rawTotal = totalRes.isNotEmpty ? totalRes.first : BigInt.zero;
      final total = rawTotal is BigInt ? rawTotal.toInt() : int.tryParse(rawTotal.toString()) ?? 0;

      print('Total NFT types: $total');

      List<Map<String, dynamic>> loadedNFTs = [];

      for (int i = 0; i < total; i++) {
        try {
          print('Loading NFT type $i...');

          final nftTypeRes = await widget.appKitModal.requestReadContract(
            topic: widget.appKitModal.session!.topic,
            chainId: widget.appKitModal.selectedChain!.chainId,
            deployedContract: deployedContract,
            functionName: 'nftTypes',
            parameters: [BigInt.from(i)],
          );

          print('NFT Type $i response: $nftTypeRes');

          if (nftTypeRes.isEmpty || nftTypeRes.length < 2) {
            throw Exception('Invalid nftTypes response');
          }

          final uri = nftTypeRes[0]?.toString() ?? '';
          final rawPrice = nftTypeRes[1];
          final priceInTokens = rawPrice is BigInt
              ? rawPrice.toInt()
              : rawPrice is int
              ? rawPrice
              : int.tryParse(rawPrice.toString()) ?? 0;

          print('NFT $i - URI: $uri, Price: $priceInTokens');

          if (uri.isEmpty) {
            loadedNFTs.add({
              'name': 'NFT Type $i',
              'description': 'NFT Type $i',
              'image': 'https://via.placeholder.com/300x300?text=NFT+$i',
              'typeId': i,
              'price': priceInTokens,
              'originalUri': uri,
              'attributes': [
                {'trait_type': 'Type', 'value': i},
                {'trait_type': 'Price', 'value': priceInTokens}
              ]
            });
            continue;
          }

          final ipfsUri = uri.startsWith('ipfs://')
              ? uri.replaceFirst("ipfs://", "https://ipfs.io/ipfs/")
              : uri;

          try {
            final res = await http.get(Uri.parse(ipfsUri))
                .timeout(const Duration(seconds: 10));

            if (res.statusCode == 200) {
              final jsonData = json.decode(res.body);

              List<dynamic> attributes = [];
              if (jsonData['attributes'] is List) {
                attributes = jsonData['attributes'];
              }

              loadedNFTs.add({
                'name': jsonData['name'] ?? 'NFT Type $i',
                'description': jsonData['description'] ?? 'NFT Type $i',
                'image': jsonData['image'] ?? 'https://via.placeholder.com/300x300?text=NFT+$i',
                'typeId': i,
                'price': priceInTokens,
                'originalUri': uri,
                'attributes': attributes.isEmpty
                    ? [
                  {'trait_type': 'Type', 'value': i},
                  {'trait_type': 'Price', 'value': priceInTokens}
                ]
                    : [...attributes, {'trait_type': 'Price', 'value': priceInTokens}]
              });
            } else {
              throw Exception('HTTP ${res.statusCode}');
            }
          } catch (e) {
            print('Failed to fetch metadata for NFT $i: $e');
            loadedNFTs.add({
              'name': 'NFT Type $i',
              'description': 'Metadata unavailable',
              'image': 'https://via.placeholder.com/300x300?text=NFT+$i',
              'typeId': i,
              'price': priceInTokens,
              'originalUri': uri,
              'attributes': [
                {'trait_type': 'Type', 'value': i},
                {'trait_type': 'Price', 'value': priceInTokens}
              ]
            });
          }
        } catch (e) {
          print('Error loading NFT type $i: $e');
          loadedNFTs.add({
            'name': 'NFT Type $i',
            'description': 'Failed to load',
            'image': 'https://via.placeholder.com/300x300?text=Error',
            'typeId': i,
            'price': 0,
            'attributes': [
              {'trait_type': 'Type', 'value': i},
              {'trait_type': 'Error', 'value': 'Failed to load'}
            ]
          });
        }
      }

      print('Loaded ${loadedNFTs.length} NFTs');

      setState(() {
        nfts = loadedNFTs;
        isLoading = false;
      });
    } catch (e) {
      print('Error in _loadAbiAndNFTs: $e');
      setState(() => isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Failed to load NFTs: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _buyNFT(dynamic typeId) async {
    try {
      final int parsedTypeId = typeId is int ? typeId : int.tryParse(typeId.toString()) ?? -1;
      if (parsedTypeId < 0) throw Exception("Invalid typeId: $typeId");

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Processing purchase...'),
            ],
          ),
        ),
      );

      final txHash = await widget.appKitModal.requestWriteContract(
        topic: widget.appKitModal.session!.topic,
        chainId: widget.appKitModal.selectedChain!.chainId,
        deployedContract: deployedContract,
        functionName: 'buyNFT',
        transaction: Transaction(
          from: EthereumAddress.fromHex(
            widget.appKitModal.session!.getAddress(
              ReownAppKitModalNetworks.getNamespaceForChainId(
                widget.appKitModal.selectedChain!.chainId,
              ),
            )!,
          ),
        ),
        parameters: [BigInt.from(parsedTypeId)],
      );

      if (mounted) Navigator.pop(context);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Successfully purchased NFT #$parsedTypeId!\nTx: ${txHash.toString().substring(0, 20)}...'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Purchase failed: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Widget _buildNFTCard(Map<String, dynamic> nft) {
    final price = nft['price'] ?? 0;
    final canAfford = widget.tokenAmount >= price;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 3,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  nft['image']?.toString().replaceFirst("ipfs://", "https://ipfs.io/ipfs/")
                      ?? 'https://via.placeholder.com/300x300?text=No+Image',
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const Center(child: CircularProgressIndicator());
                  },
                  errorBuilder: (context, error, stackTrace) =>
                      Container(
                        color: Colors.grey[200],
                        child: const Icon(Icons.error, size: 50),
                      ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nft['name'] ?? 'NFT #${nft['typeId']}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$price BEE',
                    style: TextStyle(
                      color: canAfford ? Colors.green : Colors.red,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: canAfford ? () => _buyNFT(nft['typeId']) : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: canAfford ? Colors.orange : Colors.grey,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        canAfford ? 'Buy' : 'Insufficient BEE',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("NFT Marketplace"),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Row(
              children: [
                const Icon(Icons.token, color: Colors.amber),
                const SizedBox(width: 4),
                Text(
                  "${widget.tokenAmount} BEE",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          )
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadAbiAndNFTs,
        child: isLoading
            ? const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading NFT marketplace...'),
            ],
          ),
        )
            : nfts.isEmpty
            ? const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.store_mall_directory, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'No NFTs available',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            ],
          ),
        )
            : GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.7,
          ),
          itemCount: nfts.length,
          itemBuilder: (context, index) => _buildNFTCard(nfts[index]),
        ),
      ),
    );
  }
}
