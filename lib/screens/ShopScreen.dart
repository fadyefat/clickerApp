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
  final String nftContract = "0xf2adc4ed82642f4ce376dcd50fe6aa58e09be5dd";
  final String baseCID = "bafybeicxbw3kjieiv7xs52w5xzkrslplr25rqzylvkzqr6mc32omu5jzxa";

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

      // Load ABI
      final abiString = await rootBundle.loadString('lib/assets/ABI/ClickerNft.json');
      final abiJson = json.decode(abiString);
      final abiCode = jsonEncode(abiJson['abi']);

      deployedContract = DeployedContract(
        ContractAbi.fromJson(abiCode, "ClickerNFT"),
        EthereumAddress.fromHex(nftContract),
      );

      // Get total types from contract
      final totalRes = await widget.appKitModal.requestReadContract(
        topic: widget.appKitModal.session!.topic,
        chainId: widget.appKitModal.selectedChain!.chainId,
        deployedContract: deployedContract,
        functionName: 'TOTAL_TYPES',
      );

      final rawTotal = totalRes.first;
      final total = rawTotal is BigInt
          ? rawTotal.toInt()
          : int.tryParse(rawTotal.toString()) ?? 0;

      List<Map<String, dynamic>> loadedNFTs = [];

      for (int i = 0; i < total; i++) {
        final uriRes = await widget.appKitModal.requestReadContract(
          topic: widget.appKitModal.session!.topic,
          chainId: widget.appKitModal.selectedChain!.chainId,
          deployedContract: deployedContract,
          functionName: 'uri',
          parameters: [BigInt.from(i)],
        );

        final ipfsUri = uriRes.first.toString().replaceFirst("ipfs://", "https://ipfs.io/ipfs/");
        final res = await http.get(Uri.parse(ipfsUri));
        if (res.statusCode == 200) {
          final jsonData = json.decode(res.body);
          loadedNFTs.add({...jsonData, 'typeId': i});
        }
      }

      setState(() {
        nfts = loadedNFTs;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Failed to load NFTs: $e')),
      );
    }
  }

  Future<void> buyNFT(int typeId) async {
    try {
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
        parameters: [BigInt.from(typeId)],
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ Purchased NFT #$typeId\nTx: $txHash')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Purchase failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("NFT Shop"),
        backgroundColor: Colors.orange,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: Row(
              children: [
                const Icon(Icons.token, color: Colors.amber),
                const SizedBox(width: 4),
                Text(
                  "${widget.tokenAmount}",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          )
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.75,
        ),
        itemCount: nfts.length,
        itemBuilder: (context, index) {
          final nft = nfts[index];
          return Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                children: [
                  Expanded(
                    child: Image.network(
                      nft['image'].toString().replaceFirst("ipfs://", "https://ipfs.io/ipfs/"),
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    nft['name'] ?? 'NFT',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    "${nft['attributes'][1]['value']} BEE",
                    style: const TextStyle(color: Colors.green),
                  ),
                  const SizedBox(height: 6),
                  ElevatedButton(
                    onPressed: () => buyNFT(nft['typeId']),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                    child: const Text("Buy"),
                  )
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
