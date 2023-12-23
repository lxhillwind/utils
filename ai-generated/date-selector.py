#!/usr/bin/env python3

import sys
from PyQt6.QtWidgets import QApplication, QCalendarWidget, QLabel, QVBoxLayout, QMainWindow, QWidget, QTimeEdit
from PyQt6.QtCore import Qt, QEvent, QTime, QDateTime, QDate
from PyQt6.QtGui import QFont, QTextCharFormat, QColor

ctrl_key = Qt.KeyboardModifier.MetaModifier if sys.platform == 'darwin' else Qt.KeyboardModifier.ControlModifier


class CustomCalendar(QMainWindow):
    def __init__(self, *args, **kwargs):
        super(CustomCalendar, self).__init__(*args, **kwargs)

        # 创建一个 QWidget 作为 QMainWindow 的中心窗口
        central_widget = QWidget(self)
        self.setCentralWidget(central_widget)

        # 创建一个 QVBoxLayout，并将其设置为中心窗口的布局
        layout = QVBoxLayout(central_widget)

        self.calendar = CalendarWidget(self)
        layout.addWidget(self.calendar)

        self.time_edit = QTimeEdit(self)
        current_time = QTime.currentTime()
        self.time_edit.setTime(QTime(current_time.hour(), 0, 0))  # 设置默认时间为当前小时，分钟和秒归零
        layout.addWidget(self.time_edit)
        self.time_edit.hide()

        font = QFont()
        font.setFixedPitch(True)
        font.setStyleHint(QFont.StyleHint.Monospace)

        self.instructions = QLabel(self)
        self.instructions.setFont(font)
        self.instructions.setText(
            "按键说明           : \n"
            "\n"
            "- Ctrl + ]         : 确认选择\n"
            "- Ctrl + [ / <Esc> : 退出\n"
            "- <Tab> / <S-Tab>  : 切换选择框\n"
            "- Ctrl + T         : 显示 / 隐藏时间框\n"
            "\n"
            "- 在日历界面按住 Ctrl 键时，使用 h/j/k/l 可以调整选择的日期\n"
        )
        layout.addWidget(self.instructions)

    def keyPressEvent(self, event):
        if event.key() == Qt.Key.Key_BracketRight and event.modifiers() == ctrl_key:
            self.print_date_time()
            QApplication.instance().quit()
        elif (
                event.key() == Qt.Key.Key_Escape
                or (event.key() == Qt.Key.Key_C and event.modifiers() == ctrl_key)
                or (event.key() == Qt.Key.Key_BracketLeft and event.modifiers() == ctrl_key)
                ):
            QApplication.instance().quit()
        elif event.key() == Qt.Key.Key_T and event.modifiers() == ctrl_key:
            if self.time_edit.isHidden():
                self.time_edit.show()
            else:
                self.time_edit.hide()
        else:
            super().keyPressEvent(event)

    def print_date_time(self):
        date = self.calendar.selectedDate()
        time = self.time_edit.time()
        date_time = QDateTime(date, time)
        if self.time_edit.isHidden():
            print(date_time.toString("yyyy-MM-dd"))
        else:
            print(date_time.toString("yyyy-MM-dd HH:mm:ss"))

class CalendarWidget(QCalendarWidget):
    def __init__(self, *args, **kwargs):
        super(CalendarWidget, self).__init__(*args, **kwargs)
        self.installEventFilter(self)
        self.highlightToday()

    def highlightToday(self):
        # Create a QTextCharFormat object
        fmt = QTextCharFormat()
        # Set the background color
        fmt.setBackground(QColor(Qt.GlobalColor.cyan))
        # Set the format for today's date
        self.setDateTextFormat(QDate.currentDate(), fmt)

    def eventFilter(self, obj, event):
        if event.type() == QEvent.Type.KeyPress and self.key_handled(event):
            return True
        return super(CalendarWidget, self).eventFilter(obj, event)

    def key_handled(self, event):
        handled = True
        if event.key() == Qt.Key.Key_J:
            self.setSelectedDate(self.selectedDate().addDays(7))
        elif event.key() == Qt.Key.Key_K:
            self.setSelectedDate(self.selectedDate().addDays(-7))
        elif event.key() == Qt.Key.Key_H:
            self.setSelectedDate(self.selectedDate().addDays(-1))
        elif event.key() == Qt.Key.Key_L:
            self.setSelectedDate(self.selectedDate().addDays(1))
        else:
            handled = False
        return handled


def main():
    app = QApplication(sys.argv)
    window = CustomCalendar()
    window.show()
    sys.exit(app.exec())

if __name__ == '__main__':
    main()
