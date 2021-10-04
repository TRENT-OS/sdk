#!/usr/bin/python3

# ------------------------------------------------------------------------------
# Copyright (C) 2021, HENSOLDT Cyber GmbH
# ------------------------------------------------------------------------------

"""
Backtraces -finstrument-functions markers with function hex addresses into
function names.

The script expects as arguments:
    --stdout_file:  An output file of a system (either still running or not)
                    containing the markers produced by enabling the gcc flag
                    -fintstument-functions
    --symbols_file: A .lst map file containing the symbols supposed to match the
                    hex addresses
    --timeout:      A timeout (in secs) parameter to exit the script when
                    waiting for new input. Default value is 0.

It will print out the same content of stdout_file but with the markers (with hex
strings inside corresponding to the function addresses) resolved to symbols
(names of the functions) in a human readable format with a layout that
emphasizes the function calls nesting.

E.g.:

Call the script:
./backtrace.py --stdout_file qemu_stdout.txt --symbols_file
build-zynq7000-Debug-httpd/os_system/httpServer.instance.bin.lst

Input example:

Booting all finished, dropped to user space
main@main.c:2125 Starting CapDL Loader...
main@main.c:2127 CapDL Loader done, suspending...
0x25a00 {
0x25950 {
0x2e35c {
   INFO: /host/trentos_sdk/components/UART/Uart.c:235: initialize UART
   INFO: /host/trentos_sdk/components/UART/Uart.c:295: initialize UART ok
   INFO: /host/httpd/components/Ticker/src/Ticker.c:14: Ticker running
   INFO: /host/httpd/components/NwStack/src/NwStack.c:59: [NwStack 'nwStack'] starting
   INFO: /host/trentos_sdk/components/NIC_ChanMux/driver.c:19: [NIC 'nwDriver'] post_init()
   INFO: /host/trentos_sdk/components/NIC_ChanMux/driver.c:67: [NIC 'nwDriver'] starting driver
   INFO: /host/trentos_sdk/libs/chanmux_nic_driver/src/chanmux_nic_drv_cfg.c:167: network driver init
   INFO: /host/trentos_sdk/libs/chanmux_nic_driver/src/chanmux_nic_drv_cfg.c:182: ChanMUX channels: ctrl=4, data=5
0x2e35c }
0x30fe0 {
0x30fe0 }
0x2e53c {
0x2e53c }
0x25950 }
0x25a00 }

Output example:

Booting all finished, dropped to user space
main@main.c:2125 Starting CapDL Loader...
main@main.c:2127 ESC[0mESC[32mCapDL Loader done, suspending...ESC[0m
_GNUC_init_helper_MHD_init() {
| MHD_init() {
| | MHD_monotonic_sec_counter_init() {
   INFO: /host/trentos_sdk/components/UART/Uart.c:235: initialize UART
   INFO: /host/trentos_sdk/components/UART/Uart.c:295: initialize UART ok
   INFO: /host/httpd/components/Ticker/src/Ticker.c:14: Ticker running
   INFO: /host/httpd/components/NwStack/src/NwStack.c:59: [NwStack 'nwStack'] starting
   INFO: /host/trentos_sdk/components/NIC_ChanMux/driver.c:19: [NIC 'nwDriver'] post_init()
   INFO: /host/trentos_sdk/components/NIC_ChanMux/driver.c:67: [NIC 'nwDriver'] starting driver
   INFO: /host/trentos_sdk/libs/chanmux_nic_driver/src/chanmux_nic_drv_cfg.c:167: network driver init
   INFO: /host/trentos_sdk/libs/chanmux_nic_driver/src/chanmux_nic_drv_cfg.c:182: ChanMUX channels: ctrl=4, data=5
| | MHD_monotonic_sec_counter_init() }
| | MHD_send_init_static_vars_() {
| | MHD_send_init_static_vars_() }
| | MHD_init_mem_pools_() {
| | MHD_init_mem_pools_() }
| MHD_init()
_GNUC_init_helper_MHD_init() }
"""

import time
import re
import fcntl
import os
import argparse


#------------------------------------------------------------------------------
def open_file_non_blocking(file_name, mode, nl=None):
    """
    Open a file and set non blocking OS flag.

    Args:
    file_name(str): the file full path
    mode: mode to pass to open()
    nl(str, optional): newline

    Returns:
    f(file): the file object
    """

    f = open(file_name, mode, newline=nl)
    fd = f.fileno()
    flag = fcntl.fcntl(fd, fcntl.F_GETFL)
    fcntl.fcntl(fd, fcntl.F_SETFL, flag | os.O_NONBLOCK)
    flag = fcntl.fcntl(fd, fcntl.F_GETFL)

    return f


#------------------------------------------------------------------------------
def get_remaining_timeout_or_zero(time_end):
    time_now = time.time()
    return 0 if (time_now >= time_end) else time_end - time_now;


#------------------------------------------------------------------------------
def read_line_from_log_file_with_timeout(f, timeout_sec=0):
    """
    Read a line from a logfile with a timeout. If the timeout is 0, it is
    disabled. The file handle must be opened in non-blocking mode.
    """

    time_end = time.time() + timeout_sec
    line = ""

    while True:
        # readline() will return a string, which is terminated by "\n" for
        # every line. For the last line of the file, it returns a string
        # that is not terminated by "\n" to indicate the end of the file. If
        # another task is appending data to the file, repeated calls to
        # readline() may return multiple strings without "\n", each containing
        # the new data written to the file.
        #
        #  loop iteration 1:     | line part |...
        #  loop iteration 2:               | line part |...
        #  ..
        #  loop iteration k:                                | line+\n |
        #
        # There is a line break bug in some logs, "\n\r" is used instead of
        # "\r\n". Universal newline handling accepts "\r", "\n" and "\r\n" as
        # line break. We end up with some empty lines then as "\n\r" is taken
        # as two line breaks.

        line += f.readline()
        if not line.endswith("\n"):
            # We consider timeouts only if we have to block. As long as there
            # is no blocking operation, we don't care about the timeouts. The
            # rational is, that processing the log could be slow, but all data
            # is in the logs already. We don't want to fail just because we hit
            # some timeout. If a root test executor is really concerned about
            # tests running too long, it must setup a separate watchdog that
            # simply kills the test.
            new_timeout = get_remaining_timeout_or_zero(time_end)
            if (0 == new_timeout):
                return None

            # We still have time left, so sleep a while and check again. Note
            # that we don't check for a timeout immediately after the sleep.
            # Rationale is, that waiting for a fixed time is useless, if we
            # know this would make us run into a timeout - we should not wait
            # at all in this case.
            time.sleep( min(0.5, new_timeout) )
            continue

        # We have reached the end of a line, return it.
        return line

#------------------------------------------------------------------------------
def hex_2_symbol(f, d, hex):
    """
    Given a OS lst map file 'f', a dictionary 'd' and an hex string 'hex'
    it tries to retrieve the symbol string corresponding to that hex address
    from the dictionary first.
    If the string is found then it is returned, otherwise the file get scanned
    in order to find a correspondence. If the correspondence is found the
    resulting symbol string gets added to the dictionary and returned,
    otherwise the 'hex' string itself gets returned.
    """
    symbol = d.get(hex)

    if symbol is not None:
        return symbol

    f.seek(0)
    while True:
        line = read_line_from_log_file_with_timeout(f, 0)
        if line is None:
            break
        else:
            pattern = "^([0]+" + hex +".*text.*0[0-9a-f]+[' ']+)(.*)"
            regex_compiled = re.compile(pattern)
            mo_entry = regex_compiled.search(line)
            if mo_entry is not None:
                d[hex] = mo_entry.group(2)
                return mo_entry.group(2)
    return hex

# ------------------------------------------------------------------------------

parser = argparse.ArgumentParser()
parser.add_argument('--stdout_file', type=str, required=True)
parser.add_argument('--symbols_file', type=str, required=True)
parser.add_argument('--timeout', type=int, default=0, required=False)
args = parser.parse_args()

print("Processing " + args.stdout_file)

stdout_file     = open_file_non_blocking(args.stdout_file, 'r')
symbols_file    = open(args.symbols_file, 'r')
nest            = 0
dictionary      = {}

while True:
    line = read_line_from_log_file_with_timeout(stdout_file, args.timeout)
    if line is None:
        break
    else:
        if line != "\n":
            entryPattern="^0x([0-9a-f]+) {"
            exitPattern="^0x([0-9a-f]+) }"
            regex_entry_compiled = re.compile(entryPattern)
            regex_exit_compiled = re.compile(exitPattern)
            mo_entry = regex_entry_compiled.search(line)
            mo_exit = regex_exit_compiled.search(line)

            if mo_entry is None and mo_exit is None:
                print(line, end='')
            else:
                if mo_entry is not None:
                    print("| " * nest + hex_2_symbol(symbols_file, dictionary, mo_entry.group(1)) + "() {")
                    nest=nest+1
                if mo_exit is not None:
                    nest=nest-1
                    print("| " * nest + hex_2_symbol(symbols_file, dictionary, mo_exit.group(1)) + "() }")
