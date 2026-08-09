import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:intl/intl.dart';

List<CameraDescription> cameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    cameras = await availableCameras();
  } catch (e) {
    debugPrint("Camera Initialization Error: $e");
  }
  runApp(const CaseDiaryApp());
}

class CaseDiaryApp extends StatelessWidget {
  const CaseDiaryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'কেস ডায়েরি',
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        useMaterial3: true,
      ),
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// Case Data Model
class CaseModel {
  String caseNumber;
  String clientName;
  String courtName;
  String currentDate;
  String nextDate;
  String status; // Pending, Acquitted, Disposed, etc.
  String caseType; // Civil, Criminal, etc.

  CaseModel({
    required this.caseNumber,
    required this.clientName,
    required this.courtName,
    required this.currentDate,
    required this.nextDate,
    required this.status,
    required this.caseType,
  });
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final List<CaseModel> _cases = [];

  void _addCase(CaseModel caseItem) {
    setState(() {
      _cases.add(caseItem);
    });
  }

  @override
  Widget build(BuildContext context) {
    int totalCases = _cases.length;
    int pendingCases = _cases.where((c) => c.status == 'পেন্ডিং').length;
    int acquittedCases = _cases.where((c) => c.status == 'খালাস').length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('আইনজীবী কেস ডায়েরি'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Summary Dashboard Card
              Card(
                color: Colors.indigo.shade50,
                elevation: 3,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatColumn('মোট মামলা', '$totalCases'),
                      _buildStatColumn('পেন্ডিং', '$pendingCases'),
                      _buildStatColumn('খালাস', '$acquittedCases'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 15),
              const Text(
                'মামলার তালিকা',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              _cases.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(30.0),
                        child: Text('কোন মামলা যুক্ত করা হয়নি। নিচে স্ক্যান করে যুক্ত করুন।'),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _cases.length,
                      itemBuilder: (context, index) {
                        final c = _cases[index];
                        return Card(
                          child: ListTile(
                            title: Text('${c.caseNumber} - ${c.clientName}'),
                            subtitle: Text('পরবর্তী তারিখ: ${c.nextDate} | আদালত: ${c.courtName}'),
                            trailing: Chip(
                              label: Text(c.status),
                              backgroundColor: c.status == 'খালাস'
                                  ? Colors.green.shade100
                                  : Colors.orange.shade100,
                            ),
                          ),
                        );
                      },
                    ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          if (cameras.isNotEmpty) {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ScanDiaryScreen(camera: cameras.first),
              ),
            );
            if (result != null && result is CaseModel) {
              _addCase(result);
            }
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('ক্যামেরা পাওয়া যায়নি!')),
            );
          }
        },
        icon: const Icon(Icons.qr_code_scanner),
        label: const Text('ডায়েরি স্ক্যান করুন'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildStatColumn(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.indigo)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}

// ML Kit Smart OCR Camera View
class ScanDiaryScreen extends StatefulWidget {
  final CameraDescription camera;

  const ScanDiaryScreen({super.key, required this.camera});

  @override
  State<ScanDiaryScreen> createState() => _ScanDiaryScreenState();
}

class _ScanDiaryScreenState extends State<ScanDiaryScreen> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _controller = CameraController(widget.camera, ResolutionPreset.high);
    _initializeControllerFuture = _controller.initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _processImage() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      await _initializeControllerFuture;
      final image = await _controller.takePicture();

      final inputImage = InputImage.fromFilePath(image.path);
      final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);

      String rawText = recognizedText.text;
      await textRecognizer.close();

      if (!mounted) return;

      // Extract raw parsed text and send to Confirmation Form Page
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => AddEditCaseScreen(scannedText: rawText),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('স্ক্যানিং ব্যর্থ হয়েছে: $e')),
      );
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ডায়েরির পাতা স্ক্যান করুন')),
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return Stack(
              children: [
                CameraPreview(_controller),
                if (_isProcessing)
                  const Center(child: CircularProgressIndicator()),
              ],
            );
          } else {
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _processImage,
        child: const Icon(Icons.camera_alt),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}

// Manual Form / Scanned Data Edit View
class AddEditCaseScreen extends StatefulWidget {
  final String scannedText;

  const AddEditCaseScreen({super.key, required this.scannedText});

  @override
  State<AddEditCaseScreen> createState() => _AddEditCaseScreenState();
}

class _AddEditCaseScreenState extends State<AddEditCaseScreen> {
  final _caseNoController = TextEditingController();
  final _clientController = TextEditingController();
  final _courtController = TextEditingController();
  final _nextDateController = TextEditingController();

  String _status = 'পেন্ডিং';
  String _caseType = 'ফৌজদারী';

  @override
  void initState() {
    super.initState();
    _parseText(widget.scannedText);
  }

  // Simple heuristic parser for text extraction
  void _parseText(String text) {
    _caseNoController.text = text; // Scanned raw data auto populated
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('মামলার বিবরণ নিশ্চিত করুন')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: _caseNoController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'স্ক্যানকৃত টেক্সট / মামলা নম্বর',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _clientController,
                decoration: const InputDecoration(
                  labelText: 'ক্লায়েন্টের নাম ও মোবাইল নম্বর',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _courtController,
                decoration: const InputDecoration(
                  labelText: 'আদালতের নাম',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _nextDateController,
                decoration: const InputDecoration(
                  labelText: 'পরবর্তী তারিখ (YYYY-MM-DD)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: _status,
                items: ['পেন্ডিং', 'খালাস', 'নিষ্পত্তি'].map((val) {
                  return DropdownMenuItem(value: val, child: Text(val));
                }).toList(),
                onChanged: (val) => setState(() => _status = val!),
                decoration: const InputDecoration(labelText: 'মামলার অবস্থা'),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  final newCase = CaseModel(
                    caseNumber: _caseNoController.text,
                    clientName: _clientController.text,
                    courtName: _courtController.text,
                    currentDate: DateFormat('yyyy-MM-dd').format(DateTime.now()),
                    nextDate: _nextDateController.text,
                    status: _status,
                    caseType: _caseType,
                  );
                  Navigator.pop(context, newCase);
                },
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                ),
                child: const Text('সংরক্ষণ করুন (Save)'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
