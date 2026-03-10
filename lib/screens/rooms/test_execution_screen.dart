import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
import '../../config/responsive.dart';
import '../../l10n/app_translations.dart';
import '../../models/test_model.dart';
import '../../services/gemini_service.dart';
import '../../services/token_service.dart';
import '../../widgets/token_dialog.dart';

class TestExecutionScreen extends StatefulWidget {
  final MentalTest test;
  final int tokenCost;

  const TestExecutionScreen({super.key, required this.test, this.tokenCost = 15});

  @override
  State<TestExecutionScreen> createState() => _TestExecutionScreenState();
}

class _TestExecutionScreenState extends State<TestExecutionScreen> {
  int _currentQuestionIndex = 0;
  int _totalScore = 0;
  bool _isAnalyzing = false;
  bool _tokensDeducted = false;
  String? _analysisResult;
  final List<String> _userSummary = []; // List of "Question: Answer"

  @override
  void initState() {
    super.initState();
    _deductTokens();
  }

  Future<void> _deductTokens() async {
    final balance = await TokenService.getBalance();
    if (balance < widget.tokenCost) {
      if (mounted) {
        final success = await TokenDialog.show(context);
        if (success) {
          // Retry deduction after ad
          _deductTokens();
        } else {
          Navigator.pop(context);
        }
      }
      return;
    }

    final success = await TokenService.useTokensForTest(widget.tokenCost);
    if (success) {
      setState(() => _tokensDeducted = true);
    } else {
      if (mounted) Navigator.pop(context);
    }
  }

  void _handleAnswer(TestQuestion question, TestOption opt) {
    if (!_tokensDeducted) return;

    setState(() {
      _totalScore += opt.value;
      _userSummary.add('${question.text} -> CEVAP: ${opt.text}');
      
      if (_currentQuestionIndex < widget.test.questions.length - 1) {
        _currentQuestionIndex++;
      } else {
        _finishTest();
      }
    });
  }

  Future<void> _finishTest() async {
    setState(() => _isAnalyzing = true);
    
    try {
      final answersText = _userSummary.join('\n');
      final detailedPrompt = '''
Sen uzman bir klinik psikolog ve karakter analistisin. Kullanıcı "${widget.test.title}" testini tamamladı.
Toplam Ham Puan: $_totalScore

Kullanıcının her bir soruya verdiği spesifik cevaplar aşağıdadır:
$answersText

GÖREV:
1. Bu cevapları ve toplam puanı bir bütün olarak analiz et.
2. Sadece genel geçer (klişe) ifadeler kullanma; spesifik cevaplardaki eğilimleri yakala.
3. Analizin derinlemesine, dürüst ve kullanıcıya kendini keşfetmesi için gerçek bir ayna tutacak nitelikte olsun.
4. Yanıtını Markdown formatında, düzenli başlıklar ve maddeler kullanarak ver.

NOT: Analiz promptu şablonu şuydu: ${widget.test.analysisPrompt.replaceAll('{score}', _totalScore.toString())}
Lütfen bu şablonun ötesine geçerek derin analiz yap.
''';

      final result = await GeminiService.generateResponse(detailedPrompt, 'zihin_testleri');
      
      setState(() {
        _isAnalyzing = false;
        _analysisResult = result;
      });
    } catch (e) {
      setState(() => _isAnalyzing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppTranslations.get('errorAnalysisFailed'))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = context.isCompactPhone;
    if (!_tokensDeducted && _analysisResult == null) {
      return Scaffold(
        backgroundColor: AppTheme.sandBeige,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: AppTheme.sageGreen),
              const SizedBox(height: 16),
              Text(AppTranslations.get('checkingTokens'), style: const TextStyle(color: AppTheme.mutedSage)),
            ],
          ),
        ),
      );
    }
    
    if (_analysisResult != null || _isAnalyzing) return _buildResultScreen();

    final question = widget.test.questions[_currentQuestionIndex];
    final progress = (_currentQuestionIndex + 1) / widget.test.questions.length;

    return Scaffold(
      backgroundColor: AppTheme.sandBeige,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          widget.test.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: AppTheme.forestCharcoal,
            fontSize: isCompact ? 14 : 16,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppTheme.forestCharcoal),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: EdgeInsets.all(isCompact ? 14 : 24),
        child: Column(
          children: [
            LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white,
              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.sageGreen),
              borderRadius: BorderRadius.circular(10),
              minHeight: 8,
            ),
            SizedBox(height: isCompact ? 24 : 40),
            Text(
              '${AppTranslations.get('question')} ${_currentQuestionIndex + 1}/${widget.test.questions.length}',
              style: const TextStyle(color: AppTheme.mutedSage, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Text(
              question.text,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: isCompact ? 18 : 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.forestCharcoal,
              ),
            ),
            SizedBox(height: isCompact ? 28 : 48),
            ...question.options.map((opt) => _buildOptionButton(question, opt)),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionButton(TestQuestion question, TestOption opt) {
    final isCompact = context.isCompactPhone;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GestureDetector(
        onTap: () => _handleAnswer(question, opt),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(isCompact ? 14 : 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.softBorder),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))
            ],
          ),
          child: Text(
            opt.text,
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: isCompact ? 14 : 16,
              color: AppTheme.forestCharcoal,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResultScreen() {
    final isCompact = context.isCompactPhone;
    return Scaffold(
      backgroundColor: AppTheme.sandBeige,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: isCompact ? 14 : 24,
            vertical: isCompact ? 20 : 32,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('🧘', style: TextStyle(fontSize: 64)),
              const SizedBox(height: 24),
              Text(
                AppTranslations.get('analysisCompleted'),
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.forestCharcoal),
              ),
              const SizedBox(height: 16),
              _isAnalyzing 
                ? Column(
                    children: [
                      const SizedBox(height: 48),
                      const CircularProgressIndicator(color: AppTheme.sageGreen),
                      const SizedBox(height: 16),
                      Text(AppTranslations.get('aiAnalyzing'), style: const TextStyle(color: AppTheme.mutedSage)),
                    ],
                  )
                : Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppTheme.warmCream,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)
                          ],
                        ),
                        child: Text(
                          _analysisResult ?? '',
                          style: const TextStyle(fontSize: 15, height: 1.6, color: AppTheme.forestCharcoal),
                        ),
                      ),
                      const SizedBox(height: 40),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.sageGreen,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 56),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: Text(AppTranslations.get('close'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
            ],
          ),
        ),
      ),
    );
  }
}
