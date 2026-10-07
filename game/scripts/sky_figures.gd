extends RefCounted
## Gameplay identities and simplified connections; observed positions are in sky_data.gd.
## HR identifies the representative bright component of an unresolved multiple star.
## IAU charts remain a reference for names and the independent connection drawings.
## Sources: https://iauarchive.eso.org/public/themes/constellations/
const FIGURES = [
	{"code":"ORI", "stars":["Betelgeuse","Bellatrix","Alnitak","Alnilam","Mintaka","Saiph","Rigel"],
	"hr":[2061,1790,1948,1903,1852,2004,1713],
	"edges":[[0,1],[0,2],[2,3],[3,4],[4,1],[2,5],[4,6],[5,6]], "goals":[[2],[3],[4]]},
	{"code":"LYR", "stars":["Vega","epsilon Lyr","zeta Lyr","delta Lyr","gamma Lyr","beta Lyr"],
	"hr":[7001,7051,7056,7139,7178,7106],
	"edges":[[0,1],[1,2],[2,0],[2,3],[3,4],[4,5],[5,2]], "goals":[[2,5],[3,4]]},
	{"code":"CAS", "stars":["epsilon Cas","delta Cas","gamma Cas","alpha Cas","beta Cas"],
	"hr":[542,403,264,168,21],
	"edges":[[0,1],[1,2],[2,3],[3,4]], "goals":[[1],[3]]},
	{"code":"CYG", "stars":["Deneb","gamma Cyg","Albireo","delta Cyg","epsilon Cyg","zeta Cyg"],
	"hr":[7924,7796,7417,7528,7949,8115],
	"edges":[[0,1],[1,2],[1,3],[1,4],[4,5],[5,0]], "goals":[[3],[4]]},
	{"code":"SCO", "stars":["beta Sco","delta Sco","pi Sco","sigma Sco","Antares","tau Sco","epsilon Sco","mu Sco","zeta Sco","eta Sco","theta Sco","iota Sco","kappa Sco","Shaula","Lesath"],
	"hr":[5984,5953,5944,6084,6134,6165,6241,6247,6271,6380,6553,6615,6580,6527,6508],
	"edges":[[0,1],[1,2],[1,3],[3,4],[4,5],[5,6],[6,7],[7,8],[8,9],[9,10],[10,11],[11,12],[12,13],[13,14]], "goals":[[4,5],[13,14]]}
]

static func bounds(points: Array) -> Rect2:
	var result := Rect2(points[0],Vector2.ZERO)
	for point in points:
		result = result.expand(point)
	return result
