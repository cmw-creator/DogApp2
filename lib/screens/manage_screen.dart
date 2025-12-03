import 'package:flutter/material.dart';
import '../services/api.dart';

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
  Map<String, dynamic> _medicines = {};
  List<Map<String, dynamic>> _schedules = [];

  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _refreshAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _refreshAll() async {
    setState(() => _loading = true);
    await Future.wait([
      _loadFaceInfo(),
      _loadQuestions(),
      _loadMedicine(),
      _loadSchedule(),
    ]);
    setState(() => _loading = false);
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

  Future<void> _loadQuestions() async {
    final data = await Api.getFamilyQuestions();
    if (data != null) {
      setState(() => _questions =
          data.map((e) => Map<String, dynamic>.from(e)).toList());
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

  Future<void> _deleteQuestion(int index) async {
    await Api.deleteFamilyQuestion(index);
    _loadQuestions();
  }

  Future<void> _deleteMedicine(String medId) async {
    await Api.deleteMedicine(medId);
    _loadMedicine();
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

  Future<void> _showScheduleDialog({Map<String, dynamic>? schedule}) async {
    final timeCtl =
        TextEditingController(text: schedule != null ? schedule['time'] : '');
    final eventCtl =
        TextEditingController(text: schedule != null ? schedule['event'] : '');
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
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          child: ListTile(
                            title: Text(face['id'] ?? '未知'),
                            subtitle: Text(face['description'] ?? '暂无描述'),
                            trailing: IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () => _showFaceDialog(face: face),
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
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              ElevatedButton.icon(
                onPressed: () => _showMemoryDialog(),
                icon: const Icon(Icons.add),
                label: const Text('新增记忆'),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: '刷新记忆库',
                onPressed: _loadQuestions,
              )
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _questions.isEmpty
                  ? const Center(child: Text('暂无记忆问答'))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _questions.length,
                      itemBuilder: (_, index) {
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
                                  onPressed: () =>
                                      _showMemoryDialog(question: item, index: index),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete),
                                  onPressed: () => _deleteQuestion(index),
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
}