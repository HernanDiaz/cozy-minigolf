extends Node
## Música de fondo: un vals de piano por mundo (acompañamiento "um-pa-pa",
## melodía y colchón de acordes) sintetizado en un hilo la primera vez que se
## necesita, más pájaros de fondo de vez en cuando.

const RATE := 16000
# Cada pista: pulso en segundos, acordes (bajo + 2 notas MIDI) y melodía
# ([nota MIDI, pulsos] por compás de 3/4).
const TRACKS := [
	{
		"beat": 0.62,
		"chords": [
			[48, 64, 67], [45, 64, 69], [41, 65, 69], [43, 62, 67],
			[48, 64, 67], [40, 64, 71], [41, 65, 69], [43, 62, 65],
		],
		"melody": [
			[[76, 2], [79, 1]], [[81, 2], [79, 1]], [[77, 1], [76, 1], [74, 1]], [[74, 3]],
			[[76, 2], [79, 1]], [[83, 2], [81, 1]], [[81, 1], [79, 1], [77, 1]], [[74, 2], [71, 1]],
		],
		"birds": true,
	},
	{
		# Bosque: la menor, más lento y misterioso.
		"beat": 0.72,
		"chords": [
			[45, 64, 69], [41, 65, 69], [48, 64, 67], [43, 62, 67],
			[45, 64, 69], [38, 65, 69], [40, 64, 68], [40, 62, 68],
		],
		"melody": [
			[[76, 2], [72, 1]], [[77, 2], [76, 1]], [[79, 1], [76, 1], [72, 1]], [[74, 3]],
			[[72, 1], [74, 1], [76, 1]], [[77, 2], [74, 1]], [[71, 2], [68, 1]], [[74, 1], [71, 1], [68, 1]],
		],
		"birds": false,
	},
	{
		# Islas entre las nubes: re mayor, ligero y aéreo, con saltos amplios.
		"beat": 0.56,
		"chords": [
			[50, 66, 69], [47, 66, 71], [43, 67, 71], [45, 64, 69],
			[50, 66, 69], [42, 66, 69], [43, 67, 71], [45, 64, 67],
		],
		"melody": [
			[[78, 1], [81, 1], [86, 1]], [[83, 3]], [[79, 1], [83, 1], [86, 1]], [[81, 2], [76, 1]],
			[[78, 1], [81, 1], [85, 1]], [[86, 2], [78, 1]], [[79, 2], [83, 1]], [[81, 3]],
		],
		"birds": true,
	},
	{
		# Cumbre nevada: do mayor tranquilo, notas agudas como campanillas.
		"beat": 0.74,
		"chords": [
			[48, 64, 67], [41, 65, 69], [45, 64, 69], [43, 62, 67],
			[48, 64, 67], [41, 65, 69], [43, 62, 65], [43, 62, 67],
		],
		"melody": [
			[[84, 2], [79, 1]], [[81, 2], [77, 1]], [[76, 1], [79, 1], [84, 1]], [[83, 3]],
			[[84, 2], [88, 1]], [[86, 2], [81, 1]], [[79, 1], [77, 1], [74, 1]], [[79, 3]],
		],
		"birds": false,
	},
]

var _player: AudioStreamPlayer
var _thread: Thread
var _cache := {}
var _current := -1
var _wanted := 0
var _bird_timer := 5.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_player = AudioStreamPlayer.new()
	_player.volume_db = -9.0
	add_child(_player)
	play_track(0)


## Cambia a la música de un mundo (la compone en segundo plano si hace falta).
func play_track(i: int) -> void:
	_wanted = i
	if DisplayServer.get_name() == "headless" or i == _current:
		return
	if _cache.has(i):
		_start(i, _cache[i])
		return
	if _thread and _thread.is_started():
		if _thread.is_alive():
			return  # Al terminar la pista actual se comprueba la pedida.
		_thread.wait_to_finish()
	_thread = Thread.new()
	_thread.start(_compose.bind(i))


func _process(delta: float) -> void:
	if _current >= 0 and not TRACKS[_current]["birds"]:
		return
	_bird_timer -= delta
	if _bird_timer <= 0.0:
		_bird_timer = randf_range(5.0, 11.0)
		Sfx.play("bird", -16.0, randf_range(0.85, 1.25))


func _exit_tree() -> void:
	if _thread and _thread.is_started():
		_thread.wait_to_finish()


func _compose(track: int) -> void:
	var tr_data: Dictionary = TRACKS[track]
	var beat: float = tr_data["beat"]
	var chords: Array = tr_data["chords"]
	var melody: Array = tr_data["melody"]
	var bars := chords.size()
	var n := int(bars * 3 * beat * RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	for b in bars:
		var t0 := b * 3 * beat
		var ch: Array = chords[b]
		# Colchón de acorde suave durante todo el compás.
		for m in [ch[1] - 12, ch[2] - 12]:
			_pad(buf, t0, 3 * beat, _freq(m), 0.05)
		# Um-pa-pa: bajo en el primer pulso, acorde en el segundo y tercero.
		_piano(buf, t0, _freq(ch[0]), 0.28, 1.4)
		for k in [1, 2]:
			_piano(buf, t0 + k * beat, _freq(ch[1]), 0.12, 0.8)
			_piano(buf, t0 + k * beat, _freq(ch[2]), 0.12, 0.8)
		var t := t0
		for note in melody[b]:
			_piano(buf, t, _freq(note[0]), 0.3, note[1] * beat + 0.6)
			t += note[1] * beat
	# Suaviza el final para que el bucle no dé un salto.
	for i in 200:
		buf[n - 1 - i] *= float(i) / 200.0
	# Normaliza: si los acordes suman demasiado, se baja todo en vez de recortar.
	var top := 0.0
	for v in buf:
		top = maxf(top, absf(v))
	if top > 0.85:
		for i in n:
			buf[i] *= 0.85 / top
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		data.encode_s16(i * 2, int(clampf(buf[i], -1.0, 1.0) * 24000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.data = data
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = 0
	w.loop_end = n
	_done.call_deferred(track, w)


func _done(track: int, w: AudioStreamWAV) -> void:
	_cache[track] = w
	if _thread:
		_thread.wait_to_finish()
		_thread = null
	if track == _wanted:
		_start(track, w)
	else:
		play_track(_wanted)


func _start(track: int, w: AudioStreamWAV) -> void:
	_current = track
	_player.stream = w
	_player.play()


func _freq(midi: int) -> float:
	return 440.0 * pow(2.0, (midi - 69) / 12.0)


func _piano(buf: PackedFloat32Array, t0: float, f: float, amp: float, dur: float) -> void:
	var start := int(t0 * RATE)
	var count := mini(int(dur * RATE), buf.size() - start)
	var w := TAU * f / RATE
	for i in count:
		var t := float(i) / RATE
		var env := minf(1.0, t * 250.0) * exp(-t * 3.2)
		var x := w * i
		buf[start + i] += (sin(x) + 0.35 * sin(2.0 * x) + 0.12 * sin(3.0 * x)) * env * amp


func _pad(buf: PackedFloat32Array, t0: float, dur: float, f: float, amp: float) -> void:
	var start := int(t0 * RATE)
	var count := mini(int(dur * RATE), buf.size() - start)
	var w := TAU * f / RATE
	for i in count:
		var k := float(i) / count
		buf[start + i] += sin(w * i) * sin(PI * k) * amp
