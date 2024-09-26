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

@export var max_float_offset = 0
@export_range(0.0, 0.1) var float_speed = 0.0
@export_range(1, 8) var async_float_count = 1


var spectrum
var min_values = []
var max_values = []
var data = []
var cur_rotation_offset = rotation_offset
var cur_float_offsets = [0]
var cur_float_speeds = [float_speed]



func _ready():
	spectrum = AudioServer.get_bus_effect_instance(0, 0)
	min_values.resize(line_count)
	max_values.resize(line_count)
	min_values.fill(0.0)
	max_values.fill(0.0)
	data.resize(line_count)
	data.fill(0.0)
	cur_rotation_offset = rotation_offset
	
	init_float_variables()
	
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
	
	cur_rotation_offset += rotation_speed
	adjust_float();
	
	queue_redraw()


func _draw():
	var circle_segment = TAU / line_count

	for i in range(line_count):
		var float_async_index = i % async_float_count
		var float_direction = 1 if i % 2 == 0 else -1
		var cur_radius = inner_radius + (cur_float_offsets[float_async_index]) * float_direction

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
			if rotation_speed == 0:
				cur_rotation_offset = rotation_offset
		
		draw_colored_polygon(
			[
				Vector2(cur_radius * cos(circle_segment * i - circle_segment / 2 + gutter + cur_rotation_offset), cur_radius * sin(circle_segment * i - circle_segment / 2 + gutter + cur_rotation_offset)),
				Vector2(cur_radius * cos(circle_segment * i + circle_segment / 2 - gutter + cur_rotation_offset), cur_radius * sin(circle_segment * i + circle_segment / 2 - gutter + cur_rotation_offset)),
				Vector2((cur_radius + height) * cos(circle_segment * i + cur_rotation_offset), (cur_radius + height) * sin(circle_segment * i + cur_rotation_offset)),
			],
			color,
		)
		
		draw_colored_polygon(
			[
				Vector2(cur_radius * cos(circle_segment * i - circle_segment / 2 + gutter + cur_rotation_offset), cur_radius * sin(circle_segment * i - circle_segment / 2 + gutter + cur_rotation_offset)),
				Vector2(cur_radius * cos(circle_segment * i + circle_segment / 2 - gutter + cur_rotation_offset), cur_radius * sin(circle_segment * i + circle_segment / 2 - gutter + cur_rotation_offset)),
				Vector2((cur_radius - (height / 2)) * cos(circle_segment * i + cur_rotation_offset), (cur_radius - (height / 2)) * sin(circle_segment * i + + cur_rotation_offset)),
			],
			color,
		)


func adjust_float(): 
	for i in cur_float_offsets.size():
		if (abs(cur_float_offsets[i]) == max_float_offset):
			cur_float_speeds[i] = - cur_float_speeds[i]
		cur_float_offsets[i] += cur_float_speeds[i]
		if (abs(cur_float_offsets[i]) > max_float_offset):
			cur_float_offsets[i] = sign(cur_float_offsets[i]) * max_float_offset 


func init_float_variables():
	cur_float_offsets.resize(async_float_count)
	cur_float_speeds.resize(async_float_count)
	
	cur_float_offsets.fill(0)
	for n in async_float_count:
		cur_float_speeds[n] = float_speed / (n + 2.0) + float_speed / 2
