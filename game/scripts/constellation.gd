extends RefCounted
## Each light keeps its own score layer. The later nights ask for finer releases.
const NIGHTS = [
	{"name":"オリオン座の夜","targets":[0.55,-0.80,0.68],"kinds":["main","main","relay"],"strokes":3,"main_tolerance":0.15,"echo_tolerance":0.095},
	{"name":"こと座の夜","targets":[0.65,0.50],"kind":"duet","inward":[false,true],"strokes":2,"echo_tolerance":0.085},
	{"name":"カシオペヤ座の夜","targets":[-0.92,-0.72],"kinds":["main","relay"],"strokes":2,"main_tolerance":0.06,"echo_tolerance":0.065},
	{"name":"はくちょう座の夜","targets":[-0.70,0.78],"kind":"relay","strokes":2,"echo_tolerance":0.05},
	{"name":"さそり座の夜","targets":[0.78,0.60],"kind":"duet","inward":[false,true],"strokes":2,"echo_tolerance":0.045}
]
