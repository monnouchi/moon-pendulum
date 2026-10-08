extends RefCounted
## Fixed, sparse tool marks. Light from a sounding bell stays above its patina.
const FINISHES = [
	{"body":Color("354852"),"edge":Color("929c91"),"patina":Color("416a65")},
	{"body":Color("5c5141"),"edge":Color("ad9e79"),"patina":Color("507361")},
	{"body":Color("4c525b"),"edge":Color("a5a798"),"patina":Color("57696b")},
	{"body":Color("364e49"),"edge":Color("96a793"),"patina":Color("557d68")},
	{"body":Color("514a38"),"edge":Color("aa9569"),"patina":Color("496f60")},
	{"body":Color("435451"),"edge":Color("a0a38a"),"patina":Color("4d7666")}
]

static func motif(canvas: CanvasItem, center: Vector2, kind: int, color: Color, scale: float = 1.0) -> void:
	match kind:
		0:
			for x in [-4.0,0.0,4.0]:canvas.draw_line(center+Vector2(x,-3)*scale,center+Vector2(x,3)*scale,color,0.75,true)
		1:
			canvas.draw_arc(center+Vector2(0,1)*scale,4*scale,PI,TAU,12,color,0.8,true)
			canvas.draw_line(center+Vector2(-4,2)*scale,center+Vector2(4,2)*scale,color,0.75,true)
		2:
			canvas.draw_polyline(PackedVector2Array([center+Vector2(-5,-2)*scale,center+Vector2(-2,2)*scale,center+Vector2(0,-1)*scale,center+Vector2(2,2)*scale,center+Vector2(5,-2)*scale]),color,0.8,true)
		3:
			for side in [-1.0,1.0]:canvas.draw_line(center+Vector2(-4,side*3)*scale,center, color,0.8,true)
			canvas.draw_line(center,center+Vector2(4,0)*scale,color,0.8,true)
		4:
			canvas.draw_polyline(PackedVector2Array([center+Vector2(-4,0)*scale,center+Vector2(0,-3)*scale,center+Vector2(4,0)*scale,center+Vector2(0,3)*scale,center+Vector2(-4,0)*scale]),color,0.8,true)
		_:
			canvas.draw_line(center-Vector2(5,1)*scale,center+Vector2(5,1)*scale,color,0.8,true)

static func frame(canvas: CanvasItem, pivot: Vector2, length: float, width: float, kind: int) -> void:
	var finish: Dictionary = FINISHES[kind]
	var top := pivot.y-28.0
	var half := minf(width*0.38,length*0.90)
	var lower := pivot.y+length+42.0
	for side in [-1.0,1.0]:
		var x: float = pivot.x+side*half
		canvas.draw_line(Vector2(x,top+21),Vector2(x,lower),finish["body"].darkened(0.40),8.0)
		canvas.draw_line(Vector2(x-side*7,top+25),Vector2(x-side*7,lower-2),Color(finish["patina"],0.48),1.0)
		for mark in range(10):
			var y := lerpf(top+32,lower-9,float(mark)/10.0)
			var offset := float((mark*7+kind*3)%5)-2.0
			canvas.draw_line(Vector2(x+offset,y),Vector2(x+offset-0.7,y+5+float(mark%3)),Color(finish["patina"],0.34),1.3,true)
			if mark%3==0:canvas.draw_line(Vector2(x+side*3,y+8),Vector2(x+side*3,y+12),Color(finish["edge"],0.35),0.85,true)
		canvas.draw_line(Vector2(x-6,top+23),Vector2(x+6,top+23),Color(finish["edge"],0.62),1.2,true)
		canvas.draw_line(Vector2(x-6,lower-3),Vector2(x+6,lower-3),Color(finish["edge"],0.36),1.2,true)
		motif(canvas,Vector2(x,top+34),kind,Color(finish["edge"],0.57),0.75)
	canvas.draw_line(Vector2(pivot.x-half-16,top+13),Vector2(pivot.x+half+16,top+13),finish["body"].darkened(0.18),7.0)
	canvas.draw_line(Vector2(pivot.x-half-16,top+9),Vector2(pivot.x+half+16,top+9),Color(finish["edge"],0.67),1.2)
	for mark in range(18):
		var x := lerpf(pivot.x-half-10,pivot.x+half+10,float(mark)/18.0)
		canvas.draw_line(Vector2(x,top+12+float(mark%2)),Vector2(x+4+float(mark%4),top+13+float(mark%2)),Color(finish["patina"],0.50),1.5,true)
		if mark%4==0:canvas.draw_line(Vector2(x+3,top+9),Vector2(x+8,top+9),Color(finish["edge"],0.82),0.8,true)
	for side in [-1.0,1.0]:motif(canvas,Vector2(pivot.x+side*half*0.65,top+13),kind,Color(finish["edge"],0.58),0.7)

static func bell(canvas: CanvasItem, pos: Vector2, kind: int, index: int, glow: float, light: Color, white: Color) -> void:
	var finish: Dictionary = FINISHES[kind]
	canvas.draw_colored_polygon(PackedVector2Array([pos+Vector2(-8,-11),pos+Vector2(8,-11),pos+Vector2(11,7),pos+Vector2(-11,7)]),finish["body"].lerp(light,glow))
	var quiet := 1.0-glow*0.80
	canvas.draw_colored_polygon(PackedVector2Array([pos+Vector2(-7,-9),pos+Vector2(-3,-8),pos+Vector2(-2,-3),pos+Vector2(-7,-1)]),Color(finish["patina"],quiet*0.65))
	canvas.draw_line(pos+Vector2(6,-8),pos+Vector2(8,3),Color(finish["body"].darkened(0.60),quiet*0.55),1.2,true)
	canvas.draw_line(pos+Vector2(-5+index%3,-5),pos+Vector2(-3+index%3,-2),Color(finish["edge"],quiet*0.34),0.7,true)
	motif(canvas,pos+Vector2(1,-2),kind,Color(finish["edge"],quiet*0.64),0.65)
	canvas.draw_line(pos+Vector2(-11,7),pos+Vector2(11,7),finish["edge"].lerp(white,glow),1.5)
	canvas.draw_line(pos+Vector2(-10,5),pos+Vector2(-5,5),Color(finish["edge"],quiet*0.57),0.8,true)
