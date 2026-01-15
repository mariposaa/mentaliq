class TestQuestion {
  final String id;
  final String text;
  final List<TestOption> options;

  TestQuestion({required this.id, required this.text, required this.options});
}

class TestOption {
  final String text;
  final int value; // Puan ağırlığı

  TestOption({required this.text, required this.value});
}

class MentalTest {
  final String id;
  final String title;
  final String description;
  final List<TestQuestion> questions;
  final String analysisPrompt;

  MentalTest({
    required this.id,
    required this.title,
    required this.description,
    required this.questions,
    required this.analysisPrompt,
  });
}
