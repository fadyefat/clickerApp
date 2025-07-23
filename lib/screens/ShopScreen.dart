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
  String? errorMessage;
  late DeployedContract deployedContract;
  late DeployedContract beeTokenDeployedContract;

  @override
  void initState() {
    super.initState();
    _loadAbiAndNFTs();
  }

  // Fixed price conversion function
  double _convertWeiToTokens(BigInt weiAmount) {
    if (weiAmount == BigInt.zero) return 0.0;

    // Convert BigInt to double more accurately
    // For 18 decimals: divide by 10^18
    final divisor = BigInt.from(10).pow(18);
    final wholePart = weiAmount ~/ divisor;
    final fractionalPart = weiAmount % divisor;

    // Convert fractional part to double
    final fractionalAsDouble = fractionalPart.toDouble() / divisor.toDouble();

    return wholePart.toDouble() + fractionalAsDouble;
  }

  Future<void> _loadAbiAndNFTs() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      if (widget.appKitModal.session == null) {
        setState(() {
          isLoading = false;
          errorMessage = 'Please connect your wallet first';
        });
        return;
      }

      // Load NFT Contract ABI
      String nftAbiString;
      try {
        nftAbiString = await rootBundle.loadString('lib/assets/ABI/ClickerNft.json');
      } catch (e) {
        print('Failed to load NFT ABI from file, using fallback: $e');
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
        print('Failed to load BEE Token ABI from file, using fallback: $e');
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
      try {
        if (nftAbiString.startsWith('[')) {
          nftAbiJson = json.decode(nftAbiString);
        } else {
          final abiData = json.decode(nftAbiString);
          nftAbiJson = abiData is List ? abiData : abiData['abi'] ?? abiData;
        }
      } catch (e) {
        throw Exception('Failed to parse NFT ABI: $e');
      }

      List<dynamic> beeTokenAbiJson;
      try {
        if (beeTokenAbiString.startsWith('[')) {
          beeTokenAbiJson = json.decode(beeTokenAbiString);
        } else {
          final abiData = json.decode(beeTokenAbiString);
          beeTokenAbiJson = abiData is List ? abiData : abiData['abi'] ?? abiData;
        }
      } catch (e) {
        throw Exception('Failed to parse BEE Token ABI: $e');
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

      if (totalRes.isEmpty) {
        throw Exception('Failed to get TOTAL_TYPES from contract');
      }

      final rawTotal = totalRes.first;
      int total;

      if (rawTotal is BigInt) {
        total = rawTotal.toInt();
      } else if (rawTotal is int) {
        total = rawTotal;
      } else {
        final parsed = int.tryParse(rawTotal.toString());
        if (parsed == null) {
          throw Exception('Invalid TOTAL_TYPES value: $rawTotal');
        }
        total = parsed;
      }

      print('Total NFT types: $total');

      if (total <= 0) {
        setState(() {
          nfts = [];
          isLoading = false;
        });
        return;
      }

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

          print('NFT Type $i response length: ${nftTypeRes.length}');

          if (nftTypeRes.isEmpty) {
            throw Exception('Empty nftTypes response for type $i');
          }

          String uri = '';
          BigInt priceInWei = BigInt.zero;

          // Extract URI
          if (nftTypeRes.isNotEmpty && nftTypeRes[0] != null) {
            uri = nftTypeRes[0].toString();
          }

          // Extract price with improved parsing
          if (nftTypeRes.length > 1 && nftTypeRes[1] != null) {
            final rawPrice = nftTypeRes[1];
            try {
              if (rawPrice is BigInt) {
                priceInWei = rawPrice;
              } else if (rawPrice is int) {
                priceInWei = BigInt.from(rawPrice);
              } else if (rawPrice is String) {
                if (rawPrice.startsWith('0x')) {
                  priceInWei = BigInt.parse(rawPrice.substring(2), radix: 16);
                } else {
                  priceInWei = BigInt.tryParse(rawPrice) ?? BigInt.zero;
                }
              } else {
                final priceStr = rawPrice.toString();
                if (priceStr.startsWith('0x')) {
                  priceInWei = BigInt.parse(priceStr.substring(2), radix: 16);
                } else {
                  priceInWei = BigInt.tryParse(priceStr) ?? BigInt.zero;
                }
              }
            } catch (e) {
              print('Error parsing price for NFT $i: $e, rawPrice: $rawPrice');
              priceInWei = BigInt.zero;
            }
          }

          // Convert price using fixed function
          double priceInTokens = _convertWeiToTokens(priceInWei);

          print('NFT $i - URI: $uri, Price: $priceInTokens BEE (${priceInWei} wei)');

          // Handle metadata fetching
          Map<String, dynamic> nftData = {
            'name': 'NFT Type $i',
            'description': 'NFT Type $i',
            'image': 'https://via.placeholder.com/300x300?text=NFT+$i',
            'typeId': i,
            'price': priceInTokens,
            'priceInWei': priceInWei,
            'originalUri': uri,
            'attributes': [
              {'trait_type': 'Type', 'value': i},
              {'trait_type': 'Price', 'value': '${priceInTokens.toStringAsFixed(4)} BEE'}
            ]
          };

          if (uri.isNotEmpty) {
            String imageUrl = uri;
            if (uri.startsWith('ipfs://')) {
              imageUrl = uri.replaceFirst("ipfs://", "https://ipfs.io/ipfs/");
            } else if (uri.startsWith('Qm') && uri.length == 46) {
              imageUrl = "https://ipfs.io/ipfs/$uri";
            }

            try {
              final res = await http.get(
                Uri.parse(imageUrl),
                headers: {'Accept': 'application/json'},
              ).timeout(const Duration(seconds: 10));

              if (res.statusCode == 200) {
                try {
                  final jsonData = json.decode(res.body);

                  String finalImageUrl = jsonData['image'] ?? imageUrl;
                  if (finalImageUrl.startsWith('ipfs://')) {
                    finalImageUrl = finalImageUrl.replaceFirst("ipfs://", "https://ipfs.io/ipfs/");
                  } else if (finalImageUrl.startsWith('Qm') && finalImageUrl.length == 46) {
                    finalImageUrl = "https://ipfs.io/ipfs/$finalImageUrl";
                  }

                  nftData.addAll({
                    'name': jsonData['name'] ?? 'NFT Type $i',
                    'description': jsonData['description'] ?? 'NFT Type $i',
                    'image': finalImageUrl,
                    'attributes': (jsonData['attributes'] as List?)?.cast<Map<String, dynamic>>() ?? nftData['attributes'],
                  });
                } catch (e) {
                  print('Failed to parse JSON for NFT $i: $e');
                }
              }
            } catch (e) {
              print('Failed to fetch metadata for NFT $i: $e');
            }
          }

          loadedNFTs.add(nftData);
        } catch (e) {
          print('Error loading NFT type $i: $e');
          // Add placeholder for failed NFTs
          loadedNFTs.add({
            'name': 'NFT Type $i',
            'description': 'Failed to load data',
            'image': 'https://via.placeholder.com/300x300?text=Error+Loading+NFT+$i',
            'typeId': i,
            'price': 0.0,
            'priceInWei': BigInt.zero,
            'originalUri': '',
            'attributes': [
              {'trait_type': 'Type', 'value': i},
              {'trait_type': 'Status', 'value': 'Load Error'}
            ]
          });
        }
      }

      if (mounted) {
        setState(() {
          nfts = loadedNFTs;
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error in _loadAbiAndNFTs: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
          errorMessage = 'Failed to load NFTs: ${e.toString()}';
        });
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

      if (!mounted) return;

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

      try {
        // Check allowance
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

        // Approve if needed
        if (currentAllowance < priceInWei) {
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
        }

        // Buy NFT
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

        _loadAbiAndNFTs();
      } catch (e) {
        if (mounted) Navigator.pop(context);
        throw e;
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);

      String errorMessage = 'Purchase failed: ${e.toString()}';
      if (e.toString().contains('insufficient')) {
        errorMessage = 'Insufficient BEE tokens to complete purchase';
      } else if (e.toString().contains('rejected')) {
        errorMessage = 'Transaction rejected by user';
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Calculate available height and distribute space
          final availableHeight = constraints.maxHeight;
          final imageHeight = availableHeight * 0.6; // 60% for image
          final contentHeight = availableHeight * 0.4; // 40% for content

          return Padding(
            padding: const EdgeInsets.all(6.0), // Reduced padding
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Image section with calculated height
                SizedBox(
                  height: imageHeight,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      nft['image'] ?? 'https://via.placeholder.com/300x300?text=No+Image',
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: Colors.grey[200],
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error_outline, size: 10, color: Colors.grey),

                            Text('Image Error', style: TextStyle(color: Colors.grey, fontSize: 8)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                // Content section with calculated height
                Padding(
                  padding: const EdgeInsets.only(top: 2.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Text content - flexible to take available space
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            nft['name'] ?? 'NFT #${nft['typeId']}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${price.toStringAsFixed(price < 1 ? 4 : 2)} BEE',
                            style: TextStyle(
                              color: canAfford ? Colors.green : Colors.red,
                              fontWeight: FontWeight.w600,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                      // Button - fixed at bottom
                      SizedBox(
                        width: double.infinity,
                        height: 25, // Reduced button height
                        child: ElevatedButton(
                          onPressed: canAfford ? () => _buyNFT(nft) : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: canAfford ? Colors.orange : Colors.grey,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 1),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),

                          ),
                          child: Text(
                            canAfford ? 'Buy NFT' : 'Low BEE',
                            style: const TextStyle(fontSize: 9),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
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
            : errorMessage != null
            ? Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                errorMessage!,
                style: const TextStyle(fontSize: 16, color: Colors.red),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadAbiAndNFTs,
                child: const Text('Retry'),
              ),
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
            childAspectRatio: 0.8, // Adjusted for better proportions
          ),
          itemCount: nfts.length,
          itemBuilder: (context, index) => _buildNFTCard(nfts[index]),
        ),
      ),
    );
  }
}