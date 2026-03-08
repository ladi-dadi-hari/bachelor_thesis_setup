import time
import threading

from pymodbus.server import StartTcpServer
from pymodbus.datastore import (
    ModbusSequentialDataBlock,
    ModbusSlaveContext,
    ModbusServerContext,
)

store = ModbusSlaveContext(
    di=ModbusSequentialDataBlock(0, [0] * 100),
    co=ModbusSequentialDataBlock(0, [0] * 100),
    ir=ModbusSequentialDataBlock(0, [0] * 200),
    hr=ModbusSequentialDataBlock(0, [0] * 200),
    zero_mode=True
)
context = ModbusServerContext(slaves={1: store}, single=False)

IR_MAP = {
    "pressure_in": 1,
    "pressure_out": 2,
    "flow_in": 3,
    "flow_out": 4,
    "temp_in": 5,
    "temp_out": 6,
}

COIL_MAP = {
    "pump1_start": 0,
    "pump2_start": 1,
}

HR_MAP = {
    "pump1_speed": 10,
    "pump2_speed": 20,
}

state_lock = threading.Lock()

BASE = {
    "pressure_in": 2758,
    "pressure_out": 2658,
    "flow": 29,
    "temp_in": 15,
    "temp_out": 15,
}

FLOW_GAIN = 0.4
TEMP_GAIN = 0.03

BOUNDS = {
    "pressure_in": (0, 10000),
    "pressure_out": (0, 10000),
    "flow_in": (0, 500),
    "flow_out": (0, 500),
    "temp_in": (0, 200),
    "temp_out": (0, 200),
}


def clamp_int(x, lo, hi):
    if x < lo:
        return lo
    if x > hi:
        return hi
    return x


pump_status = {
    "pump1_on": False,
    "pump2_on": False,
    "pump1_speed": 0,
    "pump2_speed": 0,
    "pump1_speed_cmd": 0,
    "pump2_speed_cmd": 0,
}


def read_commands():
    # Read pump states and speed setpoints from Modbus
    while True:
        try:
            coil0 = context[1].getValues(1, COIL_MAP["pump1_start"], count=1)[0]
            coil1 = context[1].getValues(1, COIL_MAP["pump2_start"], count=1)[0]
            speed1 = context[1].getValues(3, HR_MAP["pump1_speed"], count=1)[0]
            speed2 = context[1].getValues(3, HR_MAP["pump2_speed"], count=1)[0]

            with state_lock:
                pump_status["pump1_on"] = bool(coil0)
                pump_status["pump2_on"] = bool(coil1)
                pump_status["pump1_speed_cmd"] = int(speed1)
                pump_status["pump2_speed_cmd"] = int(speed2)

                pump_status["pump1_speed"] = int(speed1) if pump_status["pump1_on"] else 0
                pump_status["pump2_speed"] = int(speed2) if pump_status["pump2_on"] else 0

        except Exception as e:
            print(f"Error reading Modbus: {e}")

        time.sleep(0.1)


def compute_and_write_sensors():
    # Calculate sensor values from the current command state
    while True:
        with state_lock:
            p1_on = pump_status["pump1_on"]
            p2_on = pump_status["pump2_on"]
            s1 = clamp_int(pump_status["pump1_speed"], 0, 100)
            s2 = clamp_int(pump_status["pump2_speed"], 0, 100)

        # Flow follows the active pump speeds directly
        flow = BASE["flow"]
        if p1_on:
            flow += int(round(FLOW_GAIN * s1))
        if p2_on:
            flow += int(round(FLOW_GAIN * s2))

        flow_in = flow
        flow_out = flow

        # Inlet pressure drops with increasing flow and active pump speed
        pressure_in = BASE["pressure_in"]
        pressure_in -= int(round(3.0 * max(0, flow - BASE["flow"])))
        pressure_in -= int(round(1.5 * s1 if p1_on else 0))
        pressure_in -= int(round(1.5 * s2 if p2_on else 0))

        if p1_on and p2_on:
            pressure_in -= 400

        # Outlet pressure increases with pump head
        if not (p1_on or p2_on):
            pressure_out = pressure_in - 80
        else:
            pressure_out = BASE["pressure_out"]
            pressure_out += int(round(6.0 * s1 if p1_on else 0))
            pressure_out += int(round(6.0 * s2 if p2_on else 0))

            if p1_on and p2_on:
                pressure_out += 1200

        # Temperature rises slightly with pump speed
        temp_in = BASE["temp_in"]
        if p1_on:
            temp_in += int(round(TEMP_GAIN * s1))
        if p2_on:
            temp_in += int(round(TEMP_GAIN * s2))

        if p1_on or p2_on:
            temp_out = temp_in + 2
        else:
            temp_out = BASE["temp_out"]

        pressure_in = clamp_int(pressure_in, *BOUNDS["pressure_in"])
        pressure_out = clamp_int(pressure_out, *BOUNDS["pressure_out"])
        flow_in = clamp_int(flow_in, *BOUNDS["flow_in"])
        flow_out = clamp_int(flow_out, *BOUNDS["flow_out"])
        temp_in = clamp_int(temp_in, *BOUNDS["temp_in"])
        temp_out = clamp_int(temp_out, *BOUNDS["temp_out"])

        context[1].setValues(4, IR_MAP["pressure_in"], [pressure_in])
        context[1].setValues(4, IR_MAP["pressure_out"], [pressure_out])
        context[1].setValues(4, IR_MAP["flow_in"], [flow_in])
        context[1].setValues(4, IR_MAP["flow_out"], [flow_out])
        context[1].setValues(4, IR_MAP["temp_in"], [temp_in])
        context[1].setValues(4, IR_MAP["temp_out"], [temp_out])

        time.sleep(0.2)


context[1].setValues(3, HR_MAP["pump1_speed"], [50])
context[1].setValues(3, HR_MAP["pump2_speed"], [50])

threading.Thread(target=read_commands, daemon=True).start()
threading.Thread(target=compute_and_write_sensors, daemon=True).start()

print("[+] Baseline OT Modbus Remote-I/O Running (Unit 1)")
print("    Sensors (IR/FC04):", IR_MAP)
print("    Pump Cmd (Coils): ", COIL_MAP)
print("    Pump Speed (HR):  ", HR_MAP)
print("[+] Modbus/TCP listening on 0.0.0.0:502")

StartTcpServer(context=context, address=("0.0.0.0", 502))
