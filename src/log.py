#!/usr/bin/env python3
# Parse log and print results to stdout
# This script is supposed to extensively fault-tolerated when parsing log
# because log can be horribly corruptted...

import os
import logging
import re
from collections import deque
import datetime

FNAME_LOG = os.environ["ADW_PROJ_LOG"]
ABS_PATH_LOG = f'{os.environ["ADW_PROJ_ROOT_DIR"]}/{FNAME_LOG}'


class ADWLogEntryInvalidError(Exception):
    pass


class LogEntry:
    pass


class LogEntryValid(LogEntry):
    def __init__(self, date, time, commit, ret, nonce, cmd) -> None:
        # format: "%Y-%m-%d %H:%M:%S"
        self.date_time = datetime.datetime.fromisoformat(f"{date} {time}")
        self.commit = commit
        self.ret = ret
        self.nonce = nonce
        self.cmd = cmd
        if re.compile('^[0-9a-f]{7}$').fullmatch(commit) is None:
            raise ADWLogEntryInvalidError(
                f'Invalid commit_id "{commit}": {self}')


class LogEntryInvalid(LogEntry):
    def __init__(self, line: str, error: Exception) -> None:
        self.line = line
        self.error = error

    def __str__(self) -> str:
        return self.line


class LogEntryStart(LogEntryValid):
    def __init__(self, date, time, commit, ret, nonce, cmd) -> None:
        super().__init__(date, time, commit, ret, nonce, cmd)
        if self.ret != '_':
            raise ADWLogEntryInvalidError("Invalid status in LogEntryStart")

    def __str__(self) -> str:
        return f"+ {self.date_time} {self.commit} {self.ret:>3} {self.cmd}"


class LogEntryFinish(LogEntryValid):
    def __init__(self, date, time, commit, ret, nonce, cmd) -> None:
        super().__init__(date, time, commit, ret, nonce, cmd)
        try:
            _ = int(self.ret)  # must be a valid int
        except:
            raise ADWLogEntryInvalidError("Invalid status in LogEntryFinish")

    def __str__(self) -> str:
        return f"- {self.date_time} {self.commit} {self.ret:>3} {self.cmd}"


def get_log_entry(line: str) -> LogEntry:
    try:
        line = line.strip()
        mark, date, time, commit, ret, nonce, cmd = line.split(maxsplit=6)
        if mark == "+":
            return LogEntryStart(date, time, commit, ret, nonce, cmd)
        elif mark == "-":
            return LogEntryFinish(date, time, commit, ret, nonce, cmd)
        else:
            raise ADWLogEntryInvalidError(f"Unknown log mark '{mark}'")
    except Exception as e:
        logging.warning(f"{e}")
        return LogEntryInvalid(line, e)


# Merge two log entries (start & finish) to an execution record
# If fails, make it an invalid record
class ExecRecord():
    pass


class ExecRecordValid(ExecRecord):
    def __init__(self, start: LogEntryStart, finish: LogEntryFinish) -> None:
        self.start = start
        self.finish = finish

    def __str__(self) -> str:
        td = self.finish.date_time - self.start.date_time
        hours, remainder = divmod(td.seconds, 3600)
        minutes, seconds = divmod(remainder, 60)
        td_str = f"Time:   {self.start.date_time} -> {self.finish.date_time} ["
        if td.days > 0:
            td_str += f"{td.days}d"
        if hours > 0:
            td_str += f"{hours}h"
        if minutes > 0:
            td_str += f"{minutes}m"
        td_str += f"{seconds}s]"
        if self.start.commit == self.finish.commit:
            cmt_str = f"Commit: {self.start.commit}"
        else:
            cmt_str = f"Commit: {self.start.commit} -> {self.finish.commit}"
        return f"{td_str}\n{cmt_str}\n" \
            f"Status: {self.finish.ret}\nCommand: {self.start.cmd}\n"


# log entry itself doesn't make sense
class ExecRecordInvalid(ExecRecord):
    def __init__(self, log_entry: LogEntryInvalid) -> None:
        self.log_entry = log_entry

    def __str__(self) -> str:
        return f"""@ Invalid Log Entry:{"":<59}@
@     {str(self.log_entry):<72} @
@ Error:{"":<71}@
@     {str(self.log_entry.error):<73}@
"""


# log entry is valid, but only have start entry without finish entry
class ExecRecordMismatched(ExecRecord):
    def __init__(self, log_entry: LogEntryValid) -> None:
        self.log_entry = log_entry

    def __str__(self) -> str:
        if isinstance(self.log_entry, LogEntryStart):
            return f"""@ Mismatched Log Entry:{"":<56}@
@     {str(self.log_entry):<72} @
@ Error:{"":<71}@
@     No matching LogEntryFinish found{"":<41}@
"""
        else:
            assert isinstance(self.log_entry, LogEntryFinish)
            return f"""@ Mismatched Log Entry:{"":<56}@
@     {str(self.log_entry):<72} @
@ Error:{"":<71}@
@     No matching LogEntryStart found{"":<42}@
"""


def check_match(start: LogEntryStart, finish: LogEntryFinish):
    return start.nonce == finish.nonce and start.cmd == finish.cmd


if __name__ == "__main__":
    # read and parse log into LogEntry objects
    with open(ABS_PATH_LOG, "rt") as f:
        log_entry_queue = deque()
        for line in f:
            log_entry_queue.append(get_log_entry(line))

    # match and merge LogEntry objects into ExecRecords
    exec_record_queue = deque()
    while len(log_entry_queue) > 0:
        curr_le = log_entry_queue.popleft()
        if isinstance(curr_le, LogEntryInvalid):
            exec_record_queue.append(ExecRecordInvalid(curr_le))
            continue
        if isinstance(curr_le, LogEntryFinish):
            exec_record_queue.append(ExecRecordMismatched(curr_le))
            continue
        assert isinstance(curr_le, LogEntryStart)
        if len(log_entry_queue) == 0:
            exec_record_queue.append(ExecRecordMismatched(curr_le))
            continue
        next_le = log_entry_queue.popleft()
        if not isinstance(next_le, LogEntryFinish) or not check_match(
                curr_le, next_le):
            # mismatch, put it back
            log_entry_queue.appendleft(next_le)
            exec_record_queue.append(ExecRecordMismatched(curr_le))
            continue
        exec_record_queue.append(ExecRecordValid(curr_le, next_le))

    # dump ExecRecords (in reverse order)
    exec_record_queue.reverse()
    for er in exec_record_queue:
        print(f"{er}")
