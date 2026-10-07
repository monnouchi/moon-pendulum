extends RefCounted
## One local-horizon tangent plane for catalog stars, targets and the sky Moon.
const DATA = preload("res://scripts/sky_data.gd")
const FIGURES = preload("res://scripts/sky_figures.gd")

static func scene(index: int) -> Dictionary:
	return DATA.SCENES[index]

static func fit(index: int, area: Rect2) -> Dictionary:
	var raw: Array = []
	for star in scene(index)["targets"]:
		raw.append(Vector2(float(star[1]),float(star[2])))
	var box: Rect2 = FIGURES.bounds(raw)
	var scale := minf(area.size.x/box.size.x,area.size.y/box.size.y)
	var offset := area.get_center()-box.get_center()*scale
	var points := PackedVector2Array()
	for p in raw:points.append(p*scale+offset)
	return {"scale":scale,"offset":offset,"points":points}

static func point(row: Array, fitted: Dictionary) -> Vector2:
	return Vector2(float(row[1]),float(row[2]))*float(fitted["scale"])+fitted["offset"]

static func horizon(index: int, fitted: Dictionary) -> float:
	return float(scene(index)["horizon"])*float(fitted["scale"])+fitted["offset"].y

static func moon_visible(index: int) -> bool:
	var moon: Dictionary = scene(index)["moon"]
	return float(moon["alt"])>0.0 and float(moon["front"])>0.05

static func moon_point(index: int, fitted: Dictionary) -> Vector2:
	var p: Array = scene(index)["moon"]["xy"]
	return Vector2(float(p[0]),float(p[1]))*float(fitted["scale"])+fitted["offset"]

static func reflection(index: int, fitted: Dictionary, bottom: float) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var data := scene(index)
	var moon: Dictionary = data["moon"]
	var water_top := horizon(index,fitted)
	if data["season"]!="summer" or not moon_visible(index) or water_top+20.0>=bottom:
		return result
	var az := deg_to_rad(float(data["center_az"]))
	var pitch := deg_to_rad(float(data["center_alt"]))
	var moon_az := deg_to_rad(float(moon["az"]))
	var moon_alt := deg_to_rad(float(moon["alt"]))
	var difference := moon_az-az
	if cos(difference)<=0.0:return result
	var light := Vector3(sin(moon_az)*cos(moon_alt),cos(moon_az)*cos(moon_alt),sin(moon_alt))
	var forward := Vector3(sin(az)*cos(pitch),cos(az)*cos(pitch),sin(pitch))
	for i in range(16):
		var y := lerpf(water_top+18.0,bottom,float(i)/15.0)
		var py: float = (y-fitted["offset"].y)/float(fitted["scale"])
		var altitude := atan2((sin(pitch)-py*cos(pitch))*cos(difference),cos(pitch)+py*sin(pitch))
		var ray := Vector3(sin(moon_az)*cos(altitude),cos(moon_az)*cos(altitude),sin(altitude))
		var front := ray.dot(forward)
		if front<=0.05:continue
		var x: float = fitted["offset"].x+float(fitted["scale"])*cos(altitude)*sin(difference)/front
		# The glint is strongest where the Moon / viewing-ray bisector is vertical.
		# A finite lobe represents small wave slopes rather than a perfect mirror.
		var normal := (light-ray).normalized()
		var strength := pow(maxf(0.0,normal.z),64.0)*float(moon["illum"])
		if strength>0.02:result.append({"pos":Vector2(x,y),"strength":strength,"row":i})
	return result
