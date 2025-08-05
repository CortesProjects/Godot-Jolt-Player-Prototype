extends Node3D

var peer = ENetMultiplayerPeer.new()
@export var player_scene : PackedScene

func _on_server_pressed() -> void:
	print("Host")
	peer.create_server(1027)
	multiplayer.multiplayer_peer = peer
	multiplayer.peer_connected.connect(add_player)
	add_player()
	print("Host")
	$CanvasLayer/VBoxContainer/Server.hide()

func _on_client_pressed() -> void:
	peer.create_client("127.0.0.1", 1027)
	multiplayer.multiplayer_peer = peer
	$CanvasLayer/VBoxContainer/Client.hide()
	print("Join")


func add_player(id = 1):
	var player = player_scene.instantiate()
	player.name = str(id)
	call_deferred("add_child", player)

func exit_game(id):
	multiplayer.peer_disconnected.connect(delete_player)
	delete_player(id)

func delete_player(id):
	rpc("_delete_player", id)

@rpc("any_peer", "call_local")
func _delete_player(id):
	get_node(str(id)).queue_free()
