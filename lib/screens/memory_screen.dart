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
          final Map<String, dynamic> item = Map<String, dynamic>.from(value);
          final description = item['description']?.toString() ?? '';
          final title = item['title']?.toString() ?? '';
          final eventDate = item['event_date']?.toString();
          final updateTime = item['update_time']?.toString();
          final imageFile = item['image_file']?.toString() ?? '';
          final location = item['location']?.toString() ?? '';

          loadedMemories.add({
            'id': key,
            'photo_id': key,
            'title': title.isNotEmpty ? title : _extractTitle(description),
            'description': description,
            'date': eventDate?.isNotEmpty == true ? eventDate : (updateTime ?? ''),
            'media_type': 'image',
            'image_url': Api.assetUrl(imageFile),
            'location': location,
            'tags': _toStringList(item['tags']),
            'people': _toStringList(item['people']),
          });
        });

        loadedMemories.sort((a, b) => (b['date'] ?? '').compareTo(a['date'] ?? ''));
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

  List<String> _toStringList(dynamic value) {
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }
    if (value is String && value.isNotEmpty) {
      return value.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    }
    return [];
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
    final scheme = theme.colorScheme;
    
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
                    color: scheme.primary,
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
                            color: scheme.onSurface,
                          ),
                        ),
                        Text(
                          '珍藏的美好时光',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 视图切换按钮
                  IconButton(
                    icon: Icon(
                      _viewMode == 'grid' ? Icons.view_list : Icons.grid_view,
                      color: scheme.primary,
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
                  // 增加单元格可用高度，避免内容溢出
                  childAspectRatio: 0.72,
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
    final scheme = theme.colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.photo_library_outlined,
            size: 80,
            color: scheme.onSurface.withOpacity(0.35),
          ),
          const SizedBox(height: 24),
          Text(
            '还没有回忆',
            style: theme.textTheme.titleLarge?.copyWith(
              color: scheme.onSurface,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '美好的回忆会在这里展示',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateHeader(String date, ThemeData theme) {
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Text(
        _formatDate(date),
        style: theme.textTheme.titleSmall?.copyWith(
          color: scheme.onSurface,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildMemoryCard(Map<String, dynamic> memory, ThemeData theme, {bool isTimeline = false}) {
    final scheme = theme.colorScheme;
    final imageUrl = memory['image_url']?.toString() ?? '';
    final tags = _toStringList(memory['tags']);
    final displayTags = tags.length > 3 ? tags.sublist(0, 3) : tags;
    final imageHeight = isTimeline ? 200.0 : 140.0;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.dividerColor, width: 1),
      ),
      child: InkWell(
        onTap: () => _showMemoryDetail(memory, theme),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: scheme.surface,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 图片占位符或实际图片
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: _buildImage(imageUrl, height: imageHeight),
              ),
              const SizedBox(height: 12),
              // 标题
              Text(
                memory['title'] ?? '美好回忆',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: scheme.onSurface,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              // 描述
              Text(
                memory['description'] ?? '',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
                maxLines: isTimeline ? 3 : 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (isTimeline && displayTags.isNotEmpty) ...[
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: -4,
                  children: displayTags
                      .map((t) => Chip(
                            label: Text(t, style: const TextStyle(fontSize: 11)),
                            backgroundColor: scheme.surfaceContainerHighest,
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                          ))
                      .toList(),
                ),
              ],
              const SizedBox(height: 8),
              // 日期
              Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 14,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _formatDate(memory['date']?.toString()),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
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
    final scheme = theme.colorScheme;
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
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _buildImage(memory['image_url']?.toString(), height: 220),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 16,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _formatDate(memory['date']?.toString()),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                memory['description'] ?? '',
                style: theme.textTheme.bodyLarge,
              ),
              if ((memory['location']?.toString().isNotEmpty ?? false)) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.place, size: 18, color: scheme.onSurfaceVariant),
                    const SizedBox(width: 6),
                    Text(memory['location'].toString()),
                  ],
                ),
              ],
              if (_toStringList(memory['people']).isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: -6,
                  children: _toStringList(memory['people'])
                      .map((p) => Chip(
                            avatar: const Icon(Icons.person, size: 16),
                            label: Text(p),
                          ))
                      .toList(),
                ),
              ],
              if (_toStringList(memory['tags']).isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: -6,
                  children: _toStringList(memory['tags'])
                      .map((t) => Chip(
                            label: Text('#$t'),
                            backgroundColor: scheme.surfaceContainerHighest,
                          ))
                      .toList(),
                ),
              ],
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

  Widget _buildImage(String? url, {double height = 180}) {
    return Container(
      height: height,
      width: double.infinity,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: url != null && url.isNotEmpty
          ? Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Center(
                child: Icon(
                  Icons.broken_image,
                  size: 48,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.35),
                ),
              ),
            )
          : Center(
              child: Icon(
                Icons.photo,
                size: 64,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.35),
              ),
            ),
    );
  }
}