// main.dart
// Winzaap

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;

import 'firebase_options.dart';

// Pages
import 'login_page.dart';
import 'verify_email_page.dart';
import 'my_pdfs_page.dart';

/// ===================== MAIN =====================
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const WinzaapApp());
}

/// ===================== APP ROOT =====================
class WinzaapApp extends StatelessWidget {
  const WinzaapApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Winzaap',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.indigo,
        scaffoldBackgroundColor: const Color(0xFFF6F7FB),
      ),
      home: const AuthGate(),
    );
  }
}

/// ================= AUTH GATE =================
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;

        if (user == null) return const LoginPage();
        if (!user.emailVerified) return const VerifyEmailPage();

        return const HomeScreen();
      },
    );
  }
}

/// ================= HOME =================
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
  }

  /// 🔥 Word / PPT → PDF (LOCAL FLASK)
  Future<void> convertOfficeFile(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['doc', 'docx', 'ppt', 'pptx'],
    );

    if (result == null || result.files.single.path == null) return;

    final file = File(result.files.single.path!);

    if (!context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Android Emulator → Mac localhost
      final uri = Uri.parse("http://10.0.2.2:5000/convert");

      final request = http.MultipartRequest('POST', uri);
      request.files.add(
        await http.MultipartFile.fromPath('file', file.path),
      );

      final response = await request.send().timeout(
        const Duration(seconds: 60),
      );

      if (response.statusCode != 200) {
        final err = await response.stream.bytesToString();
        throw 'Server error ${response.statusCode}: $err';
      }

      final dir = await getApplicationDocumentsDirectory();
      final pdfDir = Directory('${dir.path}/pdfs');
      if (!await pdfDir.exists()) {
        await pdfDir.create(recursive: true);
      }

      final pdfFile = File(
        '${pdfDir.path}/winzaap_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );

      final bytes = await response.stream.toBytes();
      await pdfFile.writeAsBytes(bytes);

      if (!context.mounted) return;
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PDF converted & saved')),
      );
    } catch (e) {
      if (!context.mounted) return;
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Conversion failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Winzaap'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Fast PDF Tools',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              'Convert, scan and extract text',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                children: [
                  HomeCard(
                    title: 'My PDFs',
                    icon: Icons.folder,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const MyPdfsPage(),
                        ),
                      );
                    },
                  ),
                  HomeCard(
                    title: 'Image → PDF',
                    icon: Icons.image,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ImageToPdfScreen(),
                        ),
                      );
                    },
                  ),
                  HomeCard(
                    title: 'OCR Scanner',
                    icon: Icons.text_snippet,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const OcrScreen(),
                        ),
                      );
                    },
                  ),
                  HomeCard(
                    title: 'Word → PDF',
                    icon: Icons.description,
                    onTap: () => convertOfficeFile(context),
                  ),
                  HomeCard(
                    title: 'PPT → PDF',
                    icon: Icons.slideshow,
                    onTap: () => convertOfficeFile(context),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ================= HOME CARD =================
class HomeCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  const HomeCard({
    super.key,
    required this.title,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 42, color: Colors.indigo),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ================= IMAGE → PDF =================
class ImageToPdfScreen extends StatefulWidget {
  const ImageToPdfScreen({super.key});

  @override
  State<ImageToPdfScreen> createState() => _ImageToPdfScreenState();
}

class _ImageToPdfScreenState extends State<ImageToPdfScreen> {
  final ImagePicker _picker = ImagePicker();
  final List<File> _images = [];

  Future<void> pickFromCamera() async {
    final photo = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );
    if (photo == null) return;
    setState(() => _images.add(File(photo.path)));
  }

  Future<void> pickFromGallery() async {
    final picked = await _picker.pickMultiImage();
    if (picked.isEmpty) return;
    setState(() {
      _images.addAll(picked.map((e) => File(e.path)));
    });
  }

  Future<void> createPdf() async {
    final pdf = pw.Document();

    for (final img in _images) {
      final bytes = await img.readAsBytes();
      pdf.addPage(
        pw.Page(
          build: (_) => pw.Center(
            child: pw.Image(pw.MemoryImage(bytes)),
          ),
        ),
      );
    }

    final dir = await getApplicationDocumentsDirectory();
    final pdfDir = Directory('${dir.path}/pdfs');
    if (!await pdfDir.exists()) {
      await pdfDir.create(recursive: true);
    }

    final file = File(
      '${pdfDir.path}/winzaap_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );

    await file.writeAsBytes(await pdf.save());

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('PDF saved inside app folder')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Image → PDF')),
      body: Column(
        children: [
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(
                onPressed: pickFromCamera,
                icon: const Icon(Icons.camera_alt),
                label: const Text('Camera'),
              ),
              ElevatedButton.icon(
                onPressed: pickFromGallery,
                icon: const Icon(Icons.photo_library),
                label: const Text('Gallery'),
              ),
            ],
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: _images.length,
              gridDelegate:
              const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
              ),
              itemBuilder: (_, i) =>
                  Image.file(_images[i], fit: BoxFit.cover),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: ElevatedButton(
              onPressed: _images.isEmpty ? null : createPdf,
              child: const Text('Convert to PDF'),
            ),
          ),
        ],
      ),
    );
  }
}

/// ================= OCR =================
class OcrScreen extends StatefulWidget {
  const OcrScreen({super.key});

  @override
  State<OcrScreen> createState() => _OcrScreenState();
}

class _OcrScreenState extends State<OcrScreen> {
  final ImagePicker _picker = ImagePicker();
  bool _loading = false;
  String _text = '';

  Future<void> pickImageAndRecognize() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    setState(() {
      _loading = true;
      _text = '';
    });

    final inputImage = InputImage.fromFilePath(picked.path);
    final textRecognizer =
    TextRecognizer(script: TextRecognitionScript.latin);

    final result = await textRecognizer.processImage(inputImage);
    await textRecognizer.close();

    if (!mounted) return;
    setState(() {
      _text = result.text;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('OCR Scanner')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ElevatedButton.icon(
              onPressed: _loading ? null : pickImageAndRecognize,
              icon: const Icon(Icons.upload_file),
              label: const Text('Pick Image'),
            ),
            const SizedBox(height: 16),
            if (_loading) const CircularProgressIndicator(),
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  _text.isEmpty
                      ? 'Recognized text will appear here'
                      : _text,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}