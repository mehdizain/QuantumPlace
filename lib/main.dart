import 'package:flutter/material.dart';
import 'package:arcore_flutter_plugin/arcore_flutter_plugin.dart';
import 'package:vector_math/vector_math_64.dart' as vector;

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: Colors.blueGrey[900],
        scaffoldBackgroundColor: Colors.grey[900],
        cardColor: Colors.grey[850],
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blueGrey[700],
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: EdgeInsets.symmetric(vertical: 12),
          ),
        ),
        textTheme: TextTheme(
          titleMedium: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          bodyMedium: TextStyle(color: Colors.grey[300]),
          bodySmall: TextStyle(color: Colors.grey[500]),
        ),
      ),
      home: const ARViewScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class ARViewScreen extends StatefulWidget {
  const ARViewScreen({super.key});

  @override
  State<ARViewScreen> createState() => _ARViewScreenState();
}

class _ARViewScreenState extends State<ARViewScreen> {
  ArCoreController? _controller;
  int _objectCount = 0;
  String? _selectedObjectName;
  DateTime _lastTapTime = DateTime.now();

  // Updated list with lightweight models
  final List<Map<String, dynamic>> _models = [
    {
      'name': 'Damaged Helmet',
      'url': 'https://raw.githubusercontent.com/KhronosGroup/glTF-Sample-Models/master/2.0/DamagedHelmet/glTF-Binary/DamagedHelmet.glb',
      'scale': 0.5
    },
    {
      'name': 'Cesium Man',
      'url': 'https://raw.githubusercontent.com/KhronosGroup/glTF-Sample-Models/master/2.0/CesiumMan/glTF-Binary/CesiumMan.glb',
      'scale': 0.02
    },
    {
      'name': 'BoxTextured',
      'url': 'https://raw.githubusercontent.com/KhronosGroup/glTF-Sample-Models/master/2.0/BoxTextured/glTF-Binary/BoxTextured.glb',
      'scale': 0.5
    },
    {
      'name': 'WaterBottle',
      'url': 'https://raw.githubusercontent.com/KhronosGroup/glTF-Sample-Models/master/2.0/WaterBottle/glTF-Binary/WaterBottle.glb',
      'scale': 0.8
    },
  ];

  String _selectedModel = 'Damaged Helmet'; // Default model

  void _onArCoreViewCreated(ArCoreController controller) {
    _controller = controller;
    print('AR View created! Tap on detected planes to place objects.');
    _controller!.onPlaneTap = _onPlaneTapped;
    _controller!.onNodeTap = _onObjectTapped;
  }

  void _onPlaneTapped(List<ArCoreHitTestResult> hits) {
    if (hits.isNotEmpty) {
      setState(() {
        _selectedObjectName = null;
      });
      final hit = hits.first;
      print('Plane tapped! Placing object at: ${hit.pose.translation}');
      _add3DModel(hit.pose.translation);
    }
  }

  void _add3DModel(vector.Vector3 position) {
    if (_controller != null) {
      _objectCount++;
      print('Creating 3D model #$_objectCount at position: $position');

      final model = _models.firstWhere((m) => m['name'] == _selectedModel);
      final modelUrl = model['url'] as String;
      final modelScale = model['scale'] as double;

      print('Loading 3D model from: $modelUrl');

      final node = ArCoreReferenceNode(
        name: 'model_$_objectCount',
        objectUrl: modelUrl,
        position: position,
        scale: vector.Vector3(modelScale, modelScale, modelScale),
      );

      if (_selectedObjectName == null) {
        _selectedObjectName = node.name;
      }

      try {
        _controller!.addArCoreNodeWithAnchor(node);
        print('3D MODEL #$_objectCount ADDED at scale $modelScale');
        print('Model should appear shortly after download...');
      } catch (e) {
        print('Failed to add model #$_objectCount: $e');
        setState(() {
          _objectCount = _objectCount > 0 ? _objectCount - 1 : 0;
        });
      }
    } else {
      print('Controller is null - cannot add 3D model');
    }
  }

  void _onObjectTapped(String objectName) {
    final now = DateTime.now();
    final timeDifference = now.difference(_lastTapTime).inMilliseconds;

    if (timeDifference < 300) {
      print('Tap ignored - too soon after last tap ($timeDifference ms)');
      return;
    }

    _lastTapTime = now;
    print('Object tap detected: $objectName');
    print('Currently selected: $_selectedObjectName');

    setState(() {
      if (_selectedObjectName == objectName) {
        _selectedObjectName = null;
        print('Object $objectName DESELECTED');
      } else {
        _selectedObjectName = objectName;
        print('Object $objectName SELECTED');
      }
    });
  }

  void _deleteSelectedModel() {
    if (_controller != null && _selectedObjectName != null) {
      try {
        _controller!.removeNode(nodeName: _selectedObjectName!);
        print('Removed model: $_selectedObjectName');
        setState(() {
          _objectCount = _objectCount > 0 ? _objectCount - 1 : 0;
        });
      } catch (e) {
        print('Could not remove model $_selectedObjectName: $e');
      } finally {
        setState(() {
          _selectedObjectName = null;
        });
      }
    }
  }

  void _clearScene() {
    if (_controller != null) {
      for (int i = 1; i <= _objectCount; i++) {
        try {
          _controller!.removeNode(nodeName: 'model_$i');
          print('Removed model_$i');
        } catch (e) {
          print('Could not remove model_$i: $e');
        }
      }
      setState(() {
        _objectCount = 0;
        _selectedObjectName = null;
      });
      print('3D models scene cleared!');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("AR Model Placement"),
        backgroundColor: Colors.blueGrey[900],
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: DropdownButton<String>(
              value: _selectedModel,
              dropdownColor: Colors.grey[850],
              style: TextStyle(color: Colors.white),
              items: _models.map((model) {
                return DropdownMenuItem<String>(
                  value: model['name'],
                  child: Text(model['name']),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedModel = value!;
                  print('Selected model changed to: $_selectedModel');
                });
              },
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          ArCoreView(
            onArCoreViewCreated: _onArCoreViewCreated,
            enableTapRecognizer: true,
            debug: false,
          ),
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Tap planes to place • Tap models to select',
                      style: Theme.of(context).textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Models: $_objectCount',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        if (_selectedObjectName != null)
                          Text(
                            'Selected: $_selectedObjectName',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.blue[300],
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        else
                          Text(
                            'No object selected',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _selectedObjectName != null ? _deleteSelectedModel : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _selectedObjectName != null ? Colors.red[700] : Colors.grey[600],
                    ),
                    child: Text('Delete Selected'),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _clearScene,
                    child: Text('Clear All'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }
}