import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';

enum SortType { date, name }

class MyPdfsPage extends StatefulWidget {
  const MyPdfsPage({super.key});

  @override
  State<MyPdfsPage> createState() => _MyPdfsPageState();
}

class _MyPdfsPageState extends State<MyPdfsPage> {
  List<File> _allPdfs = [];
  List<File> _filteredPdfs = [];
  bool _loading = true;
  SortType _sortType = SortType.date;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadPdfs();
  }

  Future<void> _loadPdfs() async {
    final dir = await getApplicationDocumentsDirectory();
    final pdfDir = Directory('${dir.path}/pdfs');

    if (await pdfDir.exists()) {
      _allPdfs = pdfDir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.pdf'))
          .toList();

      _applyFilters();
    }

    setState(() => _loading = false);
  }

  void _applyFilters() {
    _filteredPdfs = _allPdfs.where((file) {
      final name = file.path.split('/').last.toLowerCase();
      return name.contains(_searchQuery.toLowerCase());
    }).toList();

    _applySorting();
  }

  void _applySorting() {
    if (_sortType == SortType.name) {
      _filteredPdfs.sort((a, b) =>
          a.path.split('/').last.compareTo(b.path.split('/').last));
    } else {
      _filteredPdfs.sort(
        (a, b) =>
            b.lastModifiedSync().compareTo(a.lastModifiedSync()),
      );
    }
  }

  Future<void> _deletePdf(File file) async {
    await file.delete();
    _loadPdfs();
  }

  Future<void> _renamePdf(File file) async {
    final controller = TextEditingController(
      text: file.path.split('/').last.replaceAll('.pdf', ''),
    );

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Rename PDF'),
        content: TextField(
          controller: controller,
          decoration:
              const InputDecoration(hintText: 'Enter new name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            child: const Text('Rename'),
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isEmpty) return;

              final newPath =
                  '${file.parent.path}/$newName.pdf';

              await file.rename(newPath);

              if (!mounted) return;
              Navigator.pop(context);
              _loadPdfs();
            },
          ),
        ],
      ),
    );
  }

  void _showOptions(File file) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.open_in_new),
              title: const Text('Open'),
              onTap: () {
                Navigator.pop(context);
                OpenFilex.open(file.path);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Rename'),
              onTap: () {
                Navigator.pop(context);
                _renamePdf(file);
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete'),
              onTap: () {
                Navigator.pop(context);
                _deletePdf(file);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _changeSort(SortType type) {
    setState(() {
      _sortType = type;
      _applySorting();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My PDFs'),
        actions: [
          PopupMenuButton<SortType>(
            icon: const Icon(Icons.sort),
            onSelected: _changeSort,
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: SortType.date,
                child: Text('Sort by date'),
              ),
              PopupMenuItem(
                value: SortType.name,
                child: Text('Sort by name'),
              ),
            ],
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // 🔍 SEARCH BAR
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search PDFs',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                        _applyFilters();
                      });
                    },
                  ),
                ),

                Expanded(
                  child: _filteredPdfs.isEmpty
                      ? const Center(child: Text('No PDFs found'))
                      : ListView.builder(
                          itemCount: _filteredPdfs.length,
                          itemBuilder: (context, index) {
                            final file = _filteredPdfs[index];
                            final name =
                                file.path.split('/').last;

                            return ListTile(
                              leading: const Icon(
                                Icons.picture_as_pdf,
                                color: Colors.red,
                              ),
                              title: Text(name),
                              subtitle: Text(
                                'Modified: ${file.lastModifiedSync()}',
                                style:
                                    const TextStyle(fontSize: 12),
                              ),
                              onTap: () =>
                                  OpenFilex.open(file.path),
                              onLongPress: () =>
                                  _showOptions(file),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}