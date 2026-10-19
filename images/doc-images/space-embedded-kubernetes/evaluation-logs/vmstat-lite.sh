#!/bin/sh
# vmstat-lite: emulates `vmstat -a -SM -w -t <interval> <count>` from /proc
# for BusyBox-only systems. Emits a 'gu' column (always 0) so the output
# parses with kosmoedge/vmstat-visualizer.
# Usage: vmstat-lite.sh [interval] [count]
INTERVAL=${1:-1}
COUNT=${2:-30}
PAGE_KB=4

exec awk -v interval="$INTERVAL" -v count="$COUNT" -v page_kb="$PAGE_KB" '
function readstat(   line, f) {
    while ((getline line < "/proc/stat") > 0) {
        split(line, f, " ")
        if (f[1] == "cpu") {
            c_us = f[2] + f[3]; c_sy = f[4] + f[7] + f[8]; c_id = f[5]
            c_wa = f[6]; c_st = f[9]
        } else if (f[1] == "intr") c_in = f[2]
        else if (f[1] == "ctxt") c_cs = f[2]
        else if (f[1] == "procs_running") p_r = f[2]
        else if (f[1] == "procs_blocked") p_b = f[2]
    }
    close("/proc/stat")
}
function readvm(   line, f) {
    while ((getline line < "/proc/vmstat") > 0) {
        split(line, f, " ")
        if (f[1] == "pgpgin") v_bi = f[2]
        else if (f[1] == "pgpgout") v_bo = f[2]
        else if (f[1] == "pswpin") v_si = f[2]
        else if (f[1] == "pswpout") v_so = f[2]
    }
    close("/proc/vmstat")
}
function readmem(   line, f) {
    while ((getline line < "/proc/meminfo") > 0) {
        split(line, f, " ")
        m[f[1]] = f[2]
    }
    close("/proc/meminfo")
}
function readup(   line, f) {
    getline line < "/proc/uptime"; close("/proc/uptime")
    split(line, f, " "); return f[1]
}
function pct(x, tot) { return tot > 0 ? int((100 * x + tot / 2) / tot) : 0 }
function emit(dt,   tot) {
    readmem()
    tot = (c_us - o_us) + (c_sy - o_sy) + (c_id - o_id) + (c_wa - o_wa) + (c_st - o_st)
    if (dt <= 0) dt = 1
    printf "%2d %2d %12d %12d %12d %12d %4d %4d %5d %5d %4d %4d %3d %3d %3d %3d %3d %3d %s\n",
        p_r, p_b,
        int((m["SwapTotal:"] - m["SwapFree:"]) / 1024), int(m["MemFree:"] / 1024),
        int(m["Inactive:"] / 1024), int(m["Active:"] / 1024),
        int((v_si - o_si) * page_kb / 1024 / dt), int((v_so - o_so) * page_kb / 1024 / dt),
        int((v_bi - o_bi) / dt), int((v_bo - o_bo) / dt),
        int((c_in - o_in) / dt), int((c_cs - o_cs) / dt),
        pct(c_us - o_us, tot), pct(c_sy - o_sy, tot), pct(c_id - o_id, tot),
        pct(c_wa - o_wa, tot), pct(c_st - o_st, tot), 0,
        strftime("%Y-%m-%d %H:%M:%S")
    fflush()
}
function snap() {
    o_us = c_us; o_sy = c_sy; o_id = c_id; o_wa = c_wa; o_st = c_st
    o_in = c_in; o_cs = c_cs; o_bi = v_bi; o_bo = v_bo; o_si = v_si; o_so = v_so
}
BEGIN {
    print "procs -----------------------memory---------------------- ---swap-- -----io---- -system-- ----------cpu---------- -----timestamp-----"
    print " r  b         swpd         free        inact       active   si   so    bi    bo   in   cs  us  sy  id  wa  st  gu                  UTC"
    # First line: averages since boot, like procps vmstat.
    readstat(); readvm(); up = readup()
    emit(up)
    for (i = 1; i < count; i++) {
        snap(); t0 = up
        system("sleep " interval)
        readstat(); readvm(); up = readup()
        emit(up - t0)
    }
}'
