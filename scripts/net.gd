extends Node
## Duelo por Wi-Fi local (autoload "Net"): sala, búsqueda de partidas en la red
## y mensajes de la partida.
##
## Los turnos son alternos y cada móvil simula sus propios golpes: mientras
## tira, envía al otro las posiciones de las bolas y los "eventos" que el otro
## debe mostrar (gritos, bailes, resultados). Al acabar cada tiro manda el
## estado completo (golpes, quién ha embocado, puntuaciones) y cede el turno.

signal players_changed
signal games_changed
## Conectado a una sala como invitado.
signal joined
## Se perdió la conexión. `reason` es una clave de traducción. No se emite al
## salir uno mismo.
signal left(reason: String)
## El anfitrión ha empezado la partida en ese mundo.
signal game_started(world: int)
## Posiciones de las bolas del jugador que tira: [[pos, visible], ...] por puesto.
signal balls_received(states: Array)
## Apuntado del jugador que tira: dirección, barra, fuerza fijada y fase.
signal aim_received(yaw: float, meter: float, power: float, phase: String)
## Algo que hay que mostrar (golpe, grito, baile, resultado...).
signal event_received(name: String, args: Array)
## Estado completo de la partida tras un tiro.
signal sync_received(data: Dictionary)

const GAME_PORT := 45134
const DISCOVERY_PORT := 45133
const DISCOVERY_TAG := "CM2026"
const MAX_PLAYERS := 2

## id -> {name, slot}  (slot 0 = anfitrión, 1 = invitado)
var players := {}
var in_game := false
## Partidas encontradas en la red. ip -> {name, players, seen}
var found_games := {}

var _pending_name := ""
var _beacon: PacketPeerUDP
var _beacon_timer := 0.0
var _listener: PacketPeerUDP


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	# Cambiar la conexión dentro de sus propios avisos puede tumbar el motor:
	# se hace un instante después.
	multiplayer.connection_failed.connect(func() -> void: _lost.call_deferred("NET_CONNECT_FAILED"))
	multiplayer.server_disconnected.connect(func() -> void: _lost.call_deferred("NET_HOST_CLOSED"))


func is_online() -> bool:
	return not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer)


func is_host() -> bool:
	return is_online() and multiplayer.is_server()


func my_slot() -> int:
	return players.get(multiplayer.get_unique_id(), {}).get("slot", 0)


## Nombre del jugador en un puesto (0 anfitrión, 1 invitado).
func name_of_slot(slot: int) -> String:
	for info in players.values():
		if info["slot"] == slot:
			return info["name"]
	return "?"


# --- Sala -----------------------------------------------------------------------

func host(player_name: String) -> Error:
	leave()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(GAME_PORT, MAX_PLAYERS - 1)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	players = {1: {"name": player_name, "slot": 0}}
	stop_discovery()
	_beacon = PacketPeerUDP.new()
	_beacon.set_broadcast_enabled(true)
	_beacon.set_dest_address("255.255.255.255", DISCOVERY_PORT)
	players_changed.emit()
	return OK


func join(ip: String, player_name: String) -> Error:
	leave()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(ip, GAME_PORT)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	_pending_name = player_name
	return OK


func leave() -> void:
	if is_online():
		multiplayer.multiplayer_peer.close()
	_reset()


## Direcciones IPv4 de este dispositivo, la más probable primero (para que el
## anfitrión se la diga al otro si la búsqueda automática no funciona). Las
## 172.16-31 van al final: en un PC suelen ser adaptadores virtuales.
func local_ips() -> Array[String]:
	var ranked := []
	for ip in IP.get_local_addresses():
		if not ip.is_valid_ip_address() or ":" in ip or ip.begins_with("127.") \
				or ip.begins_with("169.254."):
			continue
		var rank := 2
		if ip.begins_with("192.168.") or ip.begins_with("10."):
			rank = 0
		elif _is_172_private(ip):
			rank = 3
		ranked.append([rank, ip])
	ranked.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var result: Array[String] = []
	for entry in ranked:
		result.append(entry[1])
	return result


func _is_172_private(ip: String) -> bool:
	var parts := ip.split(".")
	return parts.size() == 4 and parts[0] == "172" and int(parts[1]) >= 16 and int(parts[1]) <= 31


func _on_connected() -> void:
	_register.rpc_id(1, _pending_name)
	joined.emit()


@rpc("any_peer", "reliable")
func _register(player_name: String) -> void:
	if not multiplayer.is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	if in_game or players.size() >= MAX_PLAYERS:
		multiplayer.multiplayer_peer.disconnect_peer(id)
		return
	players[id] = {"name": player_name.strip_edges().left(14), "slot": 1}
	_sync_players.rpc(players)
	players_changed.emit()


@rpc("authority", "reliable")
func _sync_players(new_players: Dictionary) -> void:
	players = new_players
	players_changed.emit()


func _on_peer_disconnected(id: int) -> void:
	if not players.has(id):
		return
	players.erase(id)
	players_changed.emit()
	if in_game:
		in_game = false
		left.emit.call_deferred("NET_OTHER_LEFT")


func _lost(reason: String) -> void:
	_reset()
	left.emit(reason)


func _reset() -> void:
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	players.clear()
	in_game = false
	if _beacon != null:
		_beacon.close()
		_beacon = null


# --- Búsqueda de partidas en la red ------------------------------------------------

func start_discovery() -> void:
	stop_discovery()
	found_games.clear()
	_listener = PacketPeerUDP.new()
	if _listener.bind(DISCOVERY_PORT) != OK:
		_listener = null
	games_changed.emit()


func stop_discovery() -> void:
	if _listener != null:
		_listener.close()
		_listener = null


func _process(delta: float) -> void:
	# El anfitrión anuncia su sala cada segundo mientras no hay partida.
	if _beacon != null and not in_game:
		_beacon_timer -= delta
		if _beacon_timer <= 0.0:
			_beacon_timer = 1.0
			var info := "%s|%s|%d" % [DISCOVERY_TAG, players.get(1, {}).get("name", "?"), players.size()]
			_beacon.put_packet(info.to_utf8_buffer())

	if _listener != null:
		var changed := false
		while _listener.get_available_packet_count() > 0:
			var text := _listener.get_packet().get_string_from_utf8()
			var ip := _listener.get_packet_ip()
			var parts := text.split("|")
			if parts.size() == 3 and parts[0] == DISCOVERY_TAG:
				found_games[ip] = {"name": parts[1], "players": int(parts[2]),
					"seen": Time.get_ticks_msec()}
				changed = true
		for ip in found_games.keys():
			if Time.get_ticks_msec() - found_games[ip]["seen"] > 3500:
				found_games.erase(ip)
				changed = true
		if changed:
			games_changed.emit()


# --- Partida ------------------------------------------------------------------------

func start_game(world: int) -> void:
	if is_host() and players.size() == MAX_PLAYERS:
		_start.rpc(world)


@rpc("authority", "call_local", "reliable")
func _start(world: int) -> void:
	in_game = true
	game_started.emit(world)


## Posiciones de las bolas (muchas veces por segundo, sin garantía de entrega).
func send_balls(states: Array) -> void:
	if is_online():
		_balls.rpc(states)


@rpc("any_peer", "call_remote", "unreliable_ordered")
func _balls(states: Array) -> void:
	balls_received.emit(states)


func send_aim(yaw: float, meter: float, power: float, phase: String) -> void:
	if is_online():
		_aim.rpc(yaw, meter, power, phase)


@rpc("any_peer", "call_remote", "unreliable_ordered")
func _aim(yaw: float, meter: float, power: float, phase: String) -> void:
	aim_received.emit(yaw, meter, power, phase)


func send_event(event_name: String, args: Array = []) -> void:
	if is_online():
		_event.rpc(event_name, args)


@rpc("any_peer", "call_remote", "reliable")
func _event(event_name: String, args: Array) -> void:
	event_received.emit(event_name, args)


func send_sync(data: Dictionary) -> void:
	if is_online():
		_sync.rpc(data)


@rpc("any_peer", "call_remote", "reliable")
func _sync(data: Dictionary) -> void:
	sync_received.emit(data)
