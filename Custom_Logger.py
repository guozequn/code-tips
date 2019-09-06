#!/usr/bin/env python
# -*- coding:utf-8 -*-
# @Time    : 2019/9/6 15:33
# @Author  : ZeQun
# @File    : logger.py
import os
import logbook
from logbook import Logger, RotatingFileHandler
from logbook.more import ColorizedStderrHandler


class CustomLog(object):
    """
        Custom create Logs.
        Only create logs.{{ level }} when logs output.

    """
    def __init__(self, log_name, custom_path=False, debug=False):
        self.name = log_name
        self.logger = Logger(log_name)
        self.levels = []
        self.log_path = os.path.dirname(os.path.realpath(__file__))

        if custom_path:
            self.log_dir = os.path.join(custom_path, "logs")
        else:
            self.log_dir = os.path.join(self.log_path, "logs")

        if debug:
            debug_handler = ColorizedStderrHandler(bubble=True)
            debug_handler.formatter = self.user_handler_log_formatter
            self.logger.handlers.append(debug_handler)

    def __getattr__(self, level):
        if level not in self.levels:
            if not os.path.isdir(self.log_dir):
                os.makedirs(self.log_dir)

            log_file = os.path.join(self.log_dir, '{}.{}'.format(self.name, level))
            file_handler = RotatingFileHandler(
                filename=log_file,
                level=getattr(logbook, level.upper()),
                max_size=1000000000
            )

            file_handler.formatter = self.user_handler_log_formatter
            self.logger.handlers.append(file_handler)

        return getattr(self.logger, level)

    @staticmethod
    def user_handler_log_formatter(record, handler):
        formatter = "[{dt}] [{level}] [{filename}] [{func_name}] [{lineno}] {msg}".format(
            dt=record.time,
            level=record.level_name,
            filename=os.path.split(record.filename)[-1],
            func_name=record.func_name,
            lineno=record.lineno,
            msg=record.message,
        )
        return formatter


if __name__ == '__main__':
    custom_log = CustomLog("test", debug=True)
    custom_log.info('user_info')
    custom_log.info('user_info')
    custom_log.info('user_info')
    custom_log.info('user_info')
