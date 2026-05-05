@tool
extends EditorScript

const GeometryExporter := preload("res://scripts/editor/GeometryGLBExporter.gd")

func _run() -> void:
	var exporter := GeometryExporter.new()
	var result := exporter.export_all()
	for line in result:
		print(line)
