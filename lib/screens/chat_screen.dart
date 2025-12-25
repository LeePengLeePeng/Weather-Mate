import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:weather_test/bloc/weather_bloc_bloc.dart';
import 'package:weather_test/data/weather_model.dart';
import 'package:weather_test/data/weather_repository.dart';
import 'package:weather_test/tool/weather_prompt_helper.dart'; // 請確認路徑是否正確

enum TaroState { idle, typing, getQuestion, thinking, answer, tapToText }

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with AutomaticKeepAliveClientMixin {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController(); // 新增：控制對話捲動

  String get _apiKey => dotenv.env['CHAT_API_KEY'] ?? '';
  static const String _modelId = 'llama-3.3-70b-versatile'; 

  TaroState _taroState = TaroState.idle;
  
  // 🔥 修改 1: 把單一字串改成列表，這樣才有記憶！
  final List<Map<String, String>> _messages = [];
  String _currentLocationName = "未知地點"; // 用來偵測地點變更

  Timer? _animationTimer;
  int _playbackId = 0; // 用來觸發 UI 重繪的 ID

  final Map<TaroState, String> _assets = {
    TaroState.idle: 'assets/idle.webp',
    TaroState.typing: 'assets/typing.webp',
    TaroState.getQuestion: 'assets/get_question.webp',
    TaroState.thinking: 'assets/thinking.webp',
    TaroState.answer: 'assets/answer.webp',
    TaroState.tapToText: 'assets/tap_to_text.webp',
  };

  @override
  void initState() {
    super.initState();
    // 預設第一句話
    _messages.add({
      'role': 'assistant',
      'content': '你好呀！我是芋圓 ☁️\n要去哪裡玩嗎？'
    });

    _focusNode.addListener(() {
      if (!_focusNode.hasFocus && (_taroState == TaroState.typing || _taroState == TaroState.tapToText)) {
        setState(() => _taroState = TaroState.idle);
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        precacheImage(AssetImage(_assets[TaroState.idle]!), context);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    precacheImage(AssetImage(_assets[TaroState.idle]!), context);
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    _animationTimer?.cancel();
    super.dispose();
  }

  String getTaroAnimation() {
    return _assets[_taroState] ?? 'assets/idle.webp';
  }

  // 🔥 保留原本的動畫邏輯
  Future<void> _replayAssetWebp(String assetPath) async {
    if (assetPath.contains('idle')) return;
    final provider = AssetImage(assetPath);
    await provider.evict();
  }

  // 🔥 保留原本的動畫邏輯
 void _playOneShotAnimation(TaroState targetState, TaroState nextState, int durationMs) async {
    _animationTimer?.cancel();
    
    // 1. 清除快取 (維持原本邏輯)
    await _replayAssetWebp(_assets[targetState]!);
    if (nextState != TaroState.idle) {
       _replayAssetWebp(_assets[nextState]!); 
    }

    if (mounted) {
      setState(() {
        _taroState = targetState;
      });
    }

    _animationTimer = Timer(Duration(milliseconds: durationMs), () {
      if (mounted) {
        // 如果原本是要接 typing，但鍵盤已經收起來了 (沒焦點)，就直接回 idle
        if (nextState == TaroState.typing && !_focusNode.hasFocus) {
          setState(() => _taroState = TaroState.idle);
        } else {
          // 正常切換到下一個狀態
          setState(() {
             _taroState = nextState;
             // _playbackId++; // 這裡不需要強制 +1，因為我們拿掉了 Key，讓 gaplessPlayback 自己處理
          });
        }
      }
    });
  }

  void _handleInputTap() {
    if (_taroState == TaroState.idle) {
      _playOneShotAnimation(TaroState.tapToText, TaroState.typing, 300);
    }
  }

  // 自動捲到底部
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  final Map<String, dynamic> _weatherToolDefinition = {
    "type": "function",
    "function": {
      "name": "get_weather_forecast",
      "description": "獲取指定城市或地區的詳細天氣預報，包括溫度、降雨機率及氣象建議。",
      "parameters": {
        "type": "object",
        "properties": {
          "location": {
            "type": "string",
            "description": "城市名稱或地區名稱，例如：'東京'、'紐約'、'新北市新店區'",
          }
        },
        "required": ["location"],
      },
    }
  };

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _taroState == TaroState.thinking) return;

    setState(() {
      _messages.add({'role': 'user', 'content': text});
    });
    _controller.clear();
    _focusNode.unfocus();
    _scrollToBottom();
    
    _playOneShotAnimation(TaroState.getQuestion, TaroState.thinking, 400);

    // 1. 準備基礎訊息
    List<Map<String, dynamic>> apiMessages = [];
    
    // 注入目前位置作為 context (選用)
    final weatherState = context.read<WeatherBlocBloc>().state;
    if (weatherState is WeatherBlocSuccess) {
      apiMessages.add({
        'role': 'system', 
        'content': "你是氣象助理芋圓。當前位置：${weatherState.weather.areaName}。${WeatherPromptHelper.generateSystemPrompt(weatherState.weather)}"
      });
    }

    // 加入歷史對話
    for (var msg in _messages) {
      if (msg['role'] == 'user' || msg['role'] == 'assistant') {
        apiMessages.add({'role': msg['role']!, 'content': msg['content']!});
      }
    }

    try {
      // --- 第一步：詢問 Groq (帶上 Tool 定義) ---
      var response = await _callGroqAPI(apiMessages, tools: [_weatherToolDefinition]);
      var message = response['choices'][0]['message'];

      // --- 第二步：檢查 AI 是否要查天氣 ---
      if (message['tool_calls'] != null) {
        for (var toolCall in message['tool_calls']) {
          final functionName = toolCall['function']['name'];
          final arguments = jsonDecode(toolCall['function']['arguments']);
          final location = arguments['location'];

          if (functionName == 'get_weather_forecast') {
            // 呼叫你寫好的 Repository！
            // 注意：這裡需要實例化 WeatherRepository 或從 Bloc 取得
            final weatherRepo = WeatherRepository(); 
            String weatherInfo = await weatherRepo.getWeatherForecastForGroq(location);

            // 將工具結果加入對話紀錄
            apiMessages.add(message); // 加入 AI 的呼叫請求
            apiMessages.add({
              'role': 'tool',
              'tool_call_id': toolCall['id'],
              'name': functionName,
              'content': weatherInfo,
            });
          }
        }

        // --- 第三步：將氣象數據餵回 AI，取得最終自然語言回覆 ---
        response = await _callGroqAPI(apiMessages);
        message = response['choices'][0]['message'];
      }

      final replyText = message['content'] ?? '...';

      if (mounted) {
        setState(() {
          _messages.add({'role': 'assistant', 'content': replyText});
        });
        _scrollToBottom();
        _playOneShotAnimation(TaroState.answer, TaroState.idle, 1500);
      }
    } catch (e) {
      print("Chat Error: $e");
      if (mounted) {
        setState(() {
           _messages.add({'role': 'assistant', 'content': '芋圓連線失敗了... 😭'});
           _taroState = TaroState.idle;
        });
        _scrollToBottom();
      }
      // 錯誤處理...
    }
  }
  
  // 輔助函式：統一呼叫 Groq API
  Future<Map<String, dynamic>> _callGroqAPI(List<Map<String, dynamic>> messages, {List<dynamic>? tools}) async {
    final url = Uri.parse('https://api.groq.com/openai/v1/chat/completions');
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json; charset=utf-8',
        'Authorization': 'Bearer $_apiKey',
      },
      body: jsonEncode({
        'model': _modelId,
        'messages': messages,
        if (tools != null) 'tools': tools,
        'tool_choice': 'auto',
        'temperature': 0.5,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } else {
      throw Exception('Groq API Error: ${response.body}');
    }
  }

  void _clearHistory() {
    // 收起鍵盤
    FocusScope.of(context).unfocus();
    _controller.clear();

    setState(() {
      // 1. 清空所有對話
      _messages.clear();
      
      // 2. 加回原本的開場白
      _messages.add({
        'role': 'assistant',
        'content': '記憶已清除！我是芋圓 ☁️\n有什麼想問的嗎？'
      });

      // 3. 重置芋圓狀態
      _taroState = TaroState.idle;
      
      // 4. 重置播放 ID (確保動畫不會因為 Key 相同而不重繪)
      _playbackId++;
    });

    // 5. 確保預載 Idle 圖
    precacheImage(AssetImage(_assets[TaroState.idle]!), context);
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isKeyboardOpen = bottomInset > 0;

    // 📏 參數設定
    const double taroRealHeight = 250; // 芋圓實際大小
    const double glassHeight = 250;    // 🔥 玻璃顯示高度 (變矮)
    const double inputHeight = 85;     // 輸入框高度

    // 文字防擋邏輯維持不變
    final double listPaddingBottom = isKeyboardOpen 
        ? inputHeight 
        : (taroRealHeight + inputHeight);

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: null,
        actions: [
          IconButton(
            icon: const Icon(Icons.cleaning_services_outlined, color: Colors.black54),
            tooltip: '清除對話',
            onPressed: () => _clearHistory(),
          ),
          const SizedBox(width: 10),
        ],
        title: const Text(
          "芋圓的氣象站",
          style: TextStyle(
            color: Color.fromARGB(255, 57, 57, 57),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              // -----------------------------------------------------
              // 第一層：對話列表
              // -----------------------------------------------------
              Positioned.fill(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: EdgeInsets.only(
                    top: 60,
                    left: 20,
                    right: 20,
                    bottom: listPaddingBottom + 20, 
                  ),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final msg = _messages[index];
                    final isUser = msg['role'] == 'user';
                    final isSystem = msg['role'] == 'system_info';

                    if (isSystem) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Text(msg['content']!, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                        ),
                      );
                    }
                    return _buildChatBubble(msg['content']!, isUser);
                  },
                ),
              ),

              // -----------------------------------------------------
              // 第二層：毛玻璃背景 (包住芋圓 + 輸入框)
              // -----------------------------------------------------
              Positioned(
                left: 0,
                right: 0,
                bottom: bottomInset,
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      color: Colors.white.withOpacity(0.3), // 玻璃顏色
                      padding: EdgeInsets.zero,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          
                          // ☁️ 芋圓動畫區塊
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeOut,
                            height: isKeyboardOpen ? 0 : glassHeight, // 🔥 玻璃高度 160
                            width: 250, 
                            // 🔥 這裡改用 Stack + Clip.none 來解決報錯
                            child: Stack(
                              clipBehavior: Clip.none, // 關鍵：允許子元件畫在框框外面！
                              alignment: Alignment.bottomCenter,
                              children: [
                                // 只有當鍵盤沒開的時候才渲染芋圓，避免高度為 0 時的錯誤
                                if (!isKeyboardOpen)
                                  Positioned(
                                    bottom: 0, // 貼齊底部
                                    height: taroRealHeight, // 強制高度 250 (會凸出去)
                                    width: 250,
                                    child: Image.asset(
                                      getTaroAnimation(),
                                      fit: BoxFit.contain,
                                      gaplessPlayback: true,
                                      
                                    ),
                                  ),
                              ],
                            ),
                          ),

                          // ⌨️ 輸入框
                          _buildInputSection(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 📋 新增：對話氣泡樣式 (模仿你原本的白色圓角風格)
  Widget _buildChatBubble(String content, bool isUser) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 6),
            padding: const EdgeInsets.all(16),
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
            decoration: BoxDecoration(
              color: isUser ? Colors.orange[300] : Colors.white.withOpacity(0.9),
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
            ),
            child: Text(
              content,
              style: TextStyle(
                fontSize: 16, 
                fontWeight: FontWeight.w500,
                color: isUser ? Colors.white : Colors.black87
              ),
            ),
          ),
          // 如果是芋圓講話，加一個小三角形 (裝飾用)
          if (!isUser)
             Transform.translate(
               offset: const Offset(20, -8), // 稍微往上移一點，接在氣泡下面
               child: CustomPaint(
                painter: TrianglePainter(color: Colors.white.withOpacity(0.9)),
                size: const Size(15, 10),
               ),
             ),
        ],
      ),
    );
  }

  Widget _buildInputSection() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 122, 117, 126).withOpacity(0.5),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(25)),
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                onTap: _handleInputTap,
                textAlignVertical: TextAlignVertical.center,
                decoration: const InputDecoration(
                  hintText: '問問芋圓...',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: -7),
                  isDense: true, 
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 10),
          IconButton(
            onPressed: _sendMessage,
            icon: const CircleAvatar(
              backgroundColor: Colors.blueAccent,
              child: Icon(Icons.send, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

// 🔥 保留你的三角形 Painter
class TrianglePainter extends CustomPainter {
  final Color color;
  TrianglePainter({required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    var paint = Paint()..color = color;
    var path = Path();
    // 這裡我稍微調整了三角形方向，讓它看起來是從氣泡下面長出來的
    path.moveTo(0, 0); 
    path.lineTo(size.width, 0);
    path.lineTo(size.width / 2, size.height);
    path.close();
    canvas.drawPath(path, paint);
  }
  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}