extends RefCounted
# 2026-10-05: physical latch/ratchet transients, motor bed and rising power layers.
# Separate from generic pitch sweeps so UI machinery has multiple audible events.
const RATE: int = 44100
static func synthesize(kind: String,duration: float) -> AudioStreamWAV:
	var count: int = int(ceil(duration*RATE))
	var bytes := PackedByteArray()
	bytes.resize(count*2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1052026
	var low: float = 0.0
	var phase: float = 0.0
	var power: bool = kind=="workshop_power"
	var drive: bool = kind=="workshop_drive"
	var strikes: Array = [0.0,.026,.057,.094,.139,.190,.250,.310] if drive else [0.0,.028,.061]
	for i in range(count):
		var t: float = float(i)/RATE
		var progress: float = t/duration
		var noise: float = rng.randf_range(-1,1)
		low += .16*(noise-low)
		var value: float = 0.0
		if power:
			# An accelerating harmonic charge with air and a brief bright ignition.
			phase += (150+470*progress*progress)/RATE
			var envelope: float = sin(PI*progress)*minf(1,t/.045)
			value = (.050*sin(TAU*phase)+.027*sin(TAU*phase*2)+.014*sin(TAU*phase*3.01))*envelope
			value += (noise-low)*.019*envelope*(.5+.5*sin(TAU*37*t))
			var age: float = t-.155
			if age>=0:
				value += (.022*sin(TAU*1175*age)+.013*sin(TAU*1760*age))*exp(-age*37)*minf(1,age/.003)
		else:
			# Each tooth/bolt has its own short impact and inharmonic metal ring.
			for n in range(strikes.size()):
				var age: float = t-float(strikes[n])
				if age<0 or age>.10: continue
				var frequency: float = (580.0 if drive else 410.0)+float(n%3)*137
				var ring: float = sin(TAU*frequency*age)+.48*sin(TAU*frequency*2.71*age)+.24*sin(TAU*frequency*4.13*age)
				var hit: float = (.055 if drive else .075)*exp(-age*72)*minf(1,age/.001)
				value += ring*hit+noise*(.075 if drive else .11)*exp(-age*370)*minf(1,age/.0005)
				value += .040*sin(TAU*115*age)*exp(-age*90)
			if drive:
				phase += (92+55*sin(PI*progress))/RATE
				value += (.027*sin(TAU*phase)+.011*sin(TAU*phase*3)+.032*low)*sin(PI*progress)*(.7+.3*sin(TAU*43*t))
		# Both endpoints zero; fixed conservative gain leaves room for overlapping cues.
		value *= minf(1,t/.001)*minf(1,float(count-1-i)/(RATE*.012))
		bytes.encode_s16(i*2,int(clampf(value,-.8,.8)*32767))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.data = bytes
	return stream
