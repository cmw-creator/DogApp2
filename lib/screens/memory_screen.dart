import 'package:flutter/material.dart';
import '../services/api.dart';

class MemoryScreen extends StatefulWidget {
  const MemoryScreen({Key? key}) : super(key: key);

  @override
  State<MemoryScreen> createState() => _MemoryScreenState();
}

class _MemoryScreenState extends State<MemoryScreen> {
  List<Map<String, dynamic>> memories = [];
  bool _loading = false;
  String _viewMode = 'grid'; // 'grid' 或 'timeline'

  @override
  void initState() {
    super.initState();
    _loadMemories();
  }

  Future<void> _loadMemories() async {
    setState(() => _loading = true);
    try {
      // 尝试从API获取照片信息
      final photoData = await _getPhotoInfo();
      
      if (photoData != null && photoData.isNotEmpty) {
        // 将API数据转换为回忆格式
        final List<Map<String, dynamic>> loadedMemories = [];
        photoData.forEach((key, value) {
          loadedMemories.add({
            'id': key,
            'title': _extractTitle(value['description'] ?? ''),
            'description': value['description'] ?? '',
            'date': value['update_time'] ?? '',
            'photo_id': key,
            'media_type': 'image',
          });
        });
        setState(() => memories = loadedMemories);
      } else {
        // 如果没有API数据，使用示例数据
        setState(() {
          memories = [
            {
              'id': 'photo_00001',
              'date': '2023-12-25',
              'title': '圣诞节家庭聚会',
              'description': '全家一起装饰圣诞树，共享丰盛晚餐',
              'media_type': 'image',
            },
            {
              'id': 'photo_00002',
              'date': '2023-11-20',
              'title': '生日庆祝',
              'description': '为家人庆祝生日，大家一起唱生日歌',
              'media_type': 'image',
            },
            {
              'id': 'photo_00003',
              'date': '2023-10-15',
              'title': '秋游',
              'description': '全家一起去公园看秋叶，天气很好',
              'media_type': 'image',
            },
          ];
        });
      }
    } catch (e) {
      // 出错时使用示例数据
      setState(() {
    memories = [
      {
            'id': 'photo_00001',
        'date': '2023-12-25',
        'title': '圣诞节家庭聚会',
        'description': '全家一起装饰圣诞树，共享丰盛晚餐',
        'media_type': 'image',
      },
    ];
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<Map<String, dynamic>?> _getPhotoInfo() async {
    try {
      final resp = await Api.getPhotoInfo();
      return resp;
    } catch (_) {
      return null;
    }
  }

  String _extractTitle(String description) {
    if (description.isEmpty) return '美好回忆';
    // 取前10个字符作为标题
    if (description.length <= 10) return description;
    return '${description.substring(0, 10)}...';
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '未知日期';
    try {
      // 处理 "2023-12-25" 或 "2023-12-25 14:30:00" 格式
      final datePart = dateStr.split(' ')[0];
      final parts = datePart.split('-');
      if (parts.length == 3) {
        return '${parts[0]}年${int.parse(parts[1])}月${int.parse(parts[2])}日';
      }
      return dateStr;
    } catch (_) {
      return dateStr;
    }
  }

  List<Map<String, dynamic>> _groupByDate() {
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (var memory in memories) {
      final date = memory['date']?.toString().split(' ')[0] ?? '未知';
      if (!grouped.containsKey(date)) {
        grouped[date] = [];
      }
      grouped[date]!.add(memory);
    }
    
    // 转换为列表并按日期排序
    final result = grouped.entries
        .map((e) => {'date': e.key, 'items': e.value})
        .toList();
    result.sort((a, b) {
      final dateA = a['date'] as String;
      final dateB = b['date'] as String;
      return dateB.compareTo(dateA);
    });
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return RefreshIndicator(
      onRefresh: _loadMemories,
      child: CustomScrollView(
        slivers: [
          // 顶部标题栏
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Icon(
                    Icons.photo_library,
                    color: Colors.lightBlue.shade700,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '家庭回忆',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade900,
                          ),
                        ),
                        Text(
                          '珍藏的美好时光',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 视图切换按钮
                  IconButton(
                    icon: Icon(
                      _viewMode == 'grid' ? Icons.view_list : Icons.grid_view,
                      color: Colors.lightBlue.shade700,
                    ),
                    onPressed: () {
                      setState(() {
                        _viewMode = _viewMode == 'grid' ? 'timeline' : 'grid';
                      });
                    },
                    tooltip: _viewMode == 'grid' ? '切换到时间线' : '切换到网格',
                  ),
                ],
              ),
            ),
          ),
          
          // 内容区域
          if (_loading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (memories.isEmpty)
            SliverFillRemaining(
              child: _buildEmptyState(theme),
            )
          else if (_viewMode == 'grid')
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.85,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _buildMemoryCard(memories[index], theme),
                  childCount: memories.length,
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final groups = _groupByDate();
                    if (index < groups.length) {
                      final group = groups[index];
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (index > 0) const SizedBox(height: 16),
                          _buildDateHeader(group['date'], theme),
                          const SizedBox(height: 12),
                          ...(group['items'] as List).map(
                            (item) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _buildMemoryCard(item, theme, isTimeline: true),
                            ),
                          ),
                        ],
                      );
                    }
                    return null;
                  },
                  childCount: _groupByDate().length,
                ),
              ),
            ),
          
          const SliverToBoxAdapter(
            child: SizedBox(height: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.photo_library_outlined,
            size: 80,
            color: Colors.lightBlue.shade200,
          ),
          const SizedBox(height: 24),
          Text(
            '还没有回忆',
            style: theme.textTheme.titleLarge?.copyWith(
              color: Colors.blue.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '美好的回忆会在这里展示',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.blue.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateHeader(String date, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.lightBlue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.lightBlue.shade200),
      ),
      child: Text(
        _formatDate(date),
        style: theme.textTheme.titleSmall?.copyWith(
          color: Colors.blue.shade800,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildMemoryCard(Map<String, dynamic> memory, ThemeData theme, {bool isTimeline = false}) {
    final cardHeight = isTimeline ? null : null;
    
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200, width: 1),
      ),
      child: InkWell(
        onTap: () => _showMemoryDetail(memory, theme),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: cardHeight,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Colors.white,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 图片占位符或实际图片
              Expanded(
                flex: isTimeline ? 0 : 3,
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.lightBlue.shade100,
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // 图片占位符
                      Center(
                        child: Icon(
                          Icons.photo,
                          size: isTimeline ? 40 : 60,
                          color: Colors.lightBlue.shade300,
                        ),
                      ),
                      // 如果有实际图片URL，可以在这里显示
                      // Image.network(imageUrl, fit: BoxFit.cover)
                    ],
                  ),
                ),
              ),
              if (!isTimeline) const SizedBox(height: 12),
              // 标题
              Text(
                memory['title'] ?? '美好回忆',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade900,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              // 描述
              Expanded(
                flex: isTimeline ? 0 : 2,
                child: Text(
                  memory['description'] ?? '',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.blue.shade700,
                  ),
                  maxLines: isTimeline ? 2 : 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 8),
              // 日期
              Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 14,
                    color: Colors.blue.shade600,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _formatDate(memory['date']?.toString()),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.blue.shade600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMemoryDetail(Map<String, dynamic> memory, ThemeData theme) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          memory['title'] ?? '美好回忆',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 图片预览区域
              Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.lightBlue.shade100,
                ),
                child: Center(
                  child: Icon(
                    Icons.photo,
                    size: 80,
                    color: Colors.lightBlue.shade300,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 16,
                    color: Colors.blue.shade600,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _formatDate(memory['date']?.toString()),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.blue.shade700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                memory['description'] ?? '',
                style: theme.textTheme.bodyLarge,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }
}