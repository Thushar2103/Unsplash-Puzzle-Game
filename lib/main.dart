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
import 'package:provider/provider.dart';
import 'package:puzzle_game/utils/theme_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final themeProvider = ThemeProvider(); // Create an instance of ThemeProvider
  await themeProvider.loadThemeMode();
  await dotenv.load(fileName: ".env");
  runApp(
    ChangeNotifierProvider.value(
      value: themeProvider,
      child: const MyApp(),
    ),
  );

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

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final ValueNotifier<ThemeMode> _themeModeNotifier =
      ValueNotifier(ThemeMode.system);
  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        return MaterialApp(
            title: 'Ranzle',
            debugShowCheckedModeBanner: false,
            theme: ThemeData.light(),
            darkTheme: ThemeData.dark(),
            themeMode: themeProvider.themeMode,
            home: PuzzlePage(
              themeModeNotifier: _themeModeNotifier,
            ));
      },
    );
  }
}

class PuzzlePage extends StatefulWidget {
  final ValueNotifier<ThemeMode> themeModeNotifier;
  const PuzzlePage({super.key, required this.themeModeNotifier});

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
        title: MouseRegion(
          cursor: MaterialStateMouseCursor.clickable,
          child: GestureDetector(
            onTap: () => menu(context),
            child: const Text(
              'Ranzle',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
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
          height: 50,
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
          shape:
              ContinuousRectangleBorder(borderRadius: BorderRadius.circular(5)),
          content: Image.network(_imageUrl),
          actions: [
            ElevatedButton(
              style: ButtonStyle(
                  shape: MaterialStateProperty.all(ContinuousRectangleBorder(
                      borderRadius: BorderRadius.circular(5))),
                  backgroundColor: const MaterialStatePropertyAll(Colors.red),
                  foregroundColor:
                      const MaterialStatePropertyAll(Colors.white)),
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
          shape:
              ContinuousRectangleBorder(borderRadius: BorderRadius.circular(5)),
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

  void menu(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape:
              ContinuousRectangleBorder(borderRadius: BorderRadius.circular(5)),
          title: const Text(
            "Menu",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Column(
            children: [
              const ListTile(
                leading: Icon(Icons.computer),
                title: Text("Version"),
                subtitle: Text("1.0"),
              ),
              const ListTile(
                leading: Icon(Icons.image_rounded),
                title: Text("Image Provider"),
                subtitle: Text("Unsplash"),
              ),
              ListTile(
                leading: const Icon(Icons.mode_edit),
                title: const Text("Theme"),
                subtitle: const Text("Dark/Light"),
                trailing: Consumer<ThemeProvider>(
                  builder: (context, themeProvider, _) {
                    return Switch(
                      value: themeProvider.themeMode == ThemeMode.light,
                      onChanged: (_) {
                        themeProvider.toggleTheme();
                      },
                    );
                  },
                ),
              ),
              const Spacer(),
              const Text(
                "Developed By",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const Text("Tascuit")
            ],
          ),
          actions: [
            ElevatedButton(
                style: const ButtonStyle(
                    shape: MaterialStatePropertyAll(RoundedRectangleBorder(
                        borderRadius: BorderRadius.all(Radius.circular(5)))),
                    foregroundColor: MaterialStatePropertyAll(Colors.white),
                    backgroundColor: MaterialStatePropertyAll(Colors.red)),
                onPressed: () => Navigator.pop(context),
                child: const Text("Close"))
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
