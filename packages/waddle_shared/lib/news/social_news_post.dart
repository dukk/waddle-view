/// Normalized post from a social feed API (Facebook, X/Twitter, LinkedIn).
class SocialNewsPost {
  const SocialNewsPost({
    required this.id,
    required this.text,
    required this.link,
    required this.createdAtMs,
    this.imageUrl,
  });

  final String id;
  final String text;
  final String link;
  final int createdAtMs;
  final String? imageUrl;
}
