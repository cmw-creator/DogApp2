import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../services/api.dart';
import '../services/local_store.dart';
import '../services/notification_service.dart';
import '../services/in_app_notification.dart';
import 'notification_screen.dart';

class ManageScreen extends StatefulWidget {
  final void Function(String)? onServerUrlChanged;
  const ManageScreen({Key? key, this.onServerUrlChanged}) : super(key: key);

  @override
  State<ManageScreen> createState() => _ManageScreenState();
}

class _ManageScreenState extends State<ManageScreen>
    with SingleTickerProviderStateMixin {
  bool _loading = true;
  List<Map<String, dynamic>> _faces = [];
  List<Map<String, dynamic>> _questions = [];
  List<Map<String, dynamic>> _photoMemories = [];
  Map<String, dynamic> _medicines = {};
  List<Map<String, dynamic>> _schedules = [];
  StreamSubscription<Map<String, dynamic>>? _notifSub;

  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _initNotificationListener();
    _refreshAll();
  }

  @override
  void dispose() {
    _notifSub?.cancel();
    NotificationService.instance.stop();
    _tabController.dispose();
    super.dispose();
  }

  void _initNotificationListener() {
    NotificationService.instance.start();
    _notifSub = NotificationService.instance.stream.listen((event) {
      if (!mounted) return;
      _showNotificationDialog(event);
    });
  }

  void _showNotificationDialog(Map<String, dynamic> event) {
    final message = event['message']?.toString() ?? '收到新通知';
    final type = event['type']?.toString() ?? 'info';
    InAppNotification.instance.show(
      title: '通知：$type',
      message: message,
      severity: type == 'sos'
          ? InAppNotificationSeverity.danger
          : InAppNotificationSeverity.info,
      actionLabel: '查看通知',
      onAction: () {
        if (!mounted) return;
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const NotificationCenterScreen()),
        );
      },
    );
  }

  Future<void> _refreshAll() async {
    setState(() => _loading = true);
    await Future.wait([
      _loadFaceInfo(),
      _loadPhotoMemories(),
      _loadQuestions(),
      _loadMedicine(),
      _loadSchedule(),
    ]);
    setState(() => _loading = false);
  }

  Future<void> _loadQuestions() async {
    final data = await Api.getFamilyQuestions();
    if (data != null) {
      setState(() => _questions =
          data.map((e) => Map<String, dynamic>.from(e)).toList());
    }
  }

  Future<void> _loadPhotoMemories() async {
    final data = await Api.getPhotoInfo();
    if (data != null) {
      final list = data.entries
          .map((e) => {
                'photo_id': e.key,
                ...Map<String, dynamic>.from((e.value ?? {}) as Map),
              })
          .toList();

      list.sort((a, b) =>
          ((b['event_date'] ?? b['update_time'] ?? '') as String)
              .compareTo((a['event_date'] ?? a['update_time'] ?? '') as String));
      setState(() => _photoMemories = list);
    }
  }

  Future<void> _loadFaceInfo() async {
    final data = await Api.getFaceInfo();
    if (data != null) {
      setState(() => _faces = data.entries
          .map((entry) =>
              {'id': entry.key, ...Map<String, dynamic>.from(entry.value)})
          .toList());
    }
  }

  Future<void> _loadMedicine() async {
    final data = await Api.getMedicineInfo();
    if (data != null) {
      setState(() => _medicines = data);
    }
  }

  Future<void> _loadSchedule() async {
    final data = await Api.getSchedules();
    if (data != null) {
      setState(() => _schedules =
          data.map((e) => Map<String, dynamic>.from(e)).toList());
    }
  }

  Future<void> _showFaceDialog({Map<String, dynamic>? face}) async {
    final idCtl = TextEditingController(text: face != null ? face['id'] : '');
    final descCtl =
        TextEditingController(text: face != null ? face['description'] : '');
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(face == null ? '新增家庭成员' : '编辑家庭成员'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: idCtl,
              decoration: const InputDecoration(labelText: '成员编号'),
            ),
            TextField(
              controller: descCtl,
              decoration: const InputDecoration(labelText: '描述'),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          ElevatedButton(
            onPressed: () {
              final faceId = idCtl.text.trim();
              if (faceId.isEmpty) return;
              Navigator.pop(ctx, {
                'face_id': faceId,
                'description': descCtl.text.trim(),
              });
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (result != null) {
      await Api.updateFaceInfo(result);
      _loadFaceInfo();
    }
  }

  Future<void> _pickAndSaveMemberPhoto(String memberId) async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result == null || result.files.single.path == null) return;

    // 优先上传到后端（可多端共享）；失败则回退为本地路径显示。
    final uploaded = await Api.uploadFaceImage(
      faceId: memberId,
      filePath: result.files.single.path!,
    );

    await LocalStore.ensureInit();
    if (uploaded != null) {
      final relative = uploaded['asset_path']?.toString() ?? uploaded['file_path']?.toString();
      if (relative != null && relative.isNotEmpty) {
        await LocalStore.setFamilyMemberPhotoPath(memberId: memberId, filePath: relative);
      }
    } else {
      await LocalStore.setFamilyMemberPhotoPath(
        memberId: memberId,
        filePath: result.files.single.path!,
      );
    }

    if (mounted) setState(() {});
  }

  Future<void> _clearMemberPhoto(String memberId) async {
    await LocalStore.ensureInit();
    await LocalStore.setFamilyMemberPhotoPath(memberId: memberId, filePath: '');
    if (mounted) setState(() {});
  }

  Widget _buildMemberAvatar(Map<String, dynamic> face) {
    final id = (face['id'] ?? '').toString();
    final path = LocalStore.getFamilyMemberPhotoPath(id);
    final isRemoteAsset = path != null && path.isNotEmpty && !path.contains('\\') && !path.contains(':/') && !path.startsWith('file:');
    final remoteUrl = isRemoteAsset ? Api.assetUrl(path) : '';
    final file = (!isRemoteAsset && path != null && path.isNotEmpty) ? File(path) : null;
    final exists = file != null && file.existsSync();

    Widget child;
    if (remoteUrl.isNotEmpty) {
      child = ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.network(remoteUrl, width: 48, height: 48, fit: BoxFit.cover),
      );
    } else if (exists) {
      child = ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.file(file!, width: 48, height: 48, fit: BoxFit.cover),
      );
    } else {
      child = Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(Icons.person, color: Colors.grey.shade600),
      );
    }

    return InkWell(
      onTap: id.isEmpty ? null : () => _pickAndSaveMemberPhoto(id),
      borderRadius: BorderRadius.circular(10),
      child: Stack(
        children: [
          child,
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.55),
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.all(2),
              child: const Icon(Icons.camera_alt, size: 14, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showPhotoDialog({Map<String, dynamic>? photo}) async {
    final idCtl = TextEditingController(text: photo != null ? photo['photo_id'] : '');
    final titleCtl =
        TextEditingController(text: photo != null ? photo['title'] ?? '' : '');
    final dateCtl = TextEditingController(
        text: photo != null ? (photo['event_date'] ?? '') : '');
    final locationCtl = TextEditingController(
        text: photo != null ? (photo['location'] ?? '') : '');
    final tagsCtl = TextEditingController(
        text: photo != null ? _joinList(photo['tags']) : '');
    final peopleCtl = TextEditingController(
        text: photo != null ? _joinList(photo['people']) : '');
    final descCtl = TextEditingController(
        text: photo != null ? (photo['description'] ?? '') : '');

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
                  decoration: const InputDecoration(labelText: '照片编号（例：photo_00004）'),
                  enabled: photo == null,
                ),
                TextField(
                  controller: titleCtl,
                  decoration: const InputDecoration(labelText: '标题'),
                ),
                TextField(
                  controller: dateCtl,
                  decoration: const InputDecoration(labelText: '拍摄日期，格式：YYYY-MM-DD'),
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
                        imagePath.isEmpty
                            ? '未选择图片'
                            : '已上传：$imagePath',
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
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
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

  Future<void> _showMemoryDialog({Map<String, dynamic>? question, int? index}) async {
    final questionCtl =
        TextEditingController(text: question != null ? question['question'] : '');
    final answerCtl =
        TextEditingController(text: question != null ? question['answer'] : '');
    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(question == null ? '新增记忆条目' : '编辑记忆条目'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: questionCtl, decoration: const InputDecoration(labelText: '问题')),
            TextField(controller: answerCtl, decoration: const InputDecoration(labelText: '回答')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          ElevatedButton(
            onPressed: () {
              if (questionCtl.text.trim().isEmpty || answerCtl.text.trim().isEmpty) return;
              Navigator.pop(ctx, {
                if (index != null) 'question_id': index,
                'question': questionCtl.text.trim(),
                'answer': answerCtl.text.trim(),
              });
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (payload != null) {
      await Api.updateFamilyQuestion(payload);
      _loadQuestions();
    }
  }

  Future<void> _showMedicineDialog({Map<String, dynamic>? medicine}) async {
    final idCtl =
        TextEditingController(text: medicine != null ? medicine['id'] : '');
    final descCtl = TextEditingController(
        text: medicine != null ? medicine['description'] : '');
    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(medicine == null ? '新增药品' : '编辑药品'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: idCtl, decoration: const InputDecoration(labelText: '药品编号')),
            TextField(
              controller: descCtl,
              decoration: const InputDecoration(labelText: '说明'),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          ElevatedButton(
            onPressed: () {
              final medId = idCtl.text.trim();
              if (medId.isEmpty) return;
              Navigator.pop(ctx, {
                'med_id': medId,
                'description': descCtl.text.trim(),
              });
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (payload != null) {
      await Api.updateMedicine(payload);
      _loadMedicine();
    }
  }

  Future<void> _deleteMedicine(String medId) async {
    await Api.deleteMedicine(medId);
    _loadMedicine();
  }

  Future<void> _deletePhoto(String photoId) async {
    await Api.deletePhotoInfo(photoId);
    _loadPhotoMemories();
  }

  Future<void> _deleteQuestion(int index) async {
    await Api.deleteFamilyQuestion(index);
    _loadQuestions();
  }

  Future<void> _toggleSchedule(Map<String, dynamic> schedule, bool? value) async {
    await Api.upsertSchedule({
      'schedule_id': schedule['id'],
      'time': schedule['time'],
      'event': schedule['event'],
      'completed': value ?? false,
    });
    _loadSchedule();
  }

  Future<void> _deleteSchedule(int id) async {
    await Api.deleteSchedule(id);
    _loadSchedule();
  }

  Future<void> _showScheduleDialog({
    Map<String, dynamic>? schedule,
    String? initialTime,
    String? initialEvent,
  }) async {
    final timeCtl = TextEditingController(
        text: schedule != null ? schedule['time'] : (initialTime ?? ''));
    final eventCtl = TextEditingController(
        text: schedule != null ? schedule['event'] : (initialEvent ?? ''));
    bool completed = schedule != null ? (schedule['completed'] ?? false) : false;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(schedule == null ? '新增日程' : '编辑日程'),
        content: StatefulBuilder(
          builder: (context, setStateBuilder) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: timeCtl, decoration: const InputDecoration(labelText: '时间')),
              TextField(controller: eventCtl, decoration: const InputDecoration(labelText: '事件')),
              CheckboxListTile(
                value: completed,
                onChanged: (value) =>
                    setStateBuilder(() => completed = value ?? false),
                title: const Text('已完成'),
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          ElevatedButton(
            onPressed: () {
              final payload = {
                if (schedule != null) 'schedule_id': schedule['id'],
                'time': timeCtl.text.trim(),
                'event': eventCtl.text.trim(),
                'completed': completed,
              };
              Navigator.pop(ctx, payload);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );

    if (result != null) {
      await Api.upsertSchedule(result);
      _loadSchedule();
    }
  }

  Widget _buildFaceTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              ElevatedButton.icon(
                onPressed: () => _showFaceDialog(),
                icon: const Icon(Icons.person_add),
                label: const Text('新增成员'),
              ),
              const Spacer(),
              IconButton(
                onPressed: _loadFaceInfo,
                icon: const Icon(Icons.refresh),
                tooltip: '刷新成员列表',
              )
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _faces.isEmpty
                  ? const Center(child: Text('暂无家庭成员人脸数据'))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _faces.length,
                      itemBuilder: (_, index) {
                        final face = _faces[index];
                        final memberId = (face['id'] ?? '').toString();
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          child: ListTile(
                            leading: _buildMemberAvatar(face),
                            title: Text(face['id'] ?? '未知'),
                            subtitle: Text(face['description'] ?? '暂无描述'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: '上传/更换照片',
                                  icon: const Icon(Icons.photo_camera),
                                  onPressed: memberId.isEmpty
                                      ? null
                                      : () => _pickAndSaveMemberPhoto(memberId),
                                ),
                                IconButton(
                                  tooltip: '移除照片',
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: memberId.isEmpty
                                      ? null
                                      : () => _clearMemberPhoto(memberId),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit),
                                  onPressed: () => _showFaceDialog(face: face),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildScheduleTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('新增日程'),
                onPressed: () => _showScheduleDialog(),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: '刷新日程',
                onPressed: _loadSchedule,
              )
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _schedules.isEmpty
                  ? const Center(child: Text('当前没有安排'))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _schedules.length,
                      itemBuilder: (_, index) {
                        final schedule = _schedules[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          child: ListTile(
                            leading: Checkbox(
                              value: schedule['completed'] ?? false,
                              onChanged: (value) =>
                                  _toggleSchedule(schedule, value),
                            ),
                            title: Text('${schedule['time']} - ${schedule['event']}'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit),
                                  onPressed: () =>
                                      _showScheduleDialog(schedule: schedule),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete),
                                  onPressed: () =>
                                      _deleteSchedule(schedule['id']),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildMemoryTab() {
    final spinner = _loading && _photoMemories.isEmpty && _questions.isEmpty;

    return spinner
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: () async {
              await _loadPhotoMemories();
              await _loadQuestions();
            },
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              children: [
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _showPhotoDialog(),
                      icon: const Icon(Icons.add_a_photo),
                      label: const Text('新增回忆照片'),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      tooltip: '刷新回忆数据',
                      onPressed: _loadPhotoMemories,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_photoMemories.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Center(child: Text('暂无回忆照片')),
                  )
                else
                  ..._photoMemories.map(
                    (item) {
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
                                Text('日期: ${item['event_date']}',
                                    style: const TextStyle(fontSize: 12)),
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

                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _showMemoryDialog(),
                      icon: const Icon(Icons.add_comment),
                      label: const Text('新增记忆问答'),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      tooltip: '刷新问答',
                      onPressed: _loadQuestions,
                    ),
                  ],
                ),
                if (_questions.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Center(child: Text('暂无记忆问答')),
                  )
                else
                  ...List.generate(_questions.length, (index) {
                    final item = _questions[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      child: ListTile(
                        title: Text('Q${index + 1} ${item['question'] ?? ''}'),
                        subtitle: Text(item['answer'] ?? ''),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () => _showMemoryDialog(question: item, index: index),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed: () => _deleteQuestion(index),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
              ],
            ),
          );
  }

  Widget _buildMedicineTab() {
    final entries = _medicines.entries
        .map((e) => {'id': e.key, ...Map<String, dynamic>.from(e.value)})
        .toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              ElevatedButton.icon(
                onPressed: () => _showMedicineDialog(),
                icon: const Icon(Icons.add),
                label: const Text('新增药品'),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: '刷新药品',
                onPressed: _loadMedicine,
              )
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : entries.isEmpty
                  ? const Center(child: Text('暂无药品记录'))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: entries.length,
                      itemBuilder: (_, index) {
                        final entry = entries[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          child: ListTile(
                            title: Text(entry['id'] ?? ''),
                            subtitle:
                                Text(entry['description'] ?? '暂无说明'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit),
                                  onPressed: () =>
                                      _showMedicineDialog(medicine: entry),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete),
                                  onPressed: () =>
                                      _deleteMedicine(entry['id'] ?? ''),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '家庭成员'),
            Tab(text: '日程'),
            Tab(text: '记忆库'),
            Tab(text: '药品'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildFaceTab(),
              _buildScheduleTab(),
              _buildMemoryTab(),
              _buildMedicineTab(),
            ],
          ),
        ),
      ],
    );
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
      return uploaded['asset_path']?.toString() ?? uploaded['file_path']?.toString();
    }
    return null;
  }

}