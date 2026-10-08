extends Node
## Efectos de sonido sintetizados al arrancar (no hacen falta archivos).
## Todos son tonales y suaves (sin ruido blanco, que suena a roce de micrófono)
## y se normalizan para que nunca se saturen.

const RATE := 22050

var _sounds := {}
var _players: Array[AudioStreamPlayer] = []
var _idx := 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.seed = 7
	# Golpe: un "toc" de madera redondo y grave (sin chasquido ni ruido).
	_sounds["hit"] = _soft([262.0, 523.3, 785.0], [1.0, 0.25, 0.06], 0.3, 18.0, 0.008, 0.5)
	_sounds["wall"] = _soft([330.0, 660.0], [1.0, 0.2], 0.14, 38.0, 0.004, 0.45)
	_sounds["tick"] = _soft([660.0, 1320.0], [1.0, 0.2], 0.12, 35.0, 0.004)
	_sounds["cup"] = _cup()
	_sounds["splash"] = _splash()
	_sounds["fanfare"] = _arpeggio([523.3, 659.3, 784.0, 1046.5], 0.11)
	_sounds["big_fanfare"] = _arpeggio([523.3, 659.3, 784.0, 1046.5, 784.0, 1046.5, 1318.5], 0.1)
	_sounds["sad"] = _arpeggio([392.0, 370.0, 349.2, 311.1], 0.22)
	_sounds["boing"] = _boing(180.0, 620.0, 0.4)
	_sounds["jump"] = _boing(300.0, 900.0, 0.22)
	_sounds["pipe"] = _pipe()
	_sounds["coin"] = _arpeggio([987.8, 1318.5], 0.07)
	# En lugar de aplausos (ruido), una lluvia de campanillas suaves.
	_sounds["applause"] = _sparkles(1.8, 16)
	_sounds["small_applause"] = _sparkles(0.9, 7)
	_sounds["ooh"] = _ooh()
	_sounds["bird"] = _bird()
	_sounds["whoosh"] = _whoosh()
	# Aparición del personaje: un campanilleo suave.
	_sounds["poof"] = _chime([784.0, 1174.7], 0.07)
	_sounds["dance"] = _arpeggio([523.3, 659.3, 784.0, 659.3, 587.3, 784.0, 987.8, 1046.5], 0.12)
	for i in 8:
		var p := AudioStreamPlayer.new()
		p.volume_db = -3.0
		add_child(p)
		_players.append(p)
	# Limitador en la salida: aunque suenen muchas cosas a la vez, no se satura.
	var master := AudioServer.get_bus_index("Master")
	if AudioServer.get_bus_effect_count(master) == 0:
		var lim := AudioEffectHardLimiter.new()
		lim.ceiling_db = -1.5
		lim.pre_gain_db = -2.0
		AudioServer.add_bus_effect(master, lim)


func play(sound: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	if not _sounds.has(sound):
		return
	var p := _players[_idx]
	_idx = (_idx + 1) % _players.size()
	p.stream = _sounds[sound]
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.play()


# --- Síntesis ----------------------------------------------------------------

func _buf(dur: float) -> PackedFloat32Array:
	var s := PackedFloat32Array()
	s.resize(int(dur * RATE))
	return s


## Nota suave: parciales armónicos con subida gradual (sin chasquido al empezar).
func _soft(freqs: Array, amps: Array, dur: float, decay: float, attack: float,
		peak: float = 0.55) -> AudioStreamWAV:
	var samples := _buf(dur)
	for i in samples.size():
		var t := float(i) / RATE
		# Subida suave, caída exponencial y un final a cero (sin clic).
		var env := minf(1.0, t / attack) * exp(-t * decay) * minf(1.0, (dur - t) / 0.02)
		var s := 0.0
		for k in freqs.size():
			s += sin(TAU * float(freqs[k]) * t) * float(amps[k])
		samples[i] = s * env
	return _wav(samples, peak)


## Dos notas de campanilla, una tras otra, con cola larga y suave.
func _chime(notes: Array, step: float) -> AudioStreamWAV:
	var samples := _buf(step * notes.size() + 0.6)
	for k in notes.size():
		var f: float = notes[k]
		var start := int(k * step * RATE)
		for i in range(start, samples.size()):
			var t := float(i - start) / RATE
			var env := minf(1.0, t / 0.015) * exp(-t * 6.0)
			samples[i] += (sin(TAU * f * t) + 0.25 * sin(TAU * f * 3.0 * t)) * env * 0.22
	return _wav(samples)


func _cup() -> AudioStreamWAV:
	var samples := _buf(0.35)
	for i in samples.size():
		var t := float(i) / RATE
		var s := sin(TAU * 620.0 * t) * exp(-t * 25.0)
		if t > 0.1:
			var t2 := t - 0.1
			s += 0.6 * sin(TAU * 430.0 * t2) * exp(-t2 * 22.0)
		samples[i] = s * 0.8
	return _wav(samples)


## Caída al agua: tres "bloops" de burbuja que suben de tono.
func _splash() -> AudioStreamWAV:
	var samples := _buf(0.6)
	for k in 3:
		var start := int(k * 0.12 * RATE)
		var f0 := 220.0 + k * 90.0
		var ph := 0.0
		for i in range(start, samples.size()):
			var t := float(i - start) / RATE
			ph += TAU * f0 * (1.0 + 2.5 * t) / RATE
			samples[i] += sin(ph) * minf(1.0, t / 0.01) * exp(-t * 14.0) * (1.0 - k * 0.25)
	return _wav(samples, 0.5)


func _arpeggio(notes: Array, step: float) -> AudioStreamWAV:
	var samples := _buf(step * notes.size() + 0.35)
	for k in notes.size():
		var f: float = notes[k]
		var start := int(k * step * RATE)
		for i in range(start, samples.size()):
			var t := float(i - start) / RATE
			var s := (sin(TAU * f * t) + 0.3 * sin(TAU * f * 2.0 * t)) * exp(-t * 7.0) 				* minf(1.0, t / 0.006)
			samples[i] += s * 0.35
	return _wav(samples, 0.5)


func _boing(f0: float, f1: float, dur: float) -> AudioStreamWAV:
	var samples := _buf(dur)
	var ph := 0.0
	for i in samples.size():
		var t := float(i) / RATE
		var f := lerpf(f0, f1, sqrt(t / dur)) * (1.0 + 0.08 * sin(TAU * 18.0 * t))
		ph += TAU * f / RATE
		samples[i] = (sin(ph) + 0.25 * sin(ph * 2.0)) * exp(-t * 6.0) * minf(1.0, t * 300.0) * 0.7
	return _wav(samples)


func _pipe() -> AudioStreamWAV:
	var samples := _buf(0.5)
	var ph := 0.0
	for i in samples.size():
		var t := float(i) / RATE
		ph += TAU * lerpf(900.0, 140.0, t / 0.5) / RATE
		samples[i] = (sin(ph) + 0.2 * sin(ph * 2.0)) * exp(-t * 3.0) * minf(1.0, t / 0.01)
	return _wav(samples, 0.45)


## Campanillas al azar de una escala pentatónica (alegre y tranquila).
func _sparkles(dur: float, count: int) -> AudioStreamWAV:
	var scale := [1046.5, 1174.7, 1318.5, 1568.0, 1760.0, 2093.0]
	var samples := _buf(dur + 0.6)
	for k in count:
		var f: float = scale[_rng.randi() % scale.size()]
		var start := int(_rng.randf_range(0.0, dur) * RATE)
		var amp := _rng.randf_range(0.5, 1.0)
		for i in range(start, mini(start + int(0.6 * RATE), samples.size())):
			var t := float(i - start) / RATE
			samples[i] += (sin(TAU * f * t) + 0.2 * sin(TAU * f * 2.0 * t)) * amp 				* minf(1.0, t / 0.008) * exp(-t * 7.0)
	return _wav(samples, 0.35)


func _ooh() -> AudioStreamWAV:
	# Un "oooh" de público: varias voces graves que bajan de tono.
	var samples := _buf(1.1)
	var voices := [170.0, 205.0, 240.0, 262.0, 310.0]
	for f in voices:
		var ph := 0.0
		var det := _rng.randf_range(0.97, 1.03)
		for i in samples.size():
			var t := float(i) / RATE
			var fr: float = f * det * (1.0 - 0.18 * t) * (1.0 + 0.012 * sin(TAU * 5.5 * t))
			ph += TAU * fr / RATE
			var env := minf(1.0, t * 5.0) * exp(-t * 2.2)
			samples[i] += (sin(ph) + 0.5 * sin(ph * 2.0) + 0.25 * sin(ph * 3.0)) * env * 0.09
	return _wav(samples)


func _bird() -> AudioStreamWAV:
	var samples := _buf(0.42)
	var ph := 0.0
	for i in samples.size():
		var t := float(i) / RATE
		var k := fmod(t, 0.14) / 0.14
		ph += TAU * lerpf(2600.0, 3900.0, k) / RATE
		samples[i] = sin(ph) * sin(PI * k) * 0.35
	return _wav(samples)


## "Fiuu": un deslizamiento de tono suave hacia arriba (sin ruido).
func _whoosh() -> AudioStreamWAV:
	var samples := _buf(0.4)
	var ph := 0.0
	for i in samples.size():
		var t := float(i) / RATE
		ph += TAU * lerpf(350.0, 900.0, t / 0.4) / RATE
		samples[i] = (sin(ph) + 0.15 * sin(ph * 2.0)) * sin(PI * t / 0.4)
	return _wav(samples, 0.3)


## Convierte a WAV. Con "peak" se normaliza a ese pico, así ningún sonido
## se recorta (el recorte es lo que suena distorsionado).
func _wav(samples: PackedFloat32Array, peak: float = -1.0) -> AudioStreamWAV:
	var top := 0.0
	for v in samples:
		top = maxf(top, absf(v))
	var limit := peak if peak > 0.0 else 0.8
	if top > limit or peak > 0.0:
		var g := limit / maxf(top, 0.0001)
		for i in samples.size():
			samples[i] *= g
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 26000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w
