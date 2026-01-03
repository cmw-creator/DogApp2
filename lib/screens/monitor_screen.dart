import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../services/api.dart';
import '../services/webrtc_service.dart';

class MonitorScreen extends StatefulWidget {
  const MonitorScreen({Key? key}) : super(key: key);

  @override
  State<MonitorScreen> createState() => _MonitorScreenState();
}

class _MonitorScreenState extends State<MonitorScreen> {
  Map<String, dynamic>? _activityStats;
  Map<String, dynamic>? _dogLocation;
  Map<String, dynamic>? _companionStatus;
  bool _isLoading = true;
  
  // WebRTC 相关
  WebRTCService? _webrtcService;
  List<String> _availableVideos = [];
  bool _isStreaming = false;
  String? _selectedVideoFilename;
  bool _videoLoading = false;
  String? _errorMessage;
  RTCVideoRenderer? _remoteRenderer;

  @override
  void initState() {
    super.initState();
    _loadMonitorData();
    _initializeWebRTC();
  }

  @override
  void dispose() {
    _webrtcService?.dispose();
    _remoteRenderer?.dispose();
    super.dispose();
  }

  Future<void> _initializeWebRTC() async {
    try {
      _webrtcService = WebRTCService(serverUrl: 'http://localhost:5001');
      
      // 设置回调
      _webrtcService!.onRemoteStream = (stream) {
        if (mounted) {
          setState(() {
            _remoteRenderer = _webrtcService!.getRemoteRenderer();
          });
        }
      };
      
      _webrtcService!.onError = (error) {
        if (mounted) {
          setState(() {
            _errorMessage = error;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('错误: $error')),
          );
        }
      };
      
      _webrtcService!.onDisconnected = () {
        if (mounted) {
          setState(() {
            _isStreaming = false;
          });
        }
      };
      
      // 初始化
      await _webrtcService!.initialize();
      
      // 加载视频列表
      await _loadAvailableVideos();
      
    } catch (e) {
      print('初始化 WebRTC 失败: $e');
      if (mounted) {
        setState(() {
          _errorMessage = '初始化失败: $e';
        });
      }
    }
  }

  Future<void> _loadMonitorData() async {
    try {
      final stats = await Api.getActivityStats();
      final location = await Api.getDogLocation();
      final companion = await Api.getCompanionStatus();

      if (mounted) {
        setState(() {
          _activityStats = stats;
          _dogLocation = location;
          _companionStatus = companion;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadAvailableVideos() async {
    try {
      if (_webrtcService != null) {
        final videos = await _webrtcService!.getAvailableVideos();
        if (mounted) {
          setState(() {
            _availableVideos = videos;
            if (_availableVideos.isNotEmpty && _selectedVideoFilename == null) {
              _selectedVideoFilename = _availableVideos[0];
            }
          });
        }
      }
    } catch (e) {
      print('加载视频列表失败: $e');
    }
  }

  Future<void> _startVideoStream() async {
    if (_selectedVideoFilename == null || _webrtcService == null) return;
    
    setState(() => _videoLoading = true);
    
    try {
      await _webrtcService!.startStream(_selectedVideoFilename!);
      if (mounted) {
        setState(() {
          _isStreaming = true;
          _videoLoading = false;
          _errorMessage = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _videoLoading = false;
          _errorMessage = '$e';
        });
      }
    }
  }

  Future<void> _stopVideoStream() async {
    if (_webrtcService == null) return;
    
    setState(() => _videoLoading = true);
    
    try {
      await _webrtcService!.stopStream();
      if (mounted) {
        setState(() {
          _isStreaming = false;
          _videoLoading = false;
          _remoteRenderer = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _videoLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Column(
        children: [
          const TabBar(tabs: [
            Tab(text: '实时'),
            Tab(text: '提醒'),
            Tab(text: '视频'),
            Tab(text: '指令'),
          ]),
          Expanded(
            child: TabBarView(children: [
              // 实时监控标签页
              _buildRealtimeTab(),
              const Center(child: Text('提醒与警报 - 占位')),
              // 视频直播标签页
              _buildVideoTab(),
              const Center(child: Text('指令发送 - 占位')),
            ]),
          )
        ],
      ),
    );
  }

  Widget _buildRealtimeTab() {
    return RefreshIndicator(
      onRefresh: _loadMonitorData,
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 陪伴状态（前置）
                  _buildCompanionStatusCard(),
                  const SizedBox(height: 20),
                  // 患者活动图表
                  _buildActivityChart(),
                  const SizedBox(height: 20),
                  // 机器狗位置
                  _buildDogLocationCard(),
                ],
              ),
            ),
    );
  }

  Widget _buildActivityChart() {
    if (_activityStats == null) {
      return const SizedBox.shrink();
    }

    final dayData = _activityStats!['day'] as Map<String, dynamic>?;
    if (dayData == null) {
      return const SizedBox.shrink();
    }

    final hourly = (dayData['hourly'] as List?)?.cast<int>() ?? [];
    if (hourly.isEmpty) {
      return const SizedBox.shrink();
    }

    // 准备图表数据
    final spots = <FlSpot>[];
    for (int i = 0; i < hourly.length; i++) {
      spots.add(FlSpot(i.toDouble(), hourly[i].toDouble()));
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '患者活动情况 (过去24小时)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 250,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: true),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 3,
                        getTitlesWidget: (value, meta) {
                          return Text('${value.toInt()}点',
                              style: const TextStyle(fontSize: 10));
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          return Text('${value.toInt()}',
                              style: const TextStyle(fontSize: 10));
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: true),
                  minX: 0,
                  maxX: 23,
                  minY: 0,
                  maxY: (hourly.isNotEmpty
                          ? hourly.reduce((a, b) => a > b ? a : b).toDouble()
                          : 10) +
                      5,
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: Colors.blue,
                      barWidth: 2,
                      dotData: const FlDotData(show: false),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            _buildActivitySummary(),
          ],
        ),
      ),
    );
  }

  Widget _buildActivitySummary() {
    if (_activityStats == null) {
      return const SizedBox.shrink();
    }

    final dayData = _activityStats!['day'] as Map<String, dynamic>?;
    final dayCount = dayData?['count'] ?? 0;

    final hourData = _activityStats!['hour'] as Map<String, dynamic>?;
    final hourCount = hourData?['count'] ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '近1小时活动: $hourCount 次',
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        Text(
          '近24小时活动: $dayCount 次',
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildDogLocationCard() {
    if (_dogLocation == null) {
      return const SizedBox.shrink();
    }

    final lat = _dogLocation!['lat'] ?? 0.0;
    final lon = _dogLocation!['lon'] ?? 0.0;
    final locationName = _dogLocation!['location_name'] ?? '未知位置';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '机器狗位置',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              '位置: $locationName',
              style: const TextStyle(fontSize: 14),
            ),
            Text(
              '坐标: $lat, $lon',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompanionStatusCard() {
    if (_companionStatus == null) {
      return const SizedBox.shrink();
    }

    final isAccompanying = _companionStatus!['is_accompanying'] ?? false;
    final timestamp = _companionStatus!['timestamp'] ?? '';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '陪伴状态',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isAccompanying ? Colors.green : Colors.red,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  isAccompanying ? '陪伴在患者身边' : '未陪伴',
                  style: TextStyle(
                    fontSize: 14,
                    color: isAccompanying ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '最后更新: $timestamp',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildVideoStreamDisplay(),
          const SizedBox(height: 20),
          _buildVideoControlPanel(),
        ],
      ),
    );
  }

  Widget _buildVideoStreamDisplay() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '机器狗摄像头直播',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (_isStreaming)
              Container(
                width: double.infinity,
                height: 300,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.black,
                ),
                child: _buildWebRTCStream(),
              )
            else
              Container(
                width: double.infinity,
                height: 300,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey[300],
                ),
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.videocam_off, size: 64, color: Colors.grey),
                      SizedBox(height: 12),
                      Text(
                        '直播未启动',
                        style: TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildWebRTCStream() {
    if (_remoteRenderer == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 12),
              const Text('正在连接视频流...'),
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  '错误: $_errorMessage',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
      );
    }
    
    return RTCVideoView(
      _remoteRenderer!,
      objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
    );
  }

  Widget _buildVideoControlPanel() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '直播控制',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (_availableVideos.isNotEmpty)
              DropdownButton<String>(
                value: _selectedVideoFilename,
                isExpanded: true,
                items: _availableVideos.map((video) {
                  return DropdownMenuItem(
                    value: video,
                    child: Text(video),
                  );
                }).toList(),
                onChanged: _isStreaming
                    ? null
                    : (value) {
                        if (value != null) {
                          setState(() => _selectedVideoFilename = value);
                        }
                      },
              )
            else
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  '未找到可用视频文件',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _videoLoading || _isStreaming || _selectedVideoFilename == null
                        ? null
                        : _startVideoStream,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('启动直播'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _videoLoading || !_isStreaming ? null : _stopVideoStream,
                    icon: const Icon(Icons.stop),
                    label: const Text('停止直播'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isStreaming ? Colors.green : Colors.grey,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _isStreaming ? '直播中...' : '直播已停止',
                  style: TextStyle(
                    color: _isStreaming ? Colors.green : Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}