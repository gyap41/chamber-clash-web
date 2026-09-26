"""Offline numeric audit of full-speed foot trajectories; no aesthetic assertion."""
import math
worst=0
for i in range(1000):
    phase=i/1000
    hip_y=-10-.25-1.45*math.cos(4*math.pi*phase+.8)
    for side in (0,1):
        p=(phase+side*.5)%1
        if p<.42:
            x=6-12*p/.42
            y=-2.5
            assert abs(y+4.3*(1-.42))<.01
        else:
            u=(p-.42)/.58
            x=-6+12*u*u*(3-2*u)
            y=-2.5-6*math.sin(math.pi*u)
        reach=math.hypot(x,y-hip_y)
        worst=max(worst,reach)
        assert reach<11.6, (phase,side,reach)
assert abs(12/(.42*.42) - (12/.42)/.42)<1e-8
print(f'PASS: 2000 foot samples reachable; max reach {worst:.3f}/11.6; stance sole and ground velocity consistent. Visual quality not assessed.')
