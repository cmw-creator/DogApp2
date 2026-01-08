import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../services/api.dart';

class MemoryPhotosEditorScreen extends StatefulWidget {
  const MemoryPhotosEditorScreen({Key? key}) : super(key: key);

  @override
  State<MemoryPhotosEditorScreen> createState() => _MemoryPhotosEditorScreenState();
}

class _MemoryPhotosEditorScreenState extends State<MemoryPhotosEditorScreen> {
  bool _loading = false;
  List<Map<String, dynamic>> _photoMemories = [];

  @override
  void initState() {
    super.initState();
    _loadPhotoMemories();
  }

  Future<void> _loadPhotoMemories() async {
    setState(() => _loading = true);
    final data = await Api.getPhotoInfo();
    if (!mounted) return;
    final list = (data ?? {}).entries
        .map((e) => {
              'photo_id': e.key,
              ...Map<String, dynamic>.from((e.value ?? {}) as Map),
            })
        .toList();
    list.sort((a, b) => ((b['event_date'] ?? b['update_time'] ?? '') as String)
        .compareTo((a['event_date'] ?? a['update_time'] ?? '') as String));
    setState(() {
      _photoMemories = list;
      _loading = false;
    });
  }

  Future<void> _deletePhoto(String photoId) async {
    await Api.deletePhotoInfo(photoId);
    _loadPhotoMemories();
  }

  List<String> _splitToList(String input) {
    return input
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  String _joinList(dynamic value) {
    if (value is List) {
      return value.map((e) => e.toString()).join(', ');
    }
    if (value is String) return value;
    return '';
  }

  String _normalizePhotoId(String id) {
    if (id.isEmpty) return '';
    return id.startsWith('photo_') ? id : 'photo_$id';
  }

  Future<String?> _pickAndUploadImage(String photoId) async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result == null || result.files.single.path == null) return null;

    final uploaded = await Api.uploadPhotoImage(
      photoId: photoId,
      filePath: result.files.single.path!,
    );
    if (uploaded != null) {
      return uploaded['asset_path']?.toString() ??
          uploaded['file_path']?.toString();
    }
    return null;
  }

  Future<void> _showPhotoDialog({Map<String, dynamic>? photo}) async {
    final idCtl = TextEditingController(
      text: photo != null ? photo['photo_id'] : '',
    );
    final titleCtl = TextEditingController(
      text: photo != null ? photo['title'] ?? '' : '',
    );
    final dateCtl = TextEditingController(
      text: photo != null ? (photo['event_date'] ?? '') : '',
    );
    final locationCtl = TextEditingController(
      text: photo != null ? (photo['location'] ?? '') : '',
    );
    final tagsCtl = TextEditingController(
      text: photo != null ? _joinList(photo['tags']) : '',
    );
    final peopleCtl = TextEditingController(
      text: photo != null ? _joinList(photo['people']) : '',
    );
    final descCtl = TextEditingController(
      text: photo != null ? (photo['description'] ?? '') : '',
    );

    String imagePath = photo != null ? (photo['image_file'] ?? '') : '';

    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(photo == null ? '新增回忆照片' : '编辑回忆照片'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: idCtl,
                  decoration: const InputDecoration(
                    labelText: '照片编号（例：photo_00004）',
                  ),
                  enabled: photo == null,
                ),
                TextField(
                  controller: titleCtl,
                  decoration: const InputDecoration(labelText: '标题'),
                ),
                TextField(
                  controller: dateCtl,
                  decoration: const InputDecoration(
                    labelText: '拍摄日期，格式：YYYY-MM-DD',
                  ),
                ),
                TextField(
                  controller: locationCtl,
                  decoration: const InputDecoration(labelText: '地点（可选）'),
                ),
                TextField(
                  controller: tagsCtl,
                  decoration: const InputDecoration(labelText: '标签，逗号分隔（可选）'),
                ),
                TextField(
                  controller: peopleCtl,
                  decoration: const InputDecoration(labelText: '人物，逗号分隔（可选）'),
                ),
                TextField(
                  controller: descCtl,
                  decoration: const InputDecoration(labelText: '描述'),
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        imagePath.isEmpty ? '未选择图片' : '已上传：$imagePath',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () async {
                        final id = idCtl.text.trim();
                        if (id.isEmpty) return;
                        final uploaded = await _pickAndUploadImage(id);
                        if (uploaded != null) {
                          setLocal(() => imagePath = uploaded);
                        }
                      },
                      icon: const Icon(Icons.cloud_upload),
                      label: const Text('上传图片'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () {
                final id = _normalizePhotoId(idCtl.text.trim());
                if (id.isEmpty) return;
                Navigator.pop(ctx, {
                  'photo_id': id,
                  'title': titleCtl.text.trim(),
                  'event_date': dateCtl.text.trim(),
                  'location': locationCtl.text.trim(),
                  'tags': _splitToList(tagsCtl.text),
                  'people': _splitToList(peopleCtl.text),
                  'description': descCtl.text.trim(),
                  'image_file': imagePath,
                });
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );

    if (payload != null) {
      await Api.updatePhotoInfo(payload);
      _loadPhotoMemories();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('回忆照片编辑'),
        actions: [
          IconButton(onPressed: _loadPhotoMemories, icon: const Icon(Icons.refresh))
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showPhotoDialog(),
        icon: const Icon(Icons.add_a_photo),
        label: const Text('新增照片'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _photoMemories.isEmpty
              ? const Center(child: Text('暂无回忆照片'))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _photoMemories.length,
                  itemBuilder: (_, index) {
                    final item = _photoMemories[index];
                    final imageUrl = Api.assetUrl(item['image_file']?.toString());
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      child: ListTile(
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: SizedBox(
                            width: 56,
                            height: 56,
                            child: imageUrl.isNotEmpty
                                ? Image.network(imageUrl, fit: BoxFit.cover)
                                : Container(
                                    color: Colors.grey.shade200,
                                    child: const Icon(Icons.photo, color: Colors.grey),
                                  ),
                          ),
                        ),
                        title: Text(item['title']?.toString() ?? '未命名回忆'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if ((item['event_date'] ?? '').toString().isNotEmpty)
                              Text('日期: ${item['event_date']}', style: const TextStyle(fontSize: 12)),
                            if ((item['description'] ?? '').toString().isNotEmpty)
                              Text(
                                item['description'],
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () => _showPhotoDialog(photo: item),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed: () => _deletePhoto(item['photo_id']),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
