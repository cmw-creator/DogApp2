import 'package:flutter/material.dart';
import '../services/api.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({Key? key}) : super(key: key);

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen>
    with SingleTickerProviderStateMixin {
  TabController? _tabController;
  List<Map<String, dynamic>> _posts = [];
  bool _loadingPosts = false;

  List<Map<String, String>> get _tips => const [
        {
          'title': '保持日常作息',
          'subtitle': '固定的起居时间能降低焦虑，让患者更有安全感。',
          'icon': '🕒',
          'content': '规律的作息是照护患者的基础：\n\n'
              '• 每天同一时间起床、进餐、午睡、就寝，减少变化\n'
              '• 固定的日程能帮助患者预期接下来会发生什么，降低焦虑和混乱\n'
              '• 在关键时段（如早晨、傍晚）可能出现"黄昏综合征"，准备充足\n'
              '• 保留患者喜欢的日常活动（如晨间散步、听音乐）作为安定感来源',
        },
        {
          'title': '简化指令',
          'subtitle': '一次只说一件事，使用短句和温和语气。',
          'icon': '💬',
          'content': '有效沟通能减少误解和挫折感：\n\n'
              '• 一次只下达一个指令，避免多步骤的复杂要求\n'
              '• 使用简短、熟悉的词汇，说话放慢速度\n'
              '• 使用肯定式而非否定式（"坐下"而非"别站着"）\n'
              '• 给患者足够的反应时间，耐心等待\n'
              '• 保持温和语气，这能传递安全感',
        },
        {
          'title': '视觉提示',
          'subtitle': '用图片、颜色或手势来辅助沟通，减少误解。',
          'icon': '👀',
          'content': '非语言沟通往往更有效：\n\n'
              '• 贴上清晰的图片或符号标记日常物品和房间\n'
              '• 用不同颜色区分区域或物品（如红色标记浴室，蓝色标记卧室）\n'
              '• 配合手势和身体语言加强理解\n'
              '• 指向或轻轻引导患者，而不仅仅是口头指示\n'
              '• 保持环境清晰，减少视觉混乱',
        },
        {
          'title': '保持陪伴',
          'subtitle': '短时多次陪伴比长时间一次性更有效，保持眼神交流。',
          'icon': '🤝',
          'content': '有意义的陪伴能增强安全感和连接：\n\n'
              '• 每天多次短暂的相处比一次长时间更能维持情感连接\n'
              '• 保持眼神交流和身体接近，这传递了关注和信任\n'
              '• 参与患者感兴趣的活动，而不是被动等待\n'
              '• 即使患者不认识你，陪伴本身也能缓解孤独感\n'
              '• 在患者感到困惑或恐惧时，保持冷静和温暖的存在',
        },
        {
          'title': '安全第一',
          'subtitle': '移除锋利物品，浴室防滑，出门佩戴定位设备。',
          'icon': '🛡️',
          'content': '安全的环境是照护的前提：\n\n'
              '• 移除锋利、易碎或危险的物品\n'
              '• 浴室使用防滑垫，安装扶手，避免跌伤\n'
              '• 锁好车钥匙、门窗，防止患者走失\n'
              '• 为患者配备定位手环或手机，方便紧急定位\n'
              '• 定期检查用药，防止误服\n'
              '• 保持清道，减少绊倒风险',
        },
        {
          'title': '音乐与回忆',
          'subtitle': '播放熟悉的音乐或翻看旧照片，能唤起积极情绪。',
          'icon': '🎵',
          'content': '回忆活动能唤起患者的积极情绪：\n\n'
              '• 播放患者年轻时喜欢的音乐或广播剧\n'
              '• 翻看旧照片，讲述往事，帮助唤起记忆\n'
              '• 看患者喜爱的老电影或电视剧\n'
              '• 进行简单的手工活动（如折纸、简单烹饪）\n'
              '• 这些活动能提升心情，减少行为问题',
        },
        {
          'title': '情绪接纳',
          'subtitle': '先共情情绪，再温柔引导，避免直接否定。',
          'icon': '💛',
          'content': '接纳患者的情绪能建立信任：\n\n'
              '• 不要直接否定患者的感受（"你没有失去钱包"反而会加重焦虑）\n'
              '• 先用共情语言（"我明白你很担心"），再温柔转向其他话题\n'
              '• 验证患者的情绪，即使事实可能不同\n'
              '• 避免争论或纠正患者，这会导致对立\n'
              '• 如果患者变得激动，给予空间和时间，保持冷静',
        },
        {
          'title': '结构化环境',
          'subtitle': '物品放置固定，贴标签；减少环境噪音与混乱。',
          'icon': '📌',
          'content': '有序的环境能减少认知负荷：\n\n'
              '• 重要物品（眼镜、手机）放在固定位置，使用颜色标签\n'
              '• 每个房间功能明确，避免堆放物品\n'
              '• 减少电视、音乐、谈话等同时进行带来的噪音\n'
              '• 保持照明充足，避免昏暗或刺眼\n'
              '• 季节性调整装饰，但保持核心结构不变',
        },
        {
          'title': '运动与阳光',
          'subtitle': '每天散步或轻运动 20-30 分钟，帮助睡眠与心情。',
          'icon': '🌞',
          'content': '身体活动对认知和心理健康至关重要：\n\n'
              '• 每天安排 20-30 分钟的温和活动（散步、打太极、简单运动）\n'
              '• 上午或中午进行室外活动，接受自然光有助于调节睡眠周期\n'
              '• 运动能改善睡眠质量，减少夜间躁动\n'
              '• 与患者一起运动，既是陪伴也是健康投资\n'
              '• 根据患者体能调整强度，循序渐进',
        },
        {
          'title': '照护者自我照顾',
          'subtitle': '照护者也需要休息与支持，保持身心健康。',
          'icon': '🌱',
          'content': '照护者的健康直接影响患者的照护质量：\n\n'
              '• 寻求家庭成员、朋友或专业照护者的帮助，定期休息\n'
              '• 参加照护者支持小组，与他人分享经历和建议\n'
              '• 保持自己的兴趣和社交活动，避免完全放弃个人生活\n'
              '• 定期进行身体检查，管理自己的健康\n'
              '• 学会识别照护压力的迹象（疲惫、焦虑、抑郁），及时寻求帮助',
        },
      ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadPosts();
  }

  Future<void> _loadPosts() async {
    setState(() => _loadingPosts = true);
    final data = await Api.getCommunityPosts();
    if (data != null) {
      setState(() => _posts = data.map((e) => Map<String, dynamic>.from(e)).toList());
    }
    setState(() => _loadingPosts = false);
  }

  Future<void> _createPost() async {
    final titleCtl = TextEditingController();
    final contentCtl = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('发布帖子'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: titleCtl, decoration: const InputDecoration(labelText: '标题')),
            TextField(controller: contentCtl, decoration: const InputDecoration(labelText: '内容'), maxLines: 4),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          ElevatedButton(
            onPressed: () async {
              final ok = await Api.createCommunityPost({
                'title': titleCtl.text.trim(),
                'content': contentCtl.text.trim(),
                'author': '家庭成员',
              });
              Navigator.pop(ctx, ok);
            },
            child: const Text('发布'),
          ),
        ],
      ),
    );
    if (result == true) {
      await _loadPosts();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('发布成功')));
    }
  }

  Future<void> _showComments(Map<String, dynamic> post) async {
    final comments = List<Map<String, dynamic>>.from(post['comments'] ?? []);
    final ctl = TextEditingController();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: SizedBox(
          height: 400,
          child: Column(
            children: [
              Expanded(
                child: ListView.builder(
                  itemCount: comments.length,
                  itemBuilder: (_, i) {
                    final c = comments[i];
                    return ListTile(
                      title: Text(c['author'] ?? ''),
                      subtitle: Text(c['text'] ?? ''),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: [
                    Expanded(child: TextField(controller: ctl, decoration: const InputDecoration(hintText: '发表评论'))),
                    IconButton(
                      icon: const Icon(Icons.send),
                      onPressed: () async {
                        final text = ctl.text.trim();
                        if (text.isEmpty) return;
                        final ok = await Api.commentCommunityPost(post['id'] as int, text);
                        if (ok) {
                          Navigator.pop(ctx);
                          await _loadPosts();
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('评论成功')));
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('评论失败')));
                        }
                      },
                    )
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _likePost(int postId) async {
    final likes = await Api.likeCommunityPost(postId);
    if (likes != null) {
      await _loadPosts();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          tabs: const [Tab(text: '论坛'), Tab(text: '小知识')],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              // 论坛页
              Stack(
                children: [
                  _loadingPosts
                      ? const Center(child: CircularProgressIndicator())
                      : RefreshIndicator(
                          onRefresh: _loadPosts,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(12),
                            itemCount: _posts.length,
                            itemBuilder: (ctx, idx) {
                              final p = _posts[idx];
                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 8),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(child: Text(p['title'] ?? '', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold))),
                                          Text(p['author'] ?? '', style: theme.textTheme.bodySmall),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(p['content'] ?? ''),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          IconButton(icon: const Icon(Icons.thumb_up), onPressed: () => _likePost(p['id'] as int)),
                                          Text('${p['likes'] ?? 0}'),
                                          const SizedBox(width: 16),
                                          IconButton(icon: const Icon(Icons.comment), onPressed: () => _showComments(p)),
                                          Text('${(p['comments'] as List).length}'),
                                        ],
                                      )
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                  Positioned(
                    right: 16,
                    bottom: 16,
                    child: FloatingActionButton(
                      onPressed: _createPost,
                      child: const Icon(Icons.add),
                    ),
                  ),
                ],
              ),
              // 小知识页：保留原 tips 列表
              ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _tips.length,
                itemBuilder: (context, index) {
                  final tip = _tips[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: GestureDetector(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (ctx) => _TipDetailPage(tip: tip),
                          ),
                        );
                      },
                      child: Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: Colors.grey.shade200, width: 1),
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            color: Colors.white,
                          ),
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(tip['icon'] ?? '💡', style: const TextStyle(fontSize: 28)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      tip['title'] ?? '',
                                      style: theme.textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue.shade900,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      tip['subtitle'] ?? '',
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        color: Colors.blue.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TipDetailPage extends StatelessWidget {
  final Map<String, String> tip;

  const _TipDetailPage({Key? key, required this.tip}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(tip['title'] ?? ''),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 顶部卡片：标题、图标、摘要
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.grey.shade200, width: 1),
              ),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: Colors.white,
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tip['icon'] ?? '💡',
                          style: const TextStyle(fontSize: 48),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tip['title'] ?? '',
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade900,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                tip['subtitle'] ?? '',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: Colors.blue.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // 内容卡片：详细信息
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.shade200, width: 1),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SelectableText(
                  tip['content'] ?? '',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: Colors.grey.shade800,
                    height: 1.6,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // 温馨提示
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                border: Border.all(color: Colors.amber.shade200, width: 1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lightbulb, color: Colors.amber.shade700, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '温馨提示：每个患者情况不同，请根据实际情况灵活调整。如有疑问，建议咨询专业医护人员。',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.amber.shade800,
                      ),
                    ),
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
