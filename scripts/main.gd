# A Generator client
#
# A server must be online on localhost, 
# The interface provide two interactions:
#  - Generate, use to call the server to generate a new word
#  - Set n-gram, to change n-gram used by the server (can recompute!)
class_name Generator
extends Node

# Private
var _isPlaying := true
var _id := 0
var _rpm := 0
var _headers := ["Content-Type:application/json"]

# Preloads 
var _muted = preload("res://assets/images/Muted.png")
var _unmuted = preload("res://assets/images/Unmuted.png")

# Reference to child nodes
onready var _terminal: RichTextLabel = $Terminal
onready var _ngram_button: Button = $HBoxContainer/ChangeNGram
onready var _generate_button: Button = $HBoxContainer/GenerateButton
onready var _sound_state: Sprite = $SoundButton/SoundState
onready var _ngram_request_get: HTTPRequest = $NGramGET
onready var _generate_request_get: HTTPRequest = $GenerateGET
onready var _ngram_request_put: HTTPRequest = $NGramPUT
onready var _ngram: SpinBox = $HBoxContainer/NGram

## Called when the node enters the scene tree for the first time
func _enter_tree() -> void:
	# Setup FMOD
	Fmod.set_software_format(0, Fmod.FMOD_SPEAKERMODE_STEREO, 0)
	Fmod.init(1024, Fmod.FMOD_STUDIO_INIT_LIVEUPDATE, Fmod.FMOD_INIT_NORMAL)
	Fmod.set_sound_3D_settings(1, 32, 1)
	
	# Load banks
	# warning-ignore:return_value_discarded
	Fmod.load_bank("res://assets/Banks/Master.strings.bank", Fmod.FMOD_STUDIO_LOAD_BANK_NORMAL)
	# warning-ignore:return_value_discarded
	Fmod.load_bank("res://assets/Banks/Master.bank", Fmod.FMOD_STUDIO_LOAD_BANK_NORMAL)
	# warning-ignore:return_value_discarded
	Fmod.load_bank("res://assets/Banks/Vehicles.bank", Fmod.FMOD_STUDIO_LOAD_BANK_NORMAL)

## Called when the node is "ready", i.e. when both the node and its children have entered the scene tree
func _ready() -> void:
	# FMOD sounds setup
	_id = Fmod.create_event_instance("event:/Vehicles/Car Engine")
	Fmod.attach_instance_to_node(_id, self)
	Fmod.set_event_volume(_id, 2)
	Fmod.start_event(_id)
	Fmod.add_listener(0, self)

	# Setup termnal and call ngram
	_terminal.bbcode_text = _terminal.bbcode_text + '\n' + "[color=#FF0000]Get data from server..."
	_ngram_button.text = "Get n-gram"
	_generate_button.grab_focus()
	_sound_state.set_texture(_unmuted)

	# warning-ignore:return_value_discarded
	# GET n-gram request
	_ngram_request_get.request("http://127.0.0.1:4242/v1/ngram")

## Called during the processing step of the main loop
# warning-ignore:unused_argument
func _process(delta: float):
	# Check if space is pressed
	if Input.is_action_just_pressed("space"):
		_toggle_sound()

## Toggle sound pause
func _toggle_sound() -> void:
	_isPlaying = !_isPlaying
	if(_isPlaying):
		_sound_state.set_texture(_unmuted)
		Fmod.set_event_paused(_id, false)
	else:
		_sound_state.set_texture(_muted)
		Fmod.set_event_paused(_id, true)

## On generate button is pressed
func _on_GenerateButton_pressed() -> void:
	# RPM variable update
	_rpm = _rpm + 100
	Fmod.set_event_parameter_by_name(_id, "RPM", _rpm)

	# warning-ignore:return_value_discarded
	# GET generate request
	_generate_request_get.request("http://127.0.0.1:4242/v1/generate")

## On change n-gram button is pressed
func _on_ChangeNGram_pressed() -> void:
	# Change UI status
	_generate_button.disabled = true
	_ngram_button.disabled = true
	_ngram.editable = false

	# Add info in terminal
	_terminal.bbcode_text = _terminal.bbcode_text + '\n' + "[color=#00FF00]run generator.py -ngram " + str(_ngram.value) + " -load database[/color]"
	_terminal.bbcode_text = _terminal.bbcode_text + '\n' + "[color=#FF0000]Waiting for reconfiguration..."
	
	# warning-ignore:return_value_discarded
	# PUT n-gram request
	_ngram_request_put.request("http://127.0.0.1:4242/v1/ngram", _headers, true, HTTPClient.METHOD_PUT, str(_ngram.value))

## On RPM down timeout
func _on_RPMDown_timeout() -> void:
	# RPM variable update
	if _rpm > 0:
		var tmp = _rpm - 10
		_rpm = tmp if tmp > 0 else 0
		Fmod.set_event_parameter_by_name(_id, "RPM", _rpm)

# warning-ignore:unused_argument
## On n-gram value changed
func _on_NGram_value_changed(value: int) -> void:
	# Change focus to the n-gram button
	_ngram_button.grab_focus()

# warning-ignore:unused_argument
# warning-ignore:unused_argument
# warning-ignore:unused_argument
## On generate get request is completed
func _on_GenerateGET_request_completed(result: int, response_code: int, headers: PoolStringArray, body: PoolByteArray) -> void:
	var json: JSONParseResult = JSON.parse(body.get_string_from_utf8())
	_terminal.bbcode_text = _terminal.bbcode_text + '\n' + str(json.result)

# warning-ignore:unused_argument
# warning-ignore:unused_argument
## On n-gram get request is completed
func _on_NGramGET_request_completed(result: int, response_code: int, headers: PoolStringArray, body: PoolByteArray) -> void:
	# If response_code = 0 then the server is offline
	if response_code != 0:
		# Get JSON data
		var json: JSONParseResult = JSON.parse(body.get_string_from_utf8())

		# Write done in terminal
		_terminal.bbcode_text = _terminal.bbcode_text + "done[/color]"

		# Change UI status
		_generate_button.disabled = false
		_ngram_button.text = "Set n-gram"
		_ngram_button.disabled = false
		_ngram.editable = true
		_ngram.value = json.result
	else:
		# Write server offline
		_terminal.bbcode_text = _terminal.bbcode_text + "server offline[/color]"

		# Change UI status
		_generate_button.disabled = true
		_ngram_button.text = "Get n-gram"
		_ngram_button.disabled = false
		_ngram.editable = false
		_ngram_button.grab_focus()

# warning-ignore:unused_argument
# warning-ignore:unused_argument
# warning-ignore:unused_argument
# warning-ignore:unused_argument
## On n-gram put request is completed
func _on_NGramPUT_request_completed(result: int, response_code: int, headers: PoolStringArray, body: PoolByteArray) -> void:
	# warning-ignore:return_value_discarded
	# n-gram get request
	_ngram_request_get.request("http://127.0.0.1:4242/v1/ngram")

## On sound button pressed
func _on_SoundButton_pressed() -> void:
	_toggle_sound()
