extends RefCounted
## Major-star arrangements checked against IAU / Sky & Telescope star charts.
## Approximate chart-plane positions, north up; fit uniformly without stretching.
## Independent simplified vector drawings of factual star arrangements.
## Sources: https://iauarchive.eso.org/public/themes/constellations/
const FIGURES = [
	{"code":"ORI", "stars":["Betelgeuse","Bellatrix","Alnitak","Alnilam","Mintaka","Saiph","Rigel"],
	"points":[Vector2(396,539),Vector2(523,557),Vector2(456,699),Vector2(476,686),Vector2(494,672),Vector2(425,830),Vector2(570,806)],
	"edges":[[0,1],[0,2],[2,3],[3,4],[4,1],[2,5],[4,6],[5,6]], "goals":[[2],[3],[4]]},
	{"code":"LYR", "stars":["Vega","epsilon Lyr","zeta Lyr","delta Lyr","gamma Lyr","beta Lyr"],
	"points":[Vector2(559,351),Vector2(526,334),Vector2(525,380),Vector2(480,397),Vector2(458,491),Vector2(500,478)],
	"edges":[[0,1],[1,2],[2,0],[2,3],[3,4],[4,5],[5,2]], "goals":[[2,5],[3,4]]},
	{"code":"CAS", "stars":["epsilon Cas","delta Cas","gamma Cas","alpha Cas","beta Cas"],
	"points":[Vector2(398,406),Vector2(446,473),Vector2(507,467),Vector2(547,537),Vector2(612,484)],
	"edges":[[0,1],[1,2],[2,3],[3,4]], "goals":[[1],[3]]},
	{"code":"CYG", "stars":["Deneb","gamma Cyg","Albireo","delta Cyg","epsilon Cyg","zeta Cyg"],
	"points":[Vector2(468,574),Vector2(528,660),Vector2(733,849),Vector2(637,568),Vector2(444,766),Vector2(340,820)],
	"edges":[[0,1],[1,2],[1,3],[1,4],[4,5],[5,0]], "goals":[[3],[4]]},
	{"code":"SCO", "stars":["beta Sco","delta Sco","pi Sco","sigma Sco","Antares","tau Sco","epsilon Sco","mu Sco","zeta Sco","eta Sco","theta Sco","iota Sco","kappa Sco","Shaula","Lesath"],
	"points":[Vector2(663,453),Vector2(680,502),Vector2(680,562),Vector2(595,547),Vector2(563,560),Vector2(537,590),Vector2(484,694),Vector2(478,758),Vector2(470,831),Vector2(415,850),Vector2(333,852),Vector2(293,807),Vector2(307,787),Vector2(333,751),Vector2(344,752)],
	"edges":[[0,1],[1,2],[1,3],[3,4],[4,5],[5,6],[6,7],[7,8],[8,9],[9,10],[10,11],[11,12],[12,13],[13,14]], "goals":[[4,5],[13,14]]}
]

static func bounds(points: Array) -> Rect2:
	var result := Rect2(points[0],Vector2.ZERO)
	for point in points:
		result = result.expand(point)
	return result

static func fit(index: int, area: Rect2) -> PackedVector2Array:
	var points: Array = FIGURES[index]["points"]
	var box := bounds(points)
	var scale := minf(area.size.x/box.size.x,area.size.y/box.size.y)
	var result := PackedVector2Array()
	for point in points:
		result.append(area.get_center()+(point-box.get_center())*scale)
	return result
