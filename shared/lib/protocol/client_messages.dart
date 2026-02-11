class ClientMsg {
  final String type;
  final Map<String, dynamic> payload;

  const ClientMsg({required this.type, required this.payload});

  Map<String, dynamic> toJson() => {'type': type, 'payload': payload};

  factory ClientMsg.fromJson(Map<String, dynamic> j) => ClientMsg(
    type: j['type'] as String,
    payload: j['payload'] as Map<String, dynamic>? ?? {},
  );
}

class CreateRoomMsg {
  final String playerName;
  const CreateRoomMsg({required this.playerName});

  ClientMsg toMsg() => ClientMsg(
    type: 'createRoom',
    payload: {'playerName': playerName},
  );
}

class JoinRoomMsg {
  final String roomCode;
  final String playerName;
  const JoinRoomMsg({required this.roomCode, required this.playerName});

  ClientMsg toMsg() => ClientMsg(
    type: 'joinRoom',
    payload: {'roomCode': roomCode, 'playerName': playerName},
  );
}

class ReadyMsg {
  const ReadyMsg();
  ClientMsg toMsg() => const ClientMsg(type: 'ready', payload: {});
}

class PlayCardsMsg {
  final List<String> cardKeys;
  const PlayCardsMsg({required this.cardKeys});

  ClientMsg toMsg() => ClientMsg(
    type: 'playCards',
    payload: {'cardKeys': cardKeys},
  );
}

class PassMsg {
  const PassMsg();
  ClientMsg toMsg() => const ClientMsg(type: 'pass', payload: {});
}

class TributeGiveMsg {
  final String cardKey;
  const TributeGiveMsg({required this.cardKey});

  ClientMsg toMsg() => ClientMsg(
    type: 'tributeGive',
    payload: {'cardKey': cardKey},
  );
}

class TributeReturnMsg {
  final String cardKey;
  const TributeReturnMsg({required this.cardKey});

  ClientMsg toMsg() => ClientMsg(
    type: 'tributeReturn',
    payload: {'cardKey': cardKey},
  );
}
