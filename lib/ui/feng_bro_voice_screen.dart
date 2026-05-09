import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

class FengBroVoiceScreen extends StatefulWidget {
  const FengBroVoiceScreen({super.key});

  @override
  State<FengBroVoiceScreen> createState() => _FengBroVoiceScreenState();
}

class _FengBroVoiceScreenState extends State<FengBroVoiceScreen> {
  final SpeechToText _speech = SpeechToText();
  final TextEditingController _textController = TextEditingController();
  final List<_ConfirmedVoiceCommand> _confirmedCommands = [];

  bool _speechReady = false;
  bool _isListening = false;
  String _status = '選擇模組後可開始語音輸入';
  _FengVoiceModule _selectedModule = _voiceModules.first;
  _VoiceCommandPlan? _plan;
  int _confirmStep = 0;

  @override
  void initState() {
    super.initState();
    _initializeSpeech();
  }

  @override
  void dispose() {
    _speech.stop();
    _textController.dispose();
    super.dispose();
  }

  Future<void> _initializeSpeech() async {
    final ready = await _speech.initialize(
      onStatus: (status) {
        if (!mounted) return;
        setState(() {
          _status = _speechStatusText(status);
          _isListening = status == 'listening';
        });
      },
      onError: (error) {
        if (!mounted) return;
        setState(() {
          _status = '語音辨識失敗：${error.errorMsg}';
          _isListening = false;
        });
      },
    );

    if (!mounted) return;
    setState(() {
      _speechReady = ready;
      _status = ready ? '語音輸入已就緒' : '此裝置尚未開啟語音辨識';
    });
  }

  Future<void> _toggleListening() async {
    if (!_speechReady) {
      await _initializeSpeech();
      if (!_speechReady) return;
    }

    if (_isListening) {
      await _speech.stop();
      if (!mounted) return;
      setState(() => _isListening = false);
      return;
    }

    setState(() {
      _plan = null;
      _confirmStep = 0;
      _status = '正在聆聽 ${_selectedModule.name} 指令...';
    });

    await _speech.listen(
      localeId: 'zh_TW',
      listenOptions: SpeechListenOptions(
        listenMode: ListenMode.confirmation,
        partialResults: true,
      ),
      listenFor: const Duration(seconds: 45),
      pauseFor: const Duration(seconds: 4),
      onResult: _onSpeechResult,
    );
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    if (!mounted) return;
    setState(() {
      _textController.text = result.recognizedWords;
      _textController.selection = TextSelection.fromPosition(
        TextPosition(offset: _textController.text.length),
      );
      _status = result.finalResult ? '語音輸入完成，請檢查內容' : '正在辨識...';
    });
  }

  void _selectModule(_FengVoiceModule module) {
    setState(() {
      _selectedModule = module;
      _plan = null;
      _confirmStep = 0;
      _status = '已切換到 ${module.name} 語音輸入';
    });
  }

  void _useExample(String example) {
    setState(() {
      _textController.text = example;
      _textController.selection = TextSelection.fromPosition(
        TextPosition(offset: example.length),
      );
      _plan = null;
      _confirmStep = 0;
      _status = '已套用範例，可直接產生命令';
    });
  }

  void _buildPlan() {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      setState(() => _status = '請先輸入或說出內容');
      return;
    }

    setState(() {
      _plan = _VoiceCommandPlanner.build(
        module: _selectedModule,
        transcript: text,
      );
      _confirmStep = 0;
      _status = '已產生命令草稿，請進行雙重確認';
    });
  }

  void _confirmPlan() {
    final plan = _plan;
    if (plan == null) {
      setState(() => _status = '請先產生命令草稿');
      return;
    }

    if (_confirmStep == 0) {
      setState(() {
        _confirmStep = 1;
        _status = '第一次確認完成，請再確認一次';
      });
      return;
    }

    setState(() {
      _confirmedCommands.insert(
        0,
        _ConfirmedVoiceCommand(plan: plan, confirmedAt: DateTime.now()),
      );
      _confirmStep = 0;
      _plan = null;
      _textController.clear();
      _status = '雙重確認完成，語音指令已加入確認紀錄';
    });
  }

  void _clearInput() {
    setState(() {
      _textController.clear();
      _plan = null;
      _confirmStep = 0;
      _status = '已清空輸入';
    });
  }

  String _speechStatusText(String status) {
    switch (status) {
      case 'listening':
        return '正在聆聽...';
      case 'notListening':
        return '已停止聆聽';
      case 'done':
        return '語音輸入完成';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F6),
      appBar: AppBar(
        title: const Text(
          '鋒兄語音輸入',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _buildHeader(),
          const SizedBox(height: 14),
          _buildModulePicker(),
          const SizedBox(height: 14),
          _buildInputPanel(),
          const SizedBox(height: 14),
          _buildPlanPanel(),
          const SizedBox(height: 14),
          _buildConfirmedPanel(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0B2F2A),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.14),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.mic_rounded,
              color: Color(0xFF9FF7DF),
              size: 30,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '15 個鋒兄模組語音輸入',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  '語音先轉成草稿，再做第一次確認與第二次確認，適合新增、查詢、整理與設定類指令。',
                  style: TextStyle(color: Color(0xFFD7FFF4), height: 1.45),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModulePicker() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '選擇語音模組',
            style: TextStyle(
              color: Color(0xFF173832),
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _voiceModules.map((module) {
              final selected = module.id == _selectedModule.id;
              return ChoiceChip(
                avatar: Icon(
                  module.icon,
                  size: 18,
                  color: selected ? Colors.white : module.color,
                ),
                label: Text(module.name),
                selected: selected,
                onSelected: (_) => _selectModule(module),
                selectedColor: module.color,
                labelStyle: TextStyle(
                  color: selected ? Colors.white : const Color(0xFF173832),
                  fontWeight: FontWeight.w700,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildInputPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_selectedModule.icon, color: _selectedModule.color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${_selectedModule.name}語音輸入',
                  style: const TextStyle(
                    color: Color(0xFF173832),
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _textController,
            minLines: 3,
            maxLines: 6,
            decoration: InputDecoration(
              hintText: _selectedModule.hint,
              prefixIcon: const Icon(Icons.record_voice_over_rounded),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: _toggleListening,
                icon: Icon(
                  _isListening ? Icons.stop_rounded : Icons.mic_rounded,
                ),
                label: Text(_isListening ? '停止聆聽' : '開始語音'),
              ),
              OutlinedButton.icon(
                onPressed: _buildPlan,
                icon: const Icon(Icons.auto_fix_high_rounded),
                label: const Text('產生命令'),
              ),
              OutlinedButton.icon(
                onPressed: _clearInput,
                icon: const Icon(Icons.clear_rounded),
                label: const Text('清空'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _status,
            style: const TextStyle(
              color: Color(0xFF576B66),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            '常用說法',
            style: TextStyle(
              color: Color(0xFF173832),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _selectedModule.examples.map((example) {
              return ActionChip(
                label: Text(example),
                onPressed: () => _useExample(example),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanPanel() {
    final plan = _plan;
    if (plan == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: _cardDecoration(),
        child: const Text(
          '語音內容會先整理成命令草稿，包含動作、欄位、確認清單與風險提示。',
          style: TextStyle(color: Color(0xFF576B66), height: 1.45),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _selectedModule.color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  plan.moduleName,
                  style: TextStyle(
                    color: _selectedModule.color,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  plan.actionTitle,
                  style: const TextStyle(
                    color: Color(0xFF173832),
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            plan.summary,
            style: const TextStyle(color: Color(0xFF314A44), height: 1.45),
          ),
          const SizedBox(height: 14),
          _buildPlanSection('抽取欄位', plan.fields),
          const SizedBox(height: 10),
          _buildPlanSection('確認清單', plan.confirmations),
          const SizedBox(height: 10),
          _buildPlanSection('後續動作', plan.nextSteps),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7ED),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFF5C38A)),
            ),
            child: Text(
              plan.riskNote,
              style: const TextStyle(
                color: Color(0xFF9A531D),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: _confirmPlan,
            icon: Icon(
              _confirmStep == 0
                  ? Icons.check_circle_outline_rounded
                  : Icons.verified_rounded,
            ),
            label: Text(_confirmStep == 0 ? '第一次確認' : '第二次確認送出'),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanSection(String title, List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF173832),
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        ...items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('• ', style: TextStyle(color: Color(0xFF0F766E))),
                Expanded(
                  child: Text(
                    item,
                    style: const TextStyle(color: Color(0xFF576B66)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildConfirmedPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '雙重確認紀錄',
            style: TextStyle(
              color: Color(0xFF173832),
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          if (_confirmedCommands.isEmpty)
            const Text('尚未送出語音指令。', style: TextStyle(color: Color(0xFF576B66)))
          else
            ..._confirmedCommands.take(8).map((command) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F6F4),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      command.plan.actionTitle,
                      style: const TextStyle(
                        color: Color(0xFF173832),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${command.plan.moduleName} · ${DateFormat('MM/dd HH:mm').format(command.confirmedAt)}',
                      style: const TextStyle(color: Color(0xFF576B66)),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFDCE8E4)),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF0B3B32).withOpacity(0.06),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }
}

class _FengVoiceModule {
  final String id;
  final String name;
  final IconData icon;
  final Color color;
  final String hint;
  final List<String> verbs;
  final List<String> examples;
  final List<String> fieldHints;
  final List<String> nextStepHints;

  const _FengVoiceModule({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    required this.hint,
    required this.verbs,
    required this.examples,
    required this.fieldHints,
    required this.nextStepHints,
  });
}

class _VoiceCommandPlan {
  final String moduleName;
  final String actionTitle;
  final String summary;
  final List<String> fields;
  final List<String> confirmations;
  final List<String> nextSteps;
  final String riskNote;

  const _VoiceCommandPlan({
    required this.moduleName,
    required this.actionTitle,
    required this.summary,
    required this.fields,
    required this.confirmations,
    required this.nextSteps,
    required this.riskNote,
  });
}

class _ConfirmedVoiceCommand {
  final _VoiceCommandPlan plan;
  final DateTime confirmedAt;

  const _ConfirmedVoiceCommand({required this.plan, required this.confirmedAt});
}

class _VoiceCommandPlanner {
  static _VoiceCommandPlan build({
    required _FengVoiceModule module,
    required String transcript,
  }) {
    final action = _detectAction(module, transcript);
    final keywords = _extractKeywords(transcript);
    final numbers = _extractNumbers(transcript);
    final dates = _extractDateHints(transcript);

    final fields = <String>[
      '原始語音：$transcript',
      '判斷動作：$action',
      '關鍵字：${keywords.isEmpty ? '未偵測，保留完整語音內容' : keywords.join('、')}',
      if (numbers.isNotEmpty) '數字/金額：${numbers.join('、')}',
      if (dates.isNotEmpty) '日期/週期：${dates.join('、')}',
      ...module.fieldHints,
    ];

    return _VoiceCommandPlan(
      moduleName: module.name,
      actionTitle: '${module.name} · $action',
      summary: '已把語音整理成「$action」草稿。送出前會保留原始語音、推測欄位與待確認項目，避免誤新增、誤刪除或誤更新。',
      fields: fields,
      confirmations: [
        '第一次確認：確認辨識文字、模組與動作是否正確。',
        '第二次確認：確認欄位、金額、日期、對象與是否要送出。',
        '若語音包含刪除、付款、公開、上傳、寄送等高風險詞，送出前必須人工再看一次。',
      ],
      nextSteps: module.nextStepHints,
      riskNote: _riskNote(transcript),
    );
  }

  static String _detectAction(_FengVoiceModule module, String transcript) {
    final text = transcript.toLowerCase();
    for (final verb in module.verbs) {
      if (text.contains(verb.toLowerCase())) {
        return verb;
      }
    }
    if (_containsAny(text, ['新增', '建立', '加入', '記一筆'])) return '新增';
    if (_containsAny(text, ['查詢', '搜尋', '找', '顯示'])) return '查詢';
    if (_containsAny(text, ['更新', '修改', '改成', '調整'])) return '更新';
    if (_containsAny(text, ['刪除', '移除', '取消'])) return '刪除';
    if (_containsAny(text, ['提醒', '通知', '排程'])) return '建立提醒';
    return '整理語音草稿';
  }

  static List<String> _extractKeywords(String transcript) {
    final cleaned = transcript
        .replaceAll(RegExp(r'[，。！？,.!?]'), ' ')
        .split(RegExp(r'\s+'))
        .where((word) => word.trim().length >= 2)
        .take(8)
        .toList();
    if (cleaned.isNotEmpty) return cleaned;

    final chunks = <String>[];
    for (var i = 0; i < transcript.length; i += 4) {
      final end = (i + 4).clamp(0, transcript.length);
      chunks.add(transcript.substring(i, end));
      if (chunks.length >= 6) break;
    }
    return chunks.where((chunk) => chunk.trim().isNotEmpty).toList();
  }

  static List<String> _extractNumbers(String transcript) {
    return RegExp(
      r'(\d+(?:\.\d+)?|[一二三四五六七八九十百千萬]+)',
    ).allMatches(transcript).map((match) => match.group(0)!).take(6).toList();
  }

  static List<String> _extractDateHints(String transcript) {
    const hints = [
      '今天',
      '明天',
      '後天',
      '每週',
      '每月',
      '每年',
      '早上',
      '下午',
      '晚上',
      '週一',
      '週二',
      '週三',
      '週四',
      '週五',
      '週六',
      '週日',
    ];
    return hints.where(transcript.contains).toList();
  }

  static String _riskNote(String transcript) {
    if (_containsAny(transcript, [
      '刪除',
      '移除',
      '取消',
      '付款',
      '轉帳',
      '公開',
      '上傳',
      '寄送',
    ])) {
      return '偵測到高風險詞，雙重確認後仍建議進入對應模組再次核對。';
    }
    return '一般風險：仍需完成雙重確認才會加入確認紀錄。';
  }

  static bool _containsAny(String text, List<String> words) {
    return words.any(text.contains);
  }
}

const _voiceModules = [
  _FengVoiceModule(
    id: 'home',
    name: '鋒兄首頁',
    icon: Icons.home_rounded,
    color: Color(0xFF0F766E),
    hint: '例如：回首頁，顯示今天摘要，新增一個睡眠提醒',
    verbs: ['回首頁', '顯示摘要', '新增提醒', '搜尋功能', '開啟工具'],
    examples: ['回首頁顯示今天摘要', '新增今晚十一點睡眠提醒', '搜尋手機比價工具'],
    fieldHints: ['首頁目標區塊', '是否需要立即跳轉', '提醒時間或摘要範圍'],
    nextStepHints: ['更新首頁摘要', '開啟指定工具', '建立首頁提醒草稿'],
  ),
  _FengVoiceModule(
    id: 'dashboard',
    name: '鋒兄儀表',
    icon: Icons.dashboard_rounded,
    color: Color(0xFF2563EB),
    hint: '例如：顯示本週儀表，查看訂閱支出趨勢',
    verbs: ['顯示儀表', '查看趨勢', '更新統計', '比較數據', '匯出摘要'],
    examples: ['顯示本週訂閱支出趨勢', '比較這個月和上個月儀表', '更新今日統計摘要'],
    fieldHints: ['統計期間', '指標名稱', '比較基準'],
    nextStepHints: ['產生儀表查詢', '整理趨勢摘要', '標記需要更新的統計卡'],
  ),
  _FengVoiceModule(
    id: 'subscription',
    name: '鋒兄訂閱',
    icon: Icons.subscriptions_rounded,
    color: Color(0xFF7C3AED),
    hint: '例如：新增 Netflix 每月 390 元，下次扣款 6 月 1 日',
    verbs: ['新增訂閱', '更新訂閱', '刪除訂閱', '查詢扣款', '建立扣款提醒'],
    examples: ['新增 Netflix 每月三百九十元', '查詢三天內即將扣款的訂閱', '更新 Spotify 下次扣款日'],
    fieldHints: ['訂閱名稱', '金額', '扣款週期', '下次扣款日', '帳號或備註'],
    nextStepHints: ['建立訂閱草稿', '更新扣款提醒', '查詢即將到期清單'],
  ),
  _FengVoiceModule(
    id: 'food',
    name: '鋒兄食品',
    icon: Icons.restaurant_rounded,
    color: Color(0xFFD97706),
    hint: '例如：新增晚餐牛肉麵 120 元，標記好吃',
    verbs: ['新增食品', '記錄餐點', '查詢食品', '更新評分', '建立購物清單'],
    examples: ['新增晚餐牛肉麵一百二十元', '查詢最近吃過的火鍋', '把咖啡加入常買清單'],
    fieldHints: ['食品名稱', '價格', '餐別', '評分', '店家或備註'],
    nextStepHints: ['新增食品紀錄', '整理常買清單', '建立餐點提醒'],
  ),
  _FengVoiceModule(
    id: 'notes',
    name: '鋒兄筆記',
    icon: Icons.note_alt_rounded,
    color: Color(0xFF0891B2),
    hint: '例如：新增筆記，今天想到三個 app 改版重點',
    verbs: ['新增筆記', '查詢筆記', '整理重點', '加標籤', '待辦'],
    examples: ['新增筆記今天想到三個改版重點', '查詢語音輸入相關筆記', '把這段整理成待辦'],
    fieldHints: ['標題', '內文', '標籤', '待辦項目', '優先度'],
    nextStepHints: ['建立筆記草稿', '萃取重點', '加入待辦清單'],
  ),
  _FengVoiceModule(
    id: 'common',
    name: '鋒兄常用',
    icon: Icons.star_rounded,
    color: Color(0xFFCA8A04),
    hint: '例如：開啟常用帳號，查詢某網站登入資訊',
    verbs: ['新增常用', '查詢常用', '開啟網站', '更新帳號', '複製資訊'],
    examples: ['查詢常用的 Appwrite 帳號', '新增一個常用網站', '開啟鋒兄常用服務'],
    fieldHints: ['服務名稱', '網址', '帳號提示', '分類', '安全備註'],
    nextStepHints: ['查詢常用項目', '建立常用連結', '標記敏感資訊需二次核對'],
  ),
  _FengVoiceModule(
    id: 'images',
    name: '鋒兄圖片',
    icon: Icons.image_rounded,
    color: Color(0xFFDB2777),
    hint: '例如：搜尋上週上傳的圖片，標籤改成發票',
    verbs: ['新增圖片', '搜尋圖片', '加標籤', '整理相簿', '刪除圖片'],
    examples: ['搜尋上週上傳的發票圖片', '把這批圖片加上旅遊標籤', '建立圖片整理待辦'],
    fieldHints: ['圖片來源', '標籤', '相簿名稱', '日期範圍', '是否公開'],
    nextStepHints: ['建立圖片搜尋', '產生標籤草稿', '整理相簿動作'],
  ),
  _FengVoiceModule(
    id: 'videos',
    name: '鋒兄影片',
    icon: Icons.video_library_rounded,
    color: Color(0xFFDC2626),
    hint: '例如：搜尋教學影片，截圖並加標籤',
    verbs: ['新增影片', '搜尋影片', '產生摘要', '截圖', '整理播放清單'],
    examples: ['搜尋昨天的教學影片', '把影片加入待看清單', '產生這支影片摘要'],
    fieldHints: ['影片名稱', '播放清單', '時間點', '摘要需求', '標籤'],
    nextStepHints: ['建立影片搜尋', '整理播放清單', '建立摘要任務'],
  ),
  _FengVoiceModule(
    id: 'music',
    name: '鋒兄音樂',
    icon: Icons.music_note_rounded,
    color: Color(0xFF9333EA),
    hint: '例如：播放鋒兄歌詞，新增到播放佇列',
    verbs: ['播放音樂', '搜尋歌曲', '加入佇列', '整理歌詞', '建立播放清單'],
    examples: ['播放鋒兄歌詞', '搜尋最近新增的音樂', '把這首加入睡前播放清單'],
    fieldHints: ['歌曲名稱', '歌手', '播放清單', '佇列位置', '歌詞需求'],
    nextStepHints: ['建立音樂搜尋', '加入播放佇列', '整理歌詞草稿'],
  ),
  _FengVoiceModule(
    id: 'documents',
    name: '鋒兄文件',
    icon: Icons.description_rounded,
    color: Color(0xFF475569),
    hint: '例如：新增文件，標題是五月會議紀錄',
    verbs: ['新增文件', '搜尋文件', '整理段落', '轉成摘要', '加標籤'],
    examples: ['新增文件五月會議紀錄', '搜尋 Appwrite 架構文件', '把文件整理成三點摘要'],
    fieldHints: ['文件標題', '內容摘要', '分類', '標籤', '是否需要匯出'],
    nextStepHints: ['建立文件草稿', '產生摘要', '建立文件搜尋條件'],
  ),
  _FengVoiceModule(
    id: 'podcast',
    name: '鋒兄播客',
    icon: Icons.podcasts_rounded,
    color: Color(0xFFEA580C),
    hint: '例如：新增播客，標題是語音輸入開發紀錄',
    verbs: ['新增播客', '搜尋播客', '加入佇列', '產生逐字稿', '整理摘要'],
    examples: ['新增播客語音輸入開發紀錄', '搜尋最近的科技播客', '把這集加入通勤佇列'],
    fieldHints: ['播客名稱', '集數', '播放佇列', '逐字稿需求', '摘要重點'],
    nextStepHints: ['建立播客草稿', '加入播放佇列', '建立逐字稿任務'],
  ),
  _FengVoiceModule(
    id: 'bank',
    name: '鋒兄銀行 (+電子票證)',
    icon: Icons.account_balance_rounded,
    color: Color(0xFF15803D),
    hint: '例如：新增銀行提醒，信用卡下週一繳款',
    verbs: ['新增銀行', '查詢銀行', '建立繳款提醒', '更新帳戶', '對帳'],
    examples: ['新增信用卡下週一繳款提醒', '查詢銀行常用帳號', '建立本月對帳待辦'],
    fieldHints: ['銀行名稱', '帳戶提示', '金額', '繳款日', '安全備註'],
    nextStepHints: ['建立銀行提醒', '整理對帳草稿', '敏感欄位需二次核對'],
  ),
  _FengVoiceModule(
    id: 'routine',
    name: '鋒兄例行',
    icon: Icons.event_repeat_rounded,
    color: Color(0xFF0D9488),
    hint: '例如：建立每週一早上九點整理訂閱',
    verbs: ['新增例行', '查詢例行', '更新排程', '暫停例行', '完成例行'],
    examples: ['建立每週一早上九點整理訂閱', '查詢今天例行工作', '暫停睡前提醒三天'],
    fieldHints: ['例行名稱', '週期', '時間', '提醒內容', '暫停或啟用狀態'],
    nextStepHints: ['建立例行草稿', '更新提醒排程', '查詢今日例行清單'],
  ),
  _FengVoiceModule(
    id: 'settings',
    name: '鋒兄設定',
    icon: Icons.settings_rounded,
    color: Color(0xFF334155),
    hint: '例如：設定語音輸入預設模組為訂閱',
    verbs: ['更新設定', '查詢設定', '開啟通知', '關閉通知', '切換模式'],
    examples: ['設定語音輸入預設模組為訂閱', '開啟夜間提醒', '查詢目前通知設定'],
    fieldHints: ['設定項目', '新值', '開關狀態', '生效範圍', '回復方式'],
    nextStepHints: ['建立設定變更草稿', '提示需二次確認', '保留原設定以便回復'],
  ),
  _FengVoiceModule(
    id: 'about',
    name: '鋒兄關於',
    icon: Icons.info_rounded,
    color: Color(0xFF0369A1),
    hint: '例如：更新關於頁，加入語音輸入功能介紹',
    verbs: ['更新關於', '查詢版本', '新增介紹', '整理說明', '查看資訊'],
    examples: ['更新關於頁加入語音輸入介紹', '查詢目前版本', '整理鋒兄工具功能說明'],
    fieldHints: ['介紹標題', '說明內容', '版本資訊', '功能亮點', '發布備註'],
    nextStepHints: ['建立關於頁文案草稿', '整理版本摘要', '準備發布說明'],
  ),
];
