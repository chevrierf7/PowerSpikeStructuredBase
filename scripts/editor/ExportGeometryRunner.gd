@tool
extends Node

const GeometryExporter := preload("res://scripts/editor/GeometryGLBExporter.gd")

func _ready() -> void:
	var exporter := GeometryExporter.new()
	var result := exporter.export_all()
	for line in result:
		print(line)
	get_tree().quit()
