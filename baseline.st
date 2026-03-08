PROGRAM BaselineControl
VAR
    (* Real sensor inputs from Python Modbus mapping *)
    real_pressure_in AT %IW100 : INT;
    real_pressure_out AT %IW101 : INT;
    real_flow_in AT %IW102 : INT;
    real_flow_out AT %IW103 : INT;
    real_temp_in AT %IW104 : INT;
    real_temp_out AT %IW105 : INT;

    (* Legacy FUXA variables *)
    (* Control values written by FUXA *)
    pump1_start AT %QX0.0 : BOOL := FALSE;
    pump2_start AT %QX1.0 : BOOL := FALSE;
    pump1_speed_in AT %QW10 : INT  := 50;
    pump2_speed_in AT %QW20 : INT  := 50;

    (* Process values read by FUXA *)
    pressure_in AT %IW1 : INT := 0;
    pressure_out AT %IW2 : INT := 0;
    flow_rate_in AT %IW3 : INT := 0;
    flow_rate_out AT %IW4 : INT := 0;
    temp_in AT %IW5 : INT := 0;
    temp_out AT %IW6 : INT := 0;

    (* Status and readback values for FUXA *)
    pump1_work AT %IX0.0 : BOOL := FALSE;
    pump2_work AT %IX1.0 : BOOL := FALSE;

    pump1_speed_out AT %IW10 : INT := 0;
    pump1_temp AT %IW11 : INT := 0;
    pump1_pressure AT %IW12 : INT := 0;

    pump2_speed_out AT %IW20 : INT := 0;
    pump2_temp AT %IW21 : INT := 0;
    pump2_pressure AT %IW22 : INT := 0;

    pump1_valve1 AT %IX0.1 : BOOL := FALSE;
    pump1_valve2 AT %IX0.2 : BOOL := FALSE;
    pump1_valve3 AT %IX0.3 : BOOL := FALSE;

    pump2_valve1 AT %IX1.1 : BOOL := FALSE;
    pump2_valve2 AT %IX1.2 : BOOL := FALSE;
    pump2_valve3 AT %IX1.3 : BOOL := FALSE;

    (* Remote IO commands mapped to Python Remote IO *)
    cmd_pump1_start AT %QX100.0 : BOOL;   (* Python coil 0 *)
    cmd_pump2_start AT %QX100.1 : BOOL;   (* Python coil 1 *)
    cmd_pump1_speed AT %QW100 : INT;    (* Python holding register 10 *)
    cmd_pump2_speed AT %QW110 : INT;    (* Python holding register 20 *)
END_VAR

VAR
    (* Helper aliases without AT mapping *)
    ui_pump1_start : BOOL;
    ui_pump2_start : BOOL;
    ui_pump1_speed : INT;
    ui_pump2_speed : INT;

    (* Safety limits *)
    SPEED_MIN : INT := 0;
    SPEED_MAX : INT := 100;
END_VAR


(* Copy legacy controls into helper aliases *)
ui_pump1_start := pump1_start;
ui_pump2_start := pump2_start;
ui_pump1_speed := pump1_speed_in;
ui_pump2_speed := pump2_speed_in;


(* Baseline process view from real Python values *)
pressure_in := real_pressure_in;
pressure_out := real_pressure_out;
flow_rate_in := real_flow_in;
flow_rate_out := real_flow_out;
temp_in := real_temp_in;
temp_out := real_temp_out;


(* Mirror UI controls to remote IO commands *)
cmd_pump1_start := ui_pump1_start;
cmd_pump2_start := ui_pump2_start;

cmd_pump1_speed := ui_pump1_speed;
cmd_pump2_speed := ui_pump2_speed;

(* Clamp speed values *)
IF cmd_pump1_speed < SPEED_MIN THEN cmd_pump1_speed := SPEED_MIN; END_IF;
IF cmd_pump2_speed < SPEED_MIN THEN cmd_pump2_speed := SPEED_MIN; END_IF;

IF cmd_pump1_speed > SPEED_MAX THEN cmd_pump1_speed := SPEED_MAX; END_IF;
IF cmd_pump2_speed > SPEED_MAX THEN cmd_pump2_speed := SPEED_MAX; END_IF;


(* Legacy indicators with lamps valves and readbacks *)
pump1_work := cmd_pump1_start;
pump2_work := cmd_pump2_start;

IF cmd_pump1_start THEN
    pump1_speed_out := cmd_pump1_speed;
ELSE
    pump1_speed_out := 0;
END_IF;

IF cmd_pump2_start THEN
    pump2_speed_out := cmd_pump2_speed;
ELSE
    pump2_speed_out := 0;
END_IF;

(* Local readback values *)
pump1_temp := temp_in;
pump1_pressure := pressure_in;

pump2_temp := temp_out;
pump2_pressure := pressure_out;

(* Valve lamp states *)
IF pump1_work THEN
    pump1_valve1 := TRUE;
    pump1_valve2 := TRUE;
    pump1_valve3 := FALSE;
ELSE
    pump1_valve1 := FALSE;
    pump1_valve2 := FALSE;
    pump1_valve3 := TRUE;
END_IF;

IF pump2_work THEN
    pump2_valve1 := TRUE;
    pump2_valve2 := TRUE;
    pump2_valve3 := FALSE;
ELSE
    pump2_valve1 := FALSE;
    pump2_valve2 := FALSE;
    pump2_valve3 := TRUE;
END_IF;

END_PROGRAM


CONFIGURATION Config0
    RESOURCE Res0 ON PLC
        TASK task0(INTERVAL := T#20ms, PRIORITY := 0);
        PROGRAM instance0 WITH task0 : BaselineControl;
    END_RESOURCE
END_CONFIGURATION
