W, H = 1500, 1040
out = []
add = out.append
FONT = "DejaVu Sans, Arial, sans-serif"
C = dict(pos="#d62728", gnd="#222222", sda="#1f77b4", scl="#2ca02c", ow="#e69500",
         tx="#9467bd", rx="#8c564b", adc="#17a2b8")

def text(x, y, s, size=14, anchor="start", weight="normal", color="#222", style="normal"):
    add(f'<text x="{x}" y="{y}" font-family="{FONT}" font-size="{size}" text-anchor="{anchor}" '
        f'font-weight="{weight}" font-style="{style}" fill="{color}">{s}</text>')

def box(x, y, w, h, title, sub="", fill="#eef6f5", stroke="#0f9b8e", ty=26):
    add(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="10" fill="{fill}" stroke="{stroke}" stroke-width="2.5"/>')
    text(x + w / 2, y + ty, title, 17, "middle", "bold")
    if sub:
        text(x + w / 2, y + ty + 19, sub, 12, "middle", color="#555")

def pin(x, y, label, side):
    add(f'<circle cx="{x}" cy="{y}" r="4.5" fill="#fff" stroke="#333" stroke-width="2"/>')
    if side == "left":   text(x + 10, y + 5, label, 13)
    elif side == "right": text(x - 10, y + 5, label, 13, "end")
    elif side == "top":   text(x, y + 22, label, 13, "middle")
    elif side == "bottom": text(x, y - 12, label, 13, "middle")

def wire(pts, color, width=3):
    d = " ".join(f"{x},{y}" for x, y in pts)
    add(f'<polyline points="{d}" fill="none" stroke="{color}" stroke-width="{width}" stroke-linejoin="round" stroke-linecap="round"/>')

def dot(x, y, color):
    add(f'<circle cx="{x}" cy="{y}" r="5.5" fill="{color}"/>')

def gnd(x, y):  # ground symbol hanging below (x,y)
    wire([(x, y), (x, y + 12)], C["gnd"])
    for i, w in enumerate((22, 14, 6)):
        yy = y + 12 + i * 6
        add(f'<line x1="{x-w/2}" y1="{yy}" x2="{x+w/2}" y2="{yy}" stroke="{C["gnd"]}" stroke-width="2.5"/>')

def v33(x, y, up=True):  # 3.3 V net flag at (x,y)
    if up:
        wire([(x, y), (x, y - 14)], C["pos"])
        add(f'<polygon points="{x-22},{y-14} {x+22},{y-14} {x+22},{y-34} {x},{y-44} {x-22},{y-34}" fill="#fde8e8" stroke="{C["pos"]}" stroke-width="2"/>')
        text(x, y - 21, "3.3V", 11, "middle", "bold", C["pos"])

def res_h(x1, x2, y, label, color):
    mid = (x1 + x2) / 2
    wire([(x1, y), (mid - 30, y)], color); wire([(mid + 30, y), (x2, y)], color)
    add(f'<rect x="{mid-30}" y="{y-9}" width="60" height="18" fill="#fff" stroke="#333" stroke-width="2"/>')
    text(mid, y - 15, label, 12, "middle")

def res_v(x, y1, y2, label, color):
    mid = (y1 + y2) / 2
    wire([(x, y1), (x, mid - 28)], color); wire([(x, mid + 28), (x, y2)], color)
    add(f'<rect x="{x-9}" y="{mid-28}" width="18" height="56" fill="#fff" stroke="#333" stroke-width="2"/>')
    text(x + 16, mid + 5, label, 12)

# Title
text(W / 2, 40, "HavaPaw Smart Collar: Wiring Diagram", 24, "middle", "bold")
text(W / 2, 64, "ESP32 DevKit V1 · power via TPS63020 3.3 V buck-boost · sensors on the 3.3 V rail", 13, "middle", color="#555")

# ---------------- Power column ----------------
box(40, 95, 240, 80, "LiPo battery", "3.7 V, 1 cell", "#fff7e6", "#e69500")
pin(110, 175, "+", "bottom"); pin(210, 175, "−", "bottom")
box(40, 230, 240, 150, "TP4056", "USB-C charger + protection", "#eef2fb", "#3b6fd1", ty=70)
text(160, 346, "⚡ USB-C in (charging)", 12, "middle", color="#3b6fd1")
pin(110, 230, "B+", "top"); pin(210, 230, "B−", "top")
pin(110, 380, "OUT+", "bottom"); pin(210, 380, "OUT−", "bottom")
wire([(110, 175), (110, 230)], C["pos"]); wire([(210, 175), (210, 230)], C["gnd"])

# switch
wire([(110, 380), (110, 470)], C["pos"])
dot(110, 420, C["pos"])
add(f'<circle cx="110" cy="470" r="4" fill="{C["pos"]}"/><circle cx="110" cy="520" r="4" fill="{C["pos"]}"/>')
add(f'<line x1="110" y1="470" x2="135" y2="512" stroke="{C["pos"]}" stroke-width="3"/>')
text(98, 492, "SS12D00", 12, "end"); text(98, 508, "switch", 12, "end")
wire([(110, 520), (110, 580)], C["pos"])

box(40, 580, 240, 140, "TPS63020", "buck-boost, set to 3.3 V", "#eef6f5", "#0f9b8e", ty=66)
pin(110, 580, "VIN", "top"); pin(210, 580, "GND", "top")
pin(280, 650, "OUT", "right")
wire([(210, 380), (210, 580)], C["gnd"])
dot(210, 760 - 260, C["gnd"]); wire([(210, 500), (250, 500)], C["gnd"]); gnd(250, 500)

# battery divider
res_h(110, 400, 420, "R1 100 kΩ", C["pos"])
dot(400, 420, C["adc"])
wire([(400, 420), (520, 420)], C["adc"])
res_v(400, 420, 540, "R2 100 kΩ", C["adc"])
gnd(400, 540)

# 3.3 V from TPS to ESP32 + capacitor
wire([(280, 650), (520, 650)], C["pos"], 4)
dot(420, 650, C["pos"])
wire([(420, 650), (420, 678)], C["pos"])
add(f'<line x1="402" y1="680" x2="438" y2="680" stroke="#333" stroke-width="3"/>')
add(f'<path d="M402,694 Q420,684 438,694" fill="none" stroke="#333" stroke-width="3"/>')
text(446, 678, "+", 13, weight="bold"); text(446, 700, "C1 1000 µF 10 V", 12)
wire([(420, 690), (420, 720)], C["gnd"]); gnd(420, 720)

# ---------------- ESP32 ----------------
ex, ey, ew, eh = 520, 95, 300, 775
box(ex, ey, ew, eh, "ESP32 DevKit V1", "ESP32-WROOM-32 · Wi-Fi + BLE", "#f3effa", "#7a4fc9")
pin(ex, 420, "GPIO34 (ADC)", "left")
pin(ex, 650, "3V3", "left")
pin(ex, 710, "GND", "left")
pin(ex, 810, "VIN / 5V", "left")
wire([(ex, 710), (470, 710), (470, 740)], C["gnd"]); gnd(470, 740)
add(f'<line x1="{ex-34}" y1="798" x2="{ex-10}" y2="822" stroke="#c00" stroke-width="3"/>')
add(f'<line x1="{ex-34}" y1="822" x2="{ex-10}" y2="798" stroke="#c00" stroke-width="3"/>')
text(ex - 40, 848, "not connected", 12, "end", color="#c00", style="italic")
text(ex + ew / 2, ey + eh - 18, "micro-USB: firmware upload only", 12, "middle", color="#555", style="italic")

R = ex + ew
pin(R, 175, "GPIO21 SDA", "right")
pin(R, 225, "GPIO22 SCL", "right")
pin(R, 580, "GPIO4", "right")
pin(R, 700, "GPIO16 RX2", "right")
pin(R, 750, "GPIO17 TX2", "right")

# ---------------- Sensors ----------------
sx, sw = 1080, 260
# MAX30102
box(sx, 95, sw, 170, "MAX30102", "heart rate + SpO2 (I²C 0x57)", "#fdeef4", "#c2185b")
pin(sx, 175, "SDA", "left"); pin(sx, 225, "SCL", "left")
pin(sx + sw, 170, "VIN", "right"); pin(sx + sw, 210, "GND", "right"); pin(sx + sw, 245, "INT (nc)", "right")
# MPU6050
box(sx, 300, sw, 170, "MPU6050", "accelerometer (I²C 0x68)", "#eaf4fb", "#1f77b4")
pin(sx, 380, "SDA", "left"); pin(sx, 430, "SCL", "left")
pin(sx + sw, 360, "VCC", "right"); pin(sx + sw, 410, "GND", "right")
# DS18B20
box(sx, 500, sw, 130, "DS18B20", "skin temperature (1-Wire)", "#fff7e6", "#e69500")
pin(sx, 580, "DATA", "left")
pin(sx + sw, 575, "VDD", "right"); pin(sx + sw, 610, "GND", "right")
# GPS
box(sx, 655, sw, 170, "NEO-6M GPS", "GY-GPS6MV2 · 9600 baud", "#eef6ec", "#2ca02c")
pin(sx, 700, "TX", "left"); pin(sx, 750, "RX", "left")
pin(sx + sw, 700, "VCC", "right"); pin(sx + sw, 750, "GND", "right")
text(sx + sw / 2, 805, "patch antenna facing up", 12, "middle", color="#555", style="italic")

# I2C bus
wire([(R, 175), (sx, 175)], C["sda"])
dot(960, 175, C["sda"]); wire([(960, 175), (960, 380), (sx, 380)], C["sda"])
wire([(R, 225), (sx, 225)], C["scl"])
dot(1010, 225, C["scl"]); wire([(1010, 225), (1010, 430), (sx, 430)], C["scl"])
# 1-Wire + pull-up
wire([(R, 580), (sx, 580)], C["ow"])
dot(940, 580, C["ow"])
res_v(940, 505, 580, "4.7 kΩ", C["ow"])
v33(940, 505)
# UART
wire([(R, 700), (sx, 700)], C["rx"])
wire([(R, 750), (sx, 750)], C["tx"])
add(f'<polygon points="{(R+sx)/2-6},694 {(R+sx)/2+6},700 {(R+sx)/2-6},706" fill="{C["rx"]}" transform="rotate(180 {(R+sx)/2} 700)"/>')
add(f'<polygon points="{(R+sx)/2-6},744 {(R+sx)/2+6},750 {(R+sx)/2-6},756" fill="{C["tx"]}"/>')

# sensor power: 3.3 V flags and grounds on the right
for y_v, y_g in ((170, 210), (360, 410), (575, 610), (700, 750)):
    wire([(sx + sw, y_v), (sx + sw + 50, y_v)], C["pos"]); v33(sx + sw + 50, y_v)
    wire([(sx + sw, y_g), (sx + sw + 95, y_g)], C["gnd"]); gnd(sx + sw + 95, y_g)

# 3.3 V flag at ESP32 3V3 net
wire([(470, 650), (470, 610)], C["pos"]); dot(470, 650, C["pos"]); v33(470, 610)

# ---------------- Legend ----------------
ly = 930
add(f'<rect x="40" y="{ly-30}" width="{W-80}" height="110" rx="10" fill="#fafafa" stroke="#ccc"/>')
items = [("pos", "Battery / 3.3 V"), ("gnd", "Ground"), ("sda", "I²C SDA"), ("scl", "I²C SCL"),
         ("ow", "1-Wire data"), ("rx", "GPS TX → ESP32"), ("tx", "ESP32 → GPS RX"), ("adc", "Battery level (ADC)")]
for i, (k, label) in enumerate(items):
    x = 70 + i * 172
    wire([(x, ly), (x + 34, ly)], C[k], 4); text(x + 42, ly + 5, label, 13)
text(70, ly + 40, "All “3.3V” flags are the same net: TPS63020 OUT → ESP32 3V3. All ground symbols share the GND rail (TP4056 OUT−).", 13)
text(70, ly + 62, "The battery must never connect to ESP32 VIN/5V. Switch the collar off before plugging in the ESP32's micro-USB.", 13, color="#c00")

svg = f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}"><rect width="100%" height="100%" fill="#ffffff"/>' + "".join(out) + "</svg>"
open("wiring.svg", "w").write(svg)
