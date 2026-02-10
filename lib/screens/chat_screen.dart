import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import 'package:weather_test/bloc/weather_bloc_bloc.dart';
import 'package:weather_test/data/weather_repository.dart';
import 'package:weather_test/tool/weather_prompt_helper.dart';

enum TaroState { idle, typing, getQuestion, thinking, answer, tapToText }

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _dialogueScrollController = ScrollController();
  final FocusNode _focusNode = FocusNode(); 
  
  String get _apiKey => dotenv.env['CHAT_API_KEY'] ?? '';
  static const String _modelId = 'llama-3.3-70b-versatile'; 

  TaroState _taroState = TaroState.idle; 
  String _displayDialogue = ""; 
  bool _isTyping = false;
  
  final List<Map<String, String>> _fullHistory = [];

  late AnimationController _floatController;
  late Animation<double> _floatAnimation;
  Timer? _typewriterTimer;
  Timer? _animationTimer; 

  final Map<TaroState, String> _assets = {
    TaroState.idle: 'assets/idle.webp',
    TaroState.typing: 'assets/typing.webp',
    TaroState.getQuestion: 'assets/get_question.webp',
    TaroState.thinking: 'assets/thinking.webp',
    TaroState.answer: 'assets/answer.webp',
    TaroState.tapToText: 'assets/tap_to_text.webp',
  };

  // 工具定義
  final Map<String, dynamic> _weatherToolDefinition = {
    "type": "function",
    "function": {
      "name": "get_weather_forecast",
      "description": "Fetch weather for a NEW location if user explicitly asks for another city.",
      "parameters": {
        "type": "object",
        "properties": {
          "location": {
            "type": "string",
            "description": "City name",
          }
        },
        "required": ["location"],
      },
    }
  };

  @override
  void initState() {
    super.initState();
    
    final weatherState = context.read<WeatherBlocBloc>().state;
    String intro;

    if (weatherState is WeatherBlocSuccess) {
      // 成功抓取天氣，直接帶入地點名稱
      intro = "嗨！我是芋圓 ☁️\n我知道你在 ${weatherState.weather.areaName}，有什麼想問的嗎？";
    } else {
      // 還沒有天氣資料
      intro = "你好呀！我是芋圓 ☁️\n今天想去哪裡玩呢？";
    }

    _fullHistory.add({'role': 'assistant', 'content': intro});
    _startTypewriterEffect(intro);

    // 預載圖片
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        precacheImage(AssetImage(_assets[TaroState.idle]!), context);
      }
    });

    _focusNode.addListener(() {
      if (!_focusNode.hasFocus && (_taroState == TaroState.typing || _taroState == TaroState.tapToText)) {
        setState(() => _taroState = TaroState.idle);
      }
    });

    _floatController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    
    _floatAnimation = Tween<double>(begin: 0, end: 10).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    _floatController.dispose();
    _dialogueScrollController.dispose();
    _focusNode.dispose();
    _typewriterTimer?.cancel();
    _animationTimer?.cancel();
    super.dispose();
  }

  Future<void> _replayAssetWebp(String assetPath) async {
    if (assetPath.contains('idle')) return;
    final provider = AssetImage(assetPath);
    await provider.evict();
  }

  void _playOneShotAnimation(TaroState targetState, TaroState nextState, int durationMs) async {
    _animationTimer?.cancel();
    await _replayAssetWebp(_assets[targetState]!);
    if (nextState != TaroState.idle) {
       _replayAssetWebp(_assets[nextState]!); 
    }
    if (mounted) {
      setState(() => _taroState = targetState);
    }
    _animationTimer = Timer(Duration(milliseconds: durationMs), () {
      if (mounted) {
        if (nextState == TaroState.typing && !_focusNode.hasFocus) {
          setState(() => _taroState = TaroState.idle);
        } else {
          setState(() => _taroState = nextState);
        }
      }
    });
  }

  void _handleInputTap() {
    if (_taroState == TaroState.idle) {
      _playOneShotAnimation(TaroState.tapToText, TaroState.typing, 300);
    }
  }

  void _startTypewriterEffect(String text) {
    _typewriterTimer?.cancel();
    final charactersList = text.characters.toList();
    setState(() {
      _displayDialogue = "";
      _isTyping = true;
    });
    int index = 0;
    _typewriterTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (index < charactersList.length) {
        if (mounted) {
          setState(() => _displayDialogue += charactersList[index]);
          if (_dialogueScrollController.hasClients) {
            _dialogueScrollController.jumpTo(_dialogueScrollController.position.maxScrollExtent);
          }
        }
        index++;
      } else {
        if (mounted) setState(() => _isTyping = false);
        timer.cancel();
      }
    });
  }

  Future<void> _handleSubmitted(String text) async {
    if (text.trim().isEmpty) return;

    FocusManager.instance.primaryFocus?.unfocus();
    _textController.clear();
    _playOneShotAnimation(TaroState.getQuestion, TaroState.thinking, 800);

    setState(() {
      _fullHistory.add({'role': 'user', 'content': text});
    });
    _startTypewriterEffect("..."); 

    try {
      // 每次對話前，重新抓取最新的天氣狀態
      final weatherState = context.read<WeatherBlocBloc>().state;
      
      String systemContent;
      
      if (weatherState is WeatherBlocSuccess) {
        // 將天氣資料傳給 Prompt Helper
        systemContent = WeatherPromptHelper.generateSystemPrompt(weatherState.weather);
      } else {
        // 如果沒有資料，使用預設 Prompt
        systemContent = 'You are Taro, a weather assistant. Reply in the SAME language as the user. If you don\'t know the location, ask politely.';
      }

      List<Map<String, dynamic>> apiMessages = [
        {
          'role': 'system',
          'content': systemContent
        }
      ];
      
      for (var msg in _fullHistory) {
        apiMessages.add({'role': msg['role']!, 'content': msg['content']!});
      }

      var response = await _callGroqAPI(apiMessages, tools: [_weatherToolDefinition]);
      var message = response['choices'][0]['message'];

      if (message['tool_calls'] != null) {
        for (var toolCall in message['tool_calls']) {
          final functionName = toolCall['function']['name'];
          final args = jsonDecode(toolCall['function']['arguments']);
          
          if (functionName == 'get_weather_forecast') {
             if (mounted) _startTypewriterEffect("🔍 ☁️ ${args['location']}...");
             
             final weatherRepo = WeatherRepository(); 
             String weatherInfo = await weatherRepo.getWeatherForecastForGroq(args['location']);

             apiMessages.add(message);
             apiMessages.add({
               'role': 'tool',
               'tool_call_id': toolCall['id'],
               'name': functionName,
               'content': weatherInfo,
             });
          }
        }
        response = await _callGroqAPI(apiMessages);
        message = response['choices'][0]['message'];
      }

      final replyText = message['content'] ?? '...';

      if (mounted) {
        setState(() {
          _fullHistory.add({'role': 'assistant', 'content': replyText});
        });
        _playOneShotAnimation(TaroState.answer, TaroState.idle, 1500);
        _startTypewriterEffect(replyText);
      }

    } catch (e) {
      if (mounted) {
        _startTypewriterEffect("Error: $e");
        setState(() => _taroState = TaroState.idle);
      }
    }
  }

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
      }),
    );
    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } else {
      throw Exception('API Error');
    }
  }

  void _showHistoryDialog() {
      showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.8,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("History", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _fullHistory.length,
                  itemBuilder: (context, index) {
                    final msg = _fullHistory[index];
                    final isUser = msg['role'] == 'user';
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
                        children: [
                          if (!isUser) const Padding(padding: EdgeInsets.only(top: 4), child: Text("☁️ ", style: TextStyle(fontSize: 18))),
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isUser ? Colors.orange[300] : Colors.grey[100],
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: SelectableText(
                                msg['content']!,
                                style: TextStyle(color: isUser ? Colors.white : Colors.black87, fontSize: 15),
                              ),
                            ),
                          ),
                          if (isUser) const Padding(padding: EdgeInsets.only(top: 4), child: Text(" 👤", style: TextStyle(fontSize: 18))),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        systemOverlayStyle: SystemUiOverlayStyle.dark, 
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.history, color: Colors.black54, size: 28),
          onPressed: _showHistoryDialog,
          tooltip: "History",
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.black54),
            onPressed: () {
               setState(() {
                 _fullHistory.clear();
                 _startTypewriterEffect("Memory cleared.");
               });
            },
          )
        ],
      ),
      extendBodyBehindAppBar: true,
      body: Column(
        children: [
          Expanded(
            flex: 3,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 250,
                    height: 250,
                    child: Image.asset(
                      _assets[_taroState]!, 
                      fit: BoxFit.contain,
                      gaplessPlayback: true,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.95),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08), 
                    blurRadius: 15, 
                    offset: const Offset(0, 5)
                  )
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                    child: Row(
                      children: [
                        const Text("Yuyuan", style: TextStyle(color: Color(0xFF5D5D5D), fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(width: 8),
                        if (_isTyping) const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.orange))
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: _dialogueScrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        _displayDialogue, 
                        style: const TextStyle(color: Color(0xFF333333), fontSize: 17, height: 1.6, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
                    ),
                    child: TextField(
                      controller: _textController,
                      focusNode: _focusNode,
                      onTap: _handleInputTap,
                      style: const TextStyle(color: Colors.black87),
                      decoration: const InputDecoration(
                        hintText: " Ask Yuyuan...",
                        hintStyle: TextStyle(color: Colors.black38),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      ),
                      onSubmitted: _handleSubmitted,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.orange[300],
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: Colors.orange.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))],
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white),
                    onPressed: () => _handleSubmitted(_textController.text),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}