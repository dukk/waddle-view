/// Parsed joke payload before persistence (domain layer).
class JokeCandidate {
  const JokeCandidate({
    required this.categoryId,
    required this.setup,
    required this.punchline,
  });

  final String categoryId;
  final String setup;
  final String punchline;
}
