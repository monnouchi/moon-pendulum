extends RefCounted
## Shared musical home for physical bells, small moons and the continuing score.
## Reference WAVs remain fixed; playback rates select these pitches without synthesis.
const BELL_REFERENCE = [50,57,62,64,66,71,74]
const ECHO_REFERENCE = [62,71,66,74]
const NIGHTS = [
	{"root":"D","mode":"major pentatonic","chord":"Dadd9","pitch_classes":[2,4,6,9,11],
	"bells":[50,57,62,64,66,71,74],"bell_names":["D3","A3","D4","E4","F♯4","B4","D5"],
	"echoes":[62,71,66,74],"echo_names":["D4","B4","F♯4","D5"],"replies":[78,81],
	"bpm":58.0,"steps":16,"bass":38,"base":[[0,50,0.68],[8,57,0.52],[12,62,0.40]],
	"layers":[[[4,74,0.72],[12,76,0.60]],[[2,78,0.64],[8,81,0.62],[14,78,0.55]],[[0,86,0.60],[6,83,0.56],[10,81,0.58],[15,83,0.46]]]},
	{"root":"A","mode":"dorian","chord":"Am6 / Am9","pitch_classes":[9,11,0,2,4,6,7],
	"bells":[57,59,60,62,64,66,69],"bell_names":["A3","B3","C4","D4","E4","F♯4","A4"],
	"echoes":[60,66,72,78],"echo_names":["C4","F♯4","C5","F♯5"],"replies":[72,78],
	"bpm":66.0,"steps":12,"bass":45,"base":[[0,45,0.64],[6,52,0.56]],
	"layers":[[[0,69,0.65],[6,72,0.58]],[[3,78,0.62],[9,71,0.54]],[[2,79,0.58],[8,76,0.54]],[[5,81,0.56],[11,79,0.50]]]},
	{"root":"E","mode":"minor ninth","chord":"Em9","pitch_classes":[4,6,7,11,2],
	"bells":[52,59,64,66,67,74,76],"bell_names":["E3","B3","E4","F♯4","G4","D5","E5"],
	"echoes":[64,71,67,78],"echo_names":["E4","B4","G4","F♯5"],"replies":[67,78],
	"bpm":54.0,"steps":18,"bass":40,"base":[[0,52,0.60],[12,59,0.44]],
	"layers":[[[2,67,0.66],[8,71,0.54]],[[6,78,0.60],[14,74,0.54]]]},
	{"root":"G","mode":"suspended ninth","chord":"G9sus4","pitch_classes":[7,9,0,2,5],
	"bells":[55,62,67,69,72,77,79],"bell_names":["G3","D4","G4","A4","C5","F5","G5"],
	"echoes":[67,74,72,77],"echo_names":["G4","D5","C5","F5"],"replies":[72,77],
	"bpm":68.0,"steps":16,"bass":43,"base":[[0,43,0.62],[8,50,0.48]],
	"layers":[[[0,67,0.64],[6,72,0.60],[11,74,0.54]],[[3,69,0.60],[8,77,0.56],[14,79,0.50]]]},
	{"root":"D","mode":"major ninth","chord":"Dmaj9","pitch_classes":[2,4,6,9,1],
	"bells":[50,57,61,64,66,69,74],"bell_names":["D3","A3","C♯4","E4","F♯4","A4","D5"],
	"echoes":[62,69,73,76],"echo_names":["D4","A4","C♯5","E5"],"replies":[85,88],
	"bpm":62.0,"steps":24,"bass":38,"base":[[0,50,0.66],[12,57,0.54]],
	"layers":[[[0,74,0.65],[6,78,0.58],[12,81,0.60],[18,74,0.54]],[[3,76,0.60],[9,73,0.56],[15,78,0.56],[21,81,0.50]],[[2,86,0.56],[8,85,0.52],[14,81,0.54],[20,85,0.50]],[[5,78,0.56],[11,81,0.54],[17,88,0.56],[23,86,0.46]]]}
]
