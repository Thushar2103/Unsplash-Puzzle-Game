// ignore_for_file: deprecated_member_use, library_private_types_in_public_api

import 'package:flutter/material.dart';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image/image.dart' as img;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'dart:io';
import 'package:flutter_skeleton_ui/flutter_skeleton_ui.dart';

void main() async {
  await dotenv.load(fileName: ".env");
  runApp(const MyApp());

  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    doWhenWindowReady(() {
      const initialSize = Size(380, 600);
      appWindow.minSize = initialSize;
      appWindow.maxSize = initialSize;
      appWindow.size = initialSize;
      appWindow.alignment = Alignment.center;
      appWindow.show();
    });
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
        title: 'Tascuit Puzzle',
        debugShowCheckedModeBanner: false,
        home: PuzzlePage());
  }
}

class PuzzlePage extends StatefulWidget {
  const PuzzlePage({super.key});

  @override
  _PuzzlePageState createState() => _PuzzlePageState();
}

class _PuzzlePageState extends State<PuzzlePage> {
  late List<ImagePiece> _imagePieces;
  late ImagePiece _emptyPiece;
  String _imageUrl = '';
  bool _isLoading = false;
  bool _isSolved = false;

  @override
  void initState() {
    super.initState();
    _initializeGame();
  }

  Future<void> _initializeGame() async {
    setState(() {
      _isLoading = true;
      _isSolved = false;
    });

    final String apiKey = dotenv.env['unsplash_api'].toString();
    // final String apiKey = 'HVKxqFepaiBeSghcARNzOFTY2CUvU7URmKPT5V61AzA';
    final String apiUrl =
        'https://api.unsplash.com/photos/random?client_id=$apiKey';

    try {
      final response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode == 200) {
        final imageData = json.decode(response.body);
        _imageUrl = imageData['urls']['regular'];
        await _splitImageIntoPieces(_imageUrl);
      }
    } catch (e) {
      const Center(
        child: Text('Failed to load'),
      );
      print('Error fetching image: $e');
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _splitImageIntoPieces(String imageUrl) async {
    final response = await http.get(Uri.parse(imageUrl));
    final Uint8List imageData = response.bodyBytes;

    final img.Image image = img.decodeImage(imageData)!;

    final double pieceWidth = image.width.toDouble() / 4;
    final double pieceHeight = image.height.toDouble() / 4;

    _imagePieces = List.generate(16, (index) {
      final int row = index ~/ 4;
      final int col = index % 4;
      final img.Image piece = img.copyCrop(image, (col * pieceWidth).toInt(),
          (row * pieceHeight).toInt(), pieceWidth.toInt(), pieceHeight.toInt());
      final pieceBytes = img.encodePng(piece);
      return ImagePiece(
          index + 1, MemoryImage(Uint8List.fromList(pieceBytes.toList())));
    });

    _emptyPiece = ImagePiece(0, MemoryImage(Uint8List(0)));

    _imagePieces.shuffle();

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'Tascuit',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              'Puzzle',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          if (Platform.isWindows || Platform.isLinux || Platform.isMacOS)
            Row(
              children: [
                MoveWindow(
                  child: Container(
                    width: MediaQuery.of(context).size.width / 3,
                  ),
                ),
                MinimizeWindowButton(),
                CloseWindowButton()
              ],
            ),
        ],
      ),
      body: _isLoading
          // ? const Center(child: CircularProgressIndicator())
          ? Center(
              child: SkeletonAvatar(
                style: SkeletonAvatarStyle(
                    height: MediaQuery.of(context).size.height / 1.2,
                    width: MediaQuery.of(context).size.width / 1.1),
              ),
            )
          : Center(
              child: Padding(
                padding: const EdgeInsets.all(10.0),
                child: _buildPuzzleGrid(),
              ),
            ),
      floatingActionButton: _isLoading
          ? null
          : FloatingActionButton(
              shape: const CircleBorder(),
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              onPressed: _displayActualImage,
              child: const Icon(Icons.image),
            ),
    );
  }

  Widget _buildPuzzleGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(
          height: 30,
        ),
        Expanded(
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
            ),
            itemCount: _imagePieces.length,
            itemBuilder: (context, index) {
              final imagePiece = _imagePieces[index];
              return DragTarget<ImagePiece>(
                onAccept: (droppedPiece) {
                  _movePiece(droppedPiece, imagePiece);
                },
                builder: (context, candidateData, rejectedData) {
                  return Draggable<ImagePiece>(
                    data: imagePiece,
                    feedback: Container(
                      decoration: BoxDecoration(
                        image: DecorationImage(
                          image: _imageUrl.isNotEmpty
                              ? imagePiece.image
                              : _emptyPiece.image,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    childWhenDragging: Container(),
                    child: Container(
                      decoration: BoxDecoration(
                        image: DecorationImage(
                          image: _imageUrl.isNotEmpty
                              ? imagePiece.image
                              : _emptyPiece.image,
                          fit: BoxFit.fill,
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        const SizedBox(
          height: 25,
          child: Text('Drag and drop the puzzle'),
        ),
        ElevatedButton(
          style: const ButtonStyle(
              shape: MaterialStatePropertyAll(RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(5)))),
              backgroundColor: MaterialStatePropertyAll(Colors.red),
              foregroundColor: MaterialStatePropertyAll(Colors.white)),
          onPressed: _initializeGame,
          child: const Text('Try Other'),
        ),
      ],
    );
  }

  void _displayActualImage() {
    if (_imageUrl.isNotEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          content: Image.network(_imageUrl),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    }
  }

  void _movePiece(ImagePiece droppedPiece, ImagePiece targetPiece) {
    if (_isSolved) {
      return;
    }

    setState(() {
      final int droppedPieceIndex = _imagePieces.indexOf(droppedPiece);
      final int targetPieceIndex = _imagePieces.indexOf(targetPiece);

      // Swap dropped piece with target piece
      _imagePieces[droppedPieceIndex] = targetPiece;
      _imagePieces[targetPieceIndex] = droppedPiece;

      _checkSolved();
    });
  }

  void _checkSolved() {
    if (_imagePieces.isEmpty) {
      return;
    }

    for (int i = 0; i < _imagePieces.length - 1; i++) {
      if (_imagePieces[i].number != i + 1) {
        return;
      }
    }
    setState(() {
      _isSolved = true;
    });
    _showSolvedDialog();
  }

  Future<void> _showSolvedDialog() async {
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Congratulations!'),
          content: const Text('You solved the puzzle.'),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _initializeGame();
              },
              child: const Text('Play Again'),
            ),
          ],
        );
      },
    );
  }
}

class ImagePiece {
  final int number;
  final MemoryImage image;

  ImagePiece(this.number, this.image);
}
