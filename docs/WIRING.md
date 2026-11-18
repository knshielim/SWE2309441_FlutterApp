# HavaPaw Collar: Wiring

Use this list to draw the wiring diagram. The pin numbers match the firmware
(`HavaPaw_Arduino/havapaw_collar/havapaw_collar.ino` and `havapaw_sensors.h`).

## Parts

| # | Part | Purpose |
|---|---|---|
| 1 | ESP32 DevKit V1 (ESP32-WROOM-32, 30-pin) | Microcontroller, Wi-Fi, Bluetooth |
| 2 | 3.7 V LiPo battery (1 cell) | Power |
| 3 | TP4056 USB-C charger module (with protection: B+/B−, OUT+/OUT−) | Charges the battery, battery protection |
| 4 | SS12D00 slide switch | On/off |
| 5 | TPS63020 buck-boost module, set to 3.3 V | Steady 3.3 V from the battery |
| 6 | 1000 µF 10 V electrolytic capacitor | Covers current spikes when the radio starts |
| 7 | 2 × 100 kΩ resistors | Battery voltage divider |
| 8 | MAX30102 (GY-MAX30102) | Heart rate and SpO2 |
| 9 | MPU6050 (GY-521) | Accelerometer (steps, activity) |
| 10 | DS18B20 + 4.7 kΩ pull-up resistor | Skin temperature |
| 11 | NEO-6M GPS (GY-GPS6MV2) + patch antenna | Location |

## Power

| From | To | Wire |
|---|---|---|
| Battery + (red) | TP4056 **B+** | red |
| Battery − (black) | TP4056 **B−** | black |
| TP4056 **OUT+** | Switch **middle pin** | red |
| Switch **outer pin** (ON side) | TPS63020 **VIN** | red |
| TP4056 **OUT−** | **GND rail** | black |
| TPS63020 **GND** | **GND rail** | black |
| TPS63020 **OUT** (3.3 V) | **3.3 V rail** | red |
| **3.3 V rail** | ESP32 **3V3** | red |
| **GND rail** | ESP32 **GND** | black |
| Capacitor **+** (long leg) | ESP32 **3V3** | — |
| Capacitor **−** (striped leg) | ESP32 **GND** | — |
| ESP32 **VIN / 5V** | **nothing** | must stay unconnected |

The TP4056's own USB-C port is used for charging. The ESP32's micro-USB is only for uploading
firmware (switch the collar off first).

## Battery level (voltage divider)

| From | To |
|---|---|
| TP4056 **OUT+** | 100 kΩ (R1) → ESP32 **GPIO34** |
| ESP32 **GPIO34** | 100 kΩ (R2) → **GND rail** |

GPIO34 reads half the battery voltage (`BATTERY_DIVIDER_RATIO = 2.0`).

## Sensors

All sensors run on the **3.3 V rail** and share the **GND rail**.

### MAX30102 (heart rate, SpO2), I²C
| MAX30102 pin | Connects to |
|---|---|
| VIN | 3.3 V rail |
| GND | GND rail |
| SCL | ESP32 **GPIO22** |
| SDA | ESP32 **GPIO21** |
| INT | not connected |

### MPU6050 (accelerometer), I²C, same bus as the MAX30102
| MPU6050 pin | Connects to |
|---|---|
| VCC | 3.3 V rail |
| GND | GND rail |
| SCL | ESP32 **GPIO22** |
| SDA | ESP32 **GPIO21** |
| XDA, XCL, AD0, INT | not connected (AD0 low → address 0x68) |

### DS18B20 (temperature), 1-Wire
| DS18B20 pin | Connects to |
|---|---|
| VDD (red) | 3.3 V rail |
| GND (black) | GND rail |
| DATA (yellow) | ESP32 **GPIO4** |
| 4.7 kΩ resistor | between **GPIO4** and the **3.3 V rail** (pull-up) |

### NEO-6M GPS, UART2
| GPS pin | Connects to |
|---|---|
| VCC | 3.3 V rail |
| GND | GND rail |
| TX | ESP32 **GPIO16** (RX2) |
| RX | ESP32 **GPIO17** (TX2) |
| Antenna | u.FL patch antenna, facing up |

## ESP32 pins used

| ESP32 pin | Used for |
|---|---|
| 3V3 | power in (3.3 V rail) |
| GND | ground |
| GPIO21 | I²C SDA (MAX30102, MPU6050) |
| GPIO22 | I²C SCL (MAX30102, MPU6050) |
| GPIO4 | DS18B20 data |
| GPIO16 | GPS TX → ESP32 RX2 |
| GPIO17 | ESP32 TX2 → GPS RX |
| GPIO34 | battery voltage (input only) |
| VIN / 5V | not connected |

## Block diagram (for the report)

```
 USB-C charger ─▶ TP4056 ◀─▶ LiPo 3.7 V
                    │ OUT+                 OUT+ ─[100k]─┬─[100k]─ GND
                    ▼                                   └──▶ GPIO34 (battery %)
                 [switch]
                    ▼
               TPS63020 (3.3 V)
                    │
        ┌───────────┴────── 3.3 V rail ─────────┬──────────┬──────────┐
        ▼                                       ▼          ▼          ▼
   ESP32 (3V3) ◀── 1000 µF               MAX30102     MPU6050    NEO-6M GPS
   GPIO21 SDA ───────────────────────────── SDA ─────── SDA
   GPIO22 SCL ───────────────────────────── SCL ─────── SCL
   GPIO16 RX2 ◀────────────────────────────────────────────────── TX
   GPIO17 TX2 ───────────────────────────────────────────────────▶ RX
   GPIO4 ◀──── DS18B20 DATA (4.7k pull-up to 3.3 V)
```
