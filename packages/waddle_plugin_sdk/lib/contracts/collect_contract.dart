class CollectResponse {
  const CollectResponse({this.configKvPatches = const {}});

  final Map<String, String> configKvPatches;

  Map<String, dynamic> toJson() => {
        'v': 1,
        'config_kv_patches': configKvPatches,
      };
}
