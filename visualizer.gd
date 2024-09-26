@tool
extends Node2D


@export var line_count = 32
@export_range(0, 10) var gutter_ratio = 6

@export var inner_radius = 256.0
@export var outer_radius = 512.0
@export var min_line_height = 16.0
@export_range(0.0, 360.0, 1.0, "radians_as_degrees") var rotation_offset = 0.0

@export_range(0.0, 20000.0, 1.0, "suffix:hz") var frequency_max = 6000.0
@export_range(0.0, 20000.0, 1.0, "suffix:hz") var frequency_min = 500.0
@export var exponential_frequency_step = true
@export_range(0, 100, 1, "suffix:dB") var db_treshold = 60

@export_range(0.01, 0.5) var animation_speed = 0.1

var spectrum
var min_values = []
var max_values = []
var data = []


func _ready():
	spectrum = AudioServer.get_bus_effect_instance(0, 0)
	min_values.resize(line_count)
	max_values.resize(line_count)
	min_values.fill(0.0)
	max_values.fill(0.0)
	data.resize(line_count)
	data.fill(0.0)
	
	queue_redraw()


func _process(delta):
	data = []
	var prev_hz = 0
	
	var exp = log(frequency_max) / log(line_count)
	var linear_step = frequency_max / line_count
	for i in range(1, line_count + 1):
		var to_hz = pow(i, exp) if exponential_frequency_step else prev_hz + linear_step
		var magnitude = spectrum.get_magnitude_for_frequency_range(prev_hz, to_hz, AudioEffectSpectrumAnalyzerInstance.MAGNITUDE_AVERAGE).length()
		var energy = clampf((db_treshold + linear_to_db(magnitude)) / db_treshold, 0, 1)
		var height = energy * (outer_radius - inner_radius)
		data.append(height)
		prev_hz = to_hz
	
	for i in range(line_count):
		if data[i] > max_values[i]:
			max_values[i] = data[i]
		else:
			max_values[i] = lerp(max_values[i], data[i], animation_speed)

		if data[i] <= 0.0:
			min_values[i] = lerp(min_values[i], min_line_height, animation_speed)
	
	queue_redraw()


func _draw():
	var circle_segment = TAU / line_count
	var gutter = circle_segment / gutter_ratio
	for i in range(line_count):
		var min_height = min_values[i]
		var max_height = max_values[i]
		var height = clamp(lerp(min_height, max_height, 1), min_line_height, outer_radius - inner_radius)
		var color = "#fff"
		
		if Engine.is_editor_hint():
			height = outer_radius - inner_radius
			if i == 0:
				color = "#0f0"
		
		draw_colored_polygon(
			[
				Vector2(inner_radius * cos(circle_segment * i - circle_segment / 2 + gutter + rotation_offset), inner_radius * sin(circle_segment * i - circle_segment / 2 + gutter + rotation_offset)),
				Vector2(inner_radius * cos(circle_segment * i + circle_segment / 2 - gutter + rotation_offset), inner_radius * sin(circle_segment * i + circle_segment / 2 - gutter + rotation_offset)),
				Vector2((inner_radius + height) * cos(circle_segment * i + circle_segment / 2 - gutter + rotation_offset), (inner_radius + height) * sin(circle_segment * i + circle_segment / 2 - gutter + rotation_offset)),
				Vector2((inner_radius + height) * cos(circle_segment * i - circle_segment / 2 + gutter + rotation_offset), (inner_radius + height) * sin(circle_segment * i - circle_segment / 2 + gutter + rotation_offset)),
			],
			color,
		)


func _on_audio_stream_player_finished() -> void:
	get_tree().quit()
