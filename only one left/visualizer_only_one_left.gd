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
@export_range(-0.1, 0.1) var rotation_speed = 0.0

@export var float_offset = 0
@export_range(0.0, 0.1) var float_speed = 0.0


var spectrum
var min_values = []
var max_values = []
var data = []
var cur_float = 0.0


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
	
	rotation_offset += rotation_speed
	adjust_float();
	
	queue_redraw()


func _draw():
	var circle_segment = TAU / line_count

	for i in range(line_count):
		var float_async_offset = i % 4 * float_offset / 3.0
		var float_direction = 1 if i % 2 == 0 else -1
		var cur_radius = inner_radius + (cur_float + float_async_offset) * float_direction

		var adjusted_segment = circle_segment * (cur_radius / inner_radius)
		var gutter = adjusted_segment / gutter_ratio
		
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
				Vector2(cur_radius * cos(circle_segment * i - circle_segment / 2 + gutter + rotation_offset), cur_radius * sin(circle_segment * i - circle_segment / 2 + gutter + rotation_offset)),
				Vector2(cur_radius * cos(circle_segment * i + circle_segment / 2 - gutter + rotation_offset), cur_radius * sin(circle_segment * i + circle_segment / 2 - gutter + rotation_offset)),
				Vector2((cur_radius + height) * cos(circle_segment * i + rotation_offset), (cur_radius + height) * sin(circle_segment * i + rotation_offset)),
			],
			color,
		)
		
		draw_colored_polygon(
			[
				Vector2(cur_radius * cos(circle_segment * i - circle_segment / 2 + gutter + rotation_offset), cur_radius * sin(circle_segment * i - circle_segment / 2 + gutter + rotation_offset)),
				Vector2(cur_radius * cos(circle_segment * i + circle_segment / 2 - gutter + rotation_offset), cur_radius * sin(circle_segment * i + circle_segment / 2 - gutter + rotation_offset)),
				Vector2((cur_radius - (height / 2)) * cos(circle_segment * i + rotation_offset), (cur_radius - (height / 2)) * sin(circle_segment * i + + rotation_offset)),
			],
			color,
		)
	
		
func adjust_float(): 
	if (abs(cur_float) == float_offset):
		float_speed = - float_speed
	cur_float += float_speed
	if (abs(cur_float) > float_offset):
		cur_float = sign(cur_float) * float_offset
