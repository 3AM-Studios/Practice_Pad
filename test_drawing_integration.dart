import 'package:flutter/material.dart';
import 'package:flutter_drawing_board/flutter_drawing_board.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Drawing Test',
      home: DrawingTestScreen(),
    );
  }
}

class DrawingTestScreen extends StatefulWidget {
  @override
  _DrawingTestScreenState createState() => _DrawingTestScreenState();
}

class _DrawingTestScreenState extends State<DrawingTestScreen> {
  bool _isDrawingMode = false;
  late DrawingController _drawingController;

  @override
  void initState() {
    super.initState();
    _drawingController = DrawingController();
  }

  Widget _buildBackground() {
    return Container(
      width: 400,
      height: 400,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey),
      ),
      child: Center(
        child: Text(
          'Background Content\n(Sheet Music Would Be Here)',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18,
            color: Colors.grey[600],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawingOverlay() {
    return Stack(
      children: [
        // Background content
        _buildBackground(),
        // Drawing board overlay
        DrawingBoard(
          controller: _drawingController,
          background: Container(
            width: 400,
            height: 400,
            color: Colors.transparent, // Transparent to show background
          ),
          showDefaultActions: true,
          showDefaultTools: true,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Drawing Test'),
        actions: [
          IconButton(
            icon: Icon(
              _isDrawingMode ? Icons.edit_off : Icons.draw,
              color: _isDrawingMode ? Colors.blue : null,
            ),
            onPressed: () {
              setState(() {
                _isDrawingMode = !_isDrawingMode;
              });
            },
            tooltip: _isDrawingMode ? 'Exit Drawing Mode' : 'Enter Drawing Mode',
          ),
        ],
      ),
      body: Center(
        child: Container(
          width: 450,
          height: 450,
          padding: EdgeInsets.all(25),
          child: _isDrawingMode 
              ? _buildDrawingOverlay()
              : _buildBackground(),
        ),
      ),
    );
  }
}