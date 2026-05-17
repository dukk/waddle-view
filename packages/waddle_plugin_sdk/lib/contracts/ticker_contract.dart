class TickerItemDto {
  const TickerItemDto({required this.body, this.kind = 'custom'});

  final String body;
  final String kind;

  Map<String, dynamic> toJson() => {'kind': kind, 'body': body};
}

class TickerItemsResponse {
  const TickerItemsResponse({required this.items});

  final List<TickerItemDto> items;

  Map<String, dynamic> toJson() => {
        'v': 1,
        'items': [for (final i in items) i.toJson()],
      };
}
