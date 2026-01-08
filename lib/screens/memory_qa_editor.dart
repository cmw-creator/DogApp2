import 'package:flutter/material.dart';
import '../services/api.dart';

class MemoryQaEditorScreen extends StatefulWidget {
  const MemoryQaEditorScreen({Key? key}) : super(key: key);

  @override
  State<MemoryQaEditorScreen> createState() => _MemoryQaEditorScreenState();
}

class _MemoryQaEditorScreenState extends State<MemoryQaEditorScreen> {
  bool _loading = false;
  List<Map<String, dynamic>> _questions = [];

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    setState(() => _loading = true);
    final data = await Api.getFamilyQuestions();
    if (!mounted) return;
    setState(() {
      _questions = (data ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      _loading = false;
    });
  }

  Future<void> _deleteQuestion(int index) async {
    await Api.deleteFamilyQuestion(index);
    _loadQuestions();
  }

  Future<void> _showMemoryDialog({Map<String, dynamic>? question, int? index}) async {
    final questionCtl = TextEditingController(text: question != null ? question['question'] : '');
    final answerCtl = TextEditingController(text: question != null ? question['answer'] : '');
    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(question == null ? '新增记忆条目' : '编辑记忆条目'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: questionCtl,
              decoration: const InputDecoration(labelText: '问题'),
            ),
            TextField(
              controller: answerCtl,
              decoration: const InputDecoration(labelText: '回答'),
            ),
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
          )
        ],
      ),
    );

    if (payload != null) {
      await Api.updateFamilyQuestion(payload);
      _loadQuestions();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('问答记忆编辑'),
        actions: [
          IconButton(onPressed: _loadQuestions, icon: const Icon(Icons.refresh))
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showMemoryDialog(),
        icon: const Icon(Icons.add_comment),
        label: const Text('新增问答'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _questions.isEmpty
              ? const Center(child: Text('暂无记忆问答'))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
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
                  },
                ),
    );
  }
}
