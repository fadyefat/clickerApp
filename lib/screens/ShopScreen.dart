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
  final String nftContract = "0xf2aDc4ed82642F4cE376dcD50fE6aA58E09BE5Dd";
  final String beeTokenContract = "0x4DB8baC8A86d4D227eED02ab5339dee7Fa666382";

  List<Map<String, dynamic>> nfts = [];
  bool isLoading = true;
  late DeployedContract deployedContract;
  late DeployedContract beeTokenDeployedContract;

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

      // Load NFT Contract ABI
      String nftAbiString;
      try {
        nftAbiString = await rootBundle.loadString('lib/assets/ABI/ClickerNft.json');
      } catch (e) {
        // Fallback ABI based on your provided ABI
        nftAbiString = jsonEncode([
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
          },
          {
            "inputs": [{"internalType": "uint256", "name": "typeId", "type": "uint256"}],
            "name": "getNFTPrice",
            "outputs": [{"internalType": "uint256", "name": "", "type": "uint256"}],
            "stateMutability": "view",
            "type": "function"
          }
        ]);
      }

      // Load BEE Token ABI
      String beeTokenAbiString;
      try {
        beeTokenAbiString = await rootBundle.loadString('lib/assets/ABI/BeeToken.json');
      } catch (e) {
        // Fallback ABI based on your provided ABI
        beeTokenAbiString = jsonEncode([
          {
            "inputs": [
              {"internalType": "address", "name": "spender", "type": "address"},
              {"internalType": "uint256", "name": "amount", "type": "uint256"}
            ],
            "name": "approve",
            "outputs": [{"internalType": "bool", "name": "", "type": "bool"}],
            "stateMutability": "nonpayable",
            "type": "function"
          },
          {
            "inputs": [
              {"internalType": "address", "name": "owner", "type": "address"},
              {"internalType": "address", "name": "spender", "type": "address"}
            ],
            "name": "allowance",
            "outputs": [{"internalType": "uint256", "name": "", "type": "uint256"}],
            "stateMutability": "view",
            "type": "function"
          },
          {
            "inputs": [{"internalType": "address", "name": "account", "type": "address"}],
            "name": "balanceOf",
            "outputs": [{"internalType": "uint256", "name": "", "type": "uint256"}],
            "stateMutability": "view",
            "type": "function"
          }
        ]);
      }

      // Parse ABIs
      List<dynamic> nftAbiJson;
      if (nftAbiString.startsWith('[')) {
        nftAbiJson = json.decode(nftAbiString);
      } else {
        final abiData = json.decode(nftAbiString);
        nftAbiJson = abiData is List ? abiData : abiData['abi'] ?? abiData;
      }

      List<dynamic> beeTokenAbiJson;
      if (beeTokenAbiString.startsWith('[')) {
        beeTokenAbiJson = json.decode(beeTokenAbiString);
      } else {
        final abiData = json.decode(beeTokenAbiString);
        beeTokenAbiJson = abiData is List ? abiData : abiData['abi'] ?? abiData;
      }

      // Create deployed contracts
      deployedContract = DeployedContract(
        ContractAbi.fromJson(jsonEncode(nftAbiJson), "ClickerNFT"),
        EthereumAddress.fromHex(nftContract),
      );

      beeTokenDeployedContract = DeployedContract(
        ContractAbi.fromJson(jsonEncode(beeTokenAbiJson), "BeeToken"),
        EthereumAddress.fromHex(beeTokenContract),
      );

      // Get total NFT types
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

          // Convert price from wei to tokens (assuming 18 decimals)
          BigInt priceInWei = rawPrice is BigInt
              ? rawPrice
              : BigInt.tryParse(rawPrice.toString()) ?? BigInt.zero;

          double priceInTokens = priceInWei.toInt() / 1e18;

          print('NFT $i - URI: $uri, Price: $priceInTokens BEE');

          if (uri.isEmpty) {
            loadedNFTs.add({
              'name': 'NFT Type $i',
              'description': 'NFT Type $i',
              'image': 'https://via.placeholder.com/300x300?text=NFT+$i',
              'typeId': i,
              'price': priceInTokens,
              'priceInWei': priceInWei,
              'originalUri': uri,
              'attributes': [
                {'trait_type': 'Type', 'value': i},
                {'trait_type': 'Price', 'value': '$priceInTokens BEE'}
              ]
            });
            continue;
          }

          String imageUrl = uri;
          if (uri.startsWith('ipfs://')) {
            imageUrl = uri.replaceFirst("ipfs://", "https://ipfs.io/ipfs/");
          }

          try {
            final res = await http.get(Uri.parse(imageUrl))
                .timeout(const Duration(seconds: 10));

            if (res.statusCode == 200) {
              final jsonData = json.decode(res.body);

              List<dynamic> attributes = [];
              if (jsonData['attributes'] is List) {
                attributes = jsonData['attributes'];
              }

              String finalImageUrl = jsonData['image'] ?? imageUrl;
              if (finalImageUrl.startsWith('ipfs://')) {
                finalImageUrl = finalImageUrl.replaceFirst("ipfs://", "https://ipfs.io/ipfs/");
              }

              loadedNFTs.add({
                'name': jsonData['name'] ?? 'NFT Type $i',
                'description': jsonData['description'] ?? 'NFT Type $i',
                'image': finalImageUrl,
                'typeId': i,
                'price': priceInTokens,
                'priceInWei': priceInWei,
                'originalUri': uri,
                'attributes': attributes.isEmpty
                    ? [
                  {'trait_type': 'Type', 'value': i},
                  {'trait_type': 'Price', 'value': '$priceInTokens BEE'}
                ]
                    : [...attributes, {'trait_type': 'Price', 'value': '$priceInTokens BEE'}]
              });
            } else {
              throw Exception('HTTP ${res.statusCode}');
            }
          } catch (e) {
            print('Failed to fetch metadata for NFT $i: $e');
            loadedNFTs.add({
              'name': 'NFT Type $i',
              'description': 'Metadata unavailable',
              'image': imageUrl,
              'typeId': i,
              'price': priceInTokens,
              'priceInWei': priceInWei,
              'originalUri': uri,
              'attributes': [
                {'trait_type': 'Type', 'value': i},
                {'trait_type': 'Price', 'value': '$priceInTokens BEE'}
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
            'priceInWei': BigInt.zero,
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

  Future<void> _buyNFT(Map<String, dynamic> nft) async {
    try {
      final int typeId = nft['typeId'];
      final BigInt priceInWei = nft['priceInWei'] ?? BigInt.zero;

      if (priceInWei == BigInt.zero) {
        throw Exception("Invalid NFT price");
      }

      final userAddress = widget.appKitModal.session!.getAddress(
        ReownAppKitModalNetworks.getNamespaceForChainId(
          widget.appKitModal.selectedChain!.chainId,
        ),
      );

      if (userAddress == null) {
        throw Exception("User address not found");
      }

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

      // First, check if we need to approve the NFT contract to spend BEE tokens
      try {
        final allowanceRes = await widget.appKitModal.requestReadContract(
          topic: widget.appKitModal.session!.topic,
          chainId: widget.appKitModal.selectedChain!.chainId,
          deployedContract: beeTokenDeployedContract,
          functionName: 'allowance',
          parameters: [
            EthereumAddress.fromHex(userAddress),
            EthereumAddress.fromHex(nftContract),
          ],
        );

        final currentAllowance = allowanceRes.isNotEmpty
            ? (allowanceRes.first is BigInt ? allowanceRes.first : BigInt.tryParse(allowanceRes.first.toString()) ?? BigInt.zero)
            : BigInt.zero;

        print('Current allowance: $currentAllowance, Required: $priceInWei');

        // If allowance is insufficient, approve first
        if (currentAllowance < priceInWei) {
          print('Approving BEE tokens for NFT contract...');

          await widget.appKitModal.requestWriteContract(
            topic: widget.appKitModal.session!.topic,
            chainId: widget.appKitModal.selectedChain!.chainId,
            deployedContract: beeTokenDeployedContract,
            functionName: 'approve',
            transaction: Transaction(
              from: EthereumAddress.fromHex(userAddress),
            ),
            parameters: [
              EthereumAddress.fromHex(nftContract),
              priceInWei,
            ],
          );

          print('BEE tokens approved successfully');
        }

        // Now buy the NFT
        print('Buying NFT type $typeId...');

        final txHash = await widget.appKitModal.requestWriteContract(
          topic: widget.appKitModal.session!.topic,
          chainId: widget.appKitModal.selectedChain!.chainId,
          deployedContract: deployedContract,
          functionName: 'buyNFT',
          transaction: Transaction(
            from: EthereumAddress.fromHex(userAddress),
          ),
          parameters: [BigInt.from(typeId)],
        );

        if (mounted) Navigator.pop(context);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Successfully purchased ${nft['name']}!\nTx: ${txHash.toString().substring(0, 20)}...'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 4),
            ),
          );
        }

        // Refresh the NFT list
        _loadAbiAndNFTs();

      } catch (e) {
        if (mounted) Navigator.pop(context);
        throw e;
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);

      String errorMessage = 'Purchase failed: ${e.toString()}';

      // Provide more user-friendly error messages
      if (e.toString().contains('insufficient')) {
        errorMessage = 'Insufficient BEE tokens to complete purchase';
      } else if (e.toString().contains('rejected')) {
        errorMessage = 'Transaction rejected by user';
      } else if (e.toString().contains('allowance')) {
        errorMessage = 'Token approval failed. Please try again.';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ $errorMessage'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Widget _buildNFTCard(Map<String, dynamic> nft) {
    final double price = nft['price'] ?? 0.0;
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
                  nft['image'] ?? 'https://via.placeholder.com/300x300?text=No+Image',
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) =>
                      Container(
                        color: Colors.grey[200],
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error_outline, size: 40, color: Colors.grey),
                            Text('Image Error', style: TextStyle(color: Colors.grey)),
                          ],
                        ),
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
                    '${price.toStringAsFixed(price < 1 ? 4 : 2)} BEE',
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
                      onPressed: canAfford ? () => _buyNFT(nft) : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: canAfford ? Colors.orange : Colors.grey,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        canAfford ? 'Buy NFT' : 'Insufficient BEE',
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
              SizedBox(height: 8),
              Text(
                'Pull down to refresh',
                style: TextStyle(fontSize: 14, color: Colors.grey),
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