class Player {
  final String id;
  final String name;
  final int seatIndex; // 0-3

  int get teamId => seatIndex % 2; // 0,2 = team 0; 1,3 = team 1

  const Player({
    required this.id,
    required this.name,
    required this.seatIndex,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'seatIndex': seatIndex,
  };

  factory Player.fromJson(Map<String, dynamic> j) => Player(
    id: j['id'] as String,
    name: j['name'] as String,
    seatIndex: j['seatIndex'] as int,
  );
}
