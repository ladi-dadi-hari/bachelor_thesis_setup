PROGRAM BaselineControl
VAR
    (* Real sensor inputs from Python via Modbus mapping *)
    real_pressure_in AT %IW100 : INT;
    real_pressure_out AT %IW101 : INT;
    real_flow_in AT %IW102 : INT;
    real_flow_out AT %IW103 : INT;
    real_temp_in AT %IW104 : INT;
    real_temp_out AT %IW105 : INT;

    (* LEGACY FUXA VARIABLES *)

    (* Controls FUXA writes these *)
    pump1_start AT %QX0.0 : BOOL := FALSE;
    pump2_start AT %QX1.0 : BOOL := FALSE;
    pump1_speed_in AT %QW10 : INT  := 50;
    pump2_speed_in AT %QW20 : INT  := 50;

    (* Process view FUXA reads these *)
    pressure_in AT %IW1 : INT := 0;
    pressure_out AT %IW2 : INT := 0;
    flow_rate_in AT %IW3 : INT := 0;
    flow_rate_out AT %IW4 : INT := 0;
    temp_in AT %IW5 : INT := 0;
    temp_out AT %IW6 : INT := 0;

    (* Status lamps readback FUXA reads these *)
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
    cmd_pump1_start AT %QX100.0 : BOOL;   (* Python Coil 0 *)
    cmd_pump2_start AT %QX100.1 : BOOL;   (* Python Coil 1 *)
    cmd_pump1_speed AT %QW100 : INT;    (* Python HR 10 *)
    cmd_pump2_speed AT %QW110 : INT;    (* Python HR 20 *)

    (* ATTACK CONTROL REGISTER *)
    attack_control AT %QW11 : INT := 0;
END_VAR

VAR
    (* Helper aliases *)
    ui_pump1_start : BOOL;
    ui_pump2_start : BOOL;
    ui_pump1_speed : INT;
    ui_pump2_speed : INT;

    (* Safety clamps *)
    SPEED_MIN : INT := 0;
    SPEED_MAX : INT := 100;

    (* Attack State Machine *)
    attack_state : INT := 0;
    record_timer : TON;
    recovery_timer : TON;
    record_duration : TIME := T#3s;
    recovery_duration : TIME := T#2s;

    buffer_index : INT := 0;

    (* Recording buffers 3s for 20ms 149 Samples *)
    recorded_pressure_in : ARRAY[0..149] OF INT;
    recorded_pressure_out : ARRAY[0..149] OF INT;
    recorded_flow_in : ARRAY[0..149] OF INT;
    recorded_flow_out : ARRAY[0..149] OF INT;
    recorded_temp_in : ARRAY[0..149] OF INT;
    recorded_temp_out : ARRAY[0..149] OF INT;

    recorded_pump1_start : ARRAY[0..149] OF BOOL;
    recorded_pump2_start : ARRAY[0..149] OF BOOL;
    recorded_pump1_speed_in : ARRAY[0..149] OF INT;
    recorded_pump2_speed_in : ARRAY[0..149] OF INT;
    recorded_pump1_work : ARRAY[0..149] OF BOOL;
    recorded_pump2_work : ARRAY[0..149] OF BOOL;
    recorded_pump1_speed_out : ARRAY[0..149] OF INT;
    recorded_pump2_speed_out : ARRAY[0..149] OF INT;
    recorded_pump1_valve1 : ARRAY[0..149] OF BOOL;
    recorded_pump1_valve2 : ARRAY[0..149] OF BOOL;
    recorded_pump1_valve3 : ARRAY[0..149] OF BOOL;
    recorded_pump2_valve1 : ARRAY[0..149] OF BOOL;
    recorded_pump2_valve2 : ARRAY[0..149] OF BOOL;
    recorded_pump2_valve3 : ARRAY[0..149] OF BOOL;
    recorded_pump1_temp : ARRAY[0..149] OF INT;
    recorded_pump1_pressure : ARRAY[0..149] OF INT;
    recorded_pump2_temp : ARRAY[0..149] OF INT;
    recorded_pump2_pressure : ARRAY[0..149] OF INT;

    playback_index : INT := 0;
    last_attack_control : INT := 0;

    (* Snapshot of initial state when attack starts *)
    initial_pump1_start : BOOL := FALSE;
    initial_pump2_start : BOOL := FALSE;
    initial_pump1_speed_in : INT := 50;
    initial_pump2_speed_in : INT := 50;

    (* Ground truth internal variables not in SCADA *)
    ground_truth_pump1_temp : INT;
    ground_truth_pump1_pressure : INT;
    ground_truth_pump2_temp : INT;
    ground_truth_pump2_pressure : INT;
END_VAR

(* 0 Copy legacy controls into helper vars optional *)
ui_pump1_start := pump1_start;
ui_pump2_start := pump2_start;
ui_pump1_speed := pump1_speed_in;
ui_pump2_speed := pump2_speed_in;

(* A ATTACK STATE MACHINE MIT RECOVERY PHASE *)
(* State Transitions *)
IF attack_control = 1 AND last_attack_control = 0 THEN
    (* Rising edge Start attack sequence *)
    initial_pump1_start := pump1_start;
    initial_pump2_start := pump2_start;
    initial_pump1_speed_in := pump1_speed_in;
    initial_pump2_speed_in := pump2_speed_in;

    attack_state := 1;
    buffer_index := 0;
    record_timer(IN:=TRUE, PT:=record_duration);
ELSIF attack_control = 0 AND attack_state = 2 THEN
    (* Fallende Flanke während Angriff Starte Recovery Phase *)
    attack_state := 3;
    recovery_timer(IN:=TRUE, PT:=recovery_duration);
END_IF;

last_attack_control := attack_control;

(* State machine execution *)
CASE attack_state OF
    1: (* Recording state collect 3 seconds of data *)
        record_timer(IN:=TRUE, PT:=record_duration);

        IF buffer_index < 150 THEN
            (* Real sensor values *)
            recorded_pressure_in[buffer_index] := real_pressure_in;
            recorded_pressure_out[buffer_index] := real_pressure_out;
            recorded_flow_in[buffer_index] := real_flow_in;
            recorded_flow_out[buffer_index] := real_flow_out;
            recorded_temp_in[buffer_index] := real_temp_in;
            recorded_temp_out[buffer_index] := real_temp_out;

            (* UI controls *)
            recorded_pump1_start[buffer_index] := pump1_start;
            recorded_pump2_start[buffer_index] := pump2_start;
            recorded_pump1_speed_in[buffer_index] := pump1_speed_in;
            recorded_pump2_speed_in[buffer_index] := pump2_speed_in;

            (* Calculated status values *)
            recorded_pump1_work[buffer_index] := ui_pump1_start;
            recorded_pump2_work[buffer_index] := ui_pump2_start;

            (* Speed outputs *)
            IF ui_pump1_start THEN
                recorded_pump1_speed_out[buffer_index] := ui_pump1_speed;
            ELSE
                recorded_pump1_speed_out[buffer_index] := 0;
            END_IF;

            IF ui_pump2_start THEN
                recorded_pump2_speed_out[buffer_index] := ui_pump2_speed;
            ELSE
                recorded_pump2_speed_out[buffer_index] := 0;
            END_IF;

            (* Valve status *)
            IF ui_pump1_start THEN
                recorded_pump1_valve1[buffer_index] := TRUE;
                recorded_pump1_valve2[buffer_index] := TRUE;
                recorded_pump1_valve3[buffer_index] := FALSE;
            ELSE
                recorded_pump1_valve1[buffer_index] := FALSE;
                recorded_pump1_valve2[buffer_index] := FALSE;
                recorded_pump1_valve3[buffer_index] := TRUE;
            END_IF;

            IF ui_pump2_start THEN
                recorded_pump2_valve1[buffer_index] := TRUE;
                recorded_pump2_valve2[buffer_index] := TRUE;
                recorded_pump2_valve3[buffer_index] := FALSE;
            ELSE
                recorded_pump2_valve1[buffer_index] := FALSE;
                recorded_pump2_valve2[buffer_index] := FALSE;
                recorded_pump2_valve3[buffer_index] := TRUE;
            END_IF;

            (* Pump specific temps and pressures *)
            recorded_pump1_temp[buffer_index] := temp_in;
            recorded_pump1_pressure[buffer_index] := pressure_in;
            recorded_pump2_temp[buffer_index] := temp_out;
            recorded_pump2_pressure[buffer_index] := pressure_out;

            buffer_index := buffer_index + 1;
        END_IF;

        IF record_timer.Q THEN
            (* 3 seconds elapsed switch to attack mode *)
            attack_state := 2;
            playback_index := 0;
            record_timer(IN:=FALSE);
        END_IF;

    2: (* Attack state replay recorded data to operator *)
        (* Cycle through recorded data *)
        playback_index := playback_index + 1;
        IF playback_index >= 150 THEN
            playback_index := 0;
        END_IF;

    3: (* Recovery state wait 2s while system stabilizes *)
        recovery_timer(IN:=TRUE, PT:=recovery_duration);

        playback_index := playback_index + 1;
        IF playback_index >= 150 THEN
            playback_index := 0;
        END_IF;

        IF recovery_timer.Q THEN
            attack_state := 0;
            recovery_timer(IN:=FALSE);
        END_IF;
END_CASE;

(* B REMOTE I O COMMANDS Physical pump control *)
CASE attack_state OF
    2: (* ATTACK MODE Force both pumps to 100 percent *)
        cmd_pump1_start := TRUE;
        cmd_pump2_start := TRUE;
        cmd_pump1_speed := 100;
        cmd_pump2_speed := 100;

    3: (* RECOVERY MODE *)
        cmd_pump1_start := ui_pump1_start;
        cmd_pump2_start := ui_pump2_start;
        cmd_pump1_speed := ui_pump1_speed;
        cmd_pump2_speed := ui_pump2_speed;

    ELSE (* NORMAL MODE Use operator controls *)
        cmd_pump1_start := ui_pump1_start;
        cmd_pump2_start := ui_pump2_start;
        cmd_pump1_speed := ui_pump1_speed;
        cmd_pump2_speed := ui_pump2_speed;
END_CASE;

(* Clamp speeds always active *)
IF cmd_pump1_speed < SPEED_MIN THEN cmd_pump1_speed := SPEED_MIN; END_IF;
IF cmd_pump2_speed < SPEED_MIN THEN cmd_pump2_speed := SPEED_MIN; END_IF;
IF cmd_pump1_speed > SPEED_MAX THEN cmd_pump1_speed := SPEED_MAX; END_IF;
IF cmd_pump2_speed > SPEED_MAX THEN cmd_pump2_speed := SPEED_MAX; END_IF;

(* C OPERATOR DISPLAY What FUXA sees *)
CASE attack_state OF
    2, 3: (* ATTACK oder RECOVERY Show recorded normal data *)
        (* Sensor values from recording *)
        pressure_in := recorded_pressure_in[playback_index];
        pressure_out := recorded_pressure_out[playback_index];
        flow_rate_in := recorded_flow_in[playback_index];
        flow_rate_out := recorded_flow_out[playback_index];
        temp_in := recorded_temp_in[playback_index];
        temp_out := recorded_temp_out[playback_index];

        (* UI controls show recorded values *)
        pump1_start := recorded_pump1_start[playback_index];
        pump2_start := recorded_pump2_start[playback_index];
        pump1_speed_in := recorded_pump1_speed_in[playback_index];
        pump2_speed_in := recorded_pump2_speed_in[playback_index];

        (* Status indicators show recorded values *)
        pump1_work := recorded_pump1_work[playback_index];
        pump2_work := recorded_pump2_work[playback_index];
        pump1_speed_out := recorded_pump1_speed_out[playback_index];
        pump2_speed_out := recorded_pump2_speed_out[playback_index];

        (* Valve status show recorded values *)
        pump1_valve1 := recorded_pump1_valve1[playback_index];
        pump1_valve2 := recorded_pump1_valve2[playback_index];
        pump1_valve3 := recorded_pump1_valve3[playback_index];
        pump2_valve1 := recorded_pump2_valve1[playback_index];
        pump2_valve2 := recorded_pump2_valve2[playback_index];
        pump2_valve3 := recorded_pump2_valve3[playback_index];

        (* Pump specific temps and pressures show recorded values *)
        pump1_temp := recorded_pump1_temp[playback_index];
        pump1_pressure := recorded_pump1_pressure[playback_index];
        pump2_temp := recorded_pump2_temp[playback_index];
        pump2_pressure := recorded_pump2_pressure[playback_index];

    ELSE (* NORMAL MODE Show real data *)
        pressure_in := real_pressure_in;
        pressure_out := real_pressure_out;
        flow_rate_in := real_flow_in;
        flow_rate_out := real_flow_out;
        temp_in := real_temp_in;
        temp_out := real_temp_out;

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

        (* Valve lamps *)
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

        (* In normal mode pump temps pressures equal process temps pressures *)
        pump1_temp := temp_in;
        pump1_pressure := pressure_in;
        pump2_temp := temp_out;
        pump2_pressure := pressure_out;
END_CASE;

(* D GROUND TRUTH *)
ground_truth_pump1_temp := real_temp_in;
ground_truth_pump1_pressure := real_pressure_in;
ground_truth_pump2_temp := real_temp_out;
ground_truth_pump2_pressure := real_pressure_out;

END_PROGRAM

CONFIGURATION Config0
    RESOURCE Res0 ON PLC
        TASK task0(INTERVAL := T#20ms, PRIORITY := 0);
        PROGRAM instance0 WITH task0 : BaselineControl;
    END_RESOURCE
END_CONFIGURATION
