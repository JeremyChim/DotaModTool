import json
import os
import subprocess
import time

from PySide6.QtCore import QUrl, Qt
from PySide6.QtGui import QColor, QDesktopServices, QFont
from PySide6.QtWidgets import QListWidgetItem

from ui.ui import *

NPC_DIR = os.path.join(os.path.dirname(__file__), "npc", "heroes")
VPK_DIR = os.path.join(os.path.dirname(__file__), "vpk", "pak01_dir", "scripts", "npc", "heroes")
NPP_PATH = 'C:\\Program Files\\Notepad++\\notepad++.exe'
NPP_PATH_X86 = 'C:\\Program Files (x86)\\Notepad++\\notepad++.exe'
KEYWORDS = ['CastPoint', 'Cooldown', 'ManaCost', 'RestoreTime']
MOD1 = '''[TAB]"[AB_NAME]"\t\t"[AB_VALUE]"
[TAB]"special_bonus_shard"\t\t"[SA_VALUE]"
[TAB]"special_bonus_scepter"\t\t"[SP_VALUE]"'''
MOD2 = '''[TAB]"[AB_NAME]"
[TAB]{
[TAB]\t\t"value"\t\t"[AB_VALUE]"
[TAB]\t\t"special_bonus_shard"\t\t"[SA_VALUE]"
[TAB]\t\t"special_bonus_scepter"\t\t"[SP_VALUE]"
[TAB]}'''


class Win(QMainWindow, Ui_MainWindow):
    def __init__(self):
        super().__init__()
        self.setupUi(self)
        self.files = []  # 全部文件名缓存
        self.config = {}
        self.current_file = 'npc_dota_hero_abaddon.txt'
        self.init()

    def init(self):
        """初始化所有的控件绑定，按钮搜索框等控件，都使用该函数进行初始化绑定"""
        # 加载文件列表
        self.files = sorted(f for f in os.listdir(NPC_DIR) if f.endswith(".txt"))
        self.show_files(self.files)
        self.search_lineEdit.clear()

        # 绑定控件
        self.search_lineEdit.textChanged.connect(self.search)
        self.heroFiles_listWidget.itemClicked.connect(self.click_and_show)
        self.save_file_action.triggered.connect(self.save_file)
        self.reload_file_action.triggered.connect(self.reload_file)
        self.open_file_action.triggered.connect(self.open_file)
        self.reset_file_action.triggered.connect(self.reset_file)
        self.change_selected_item_action.triggered.connect(self.change_selected_item)
        self.set_font_to_Consolas_action.triggered.connect(self.set_font_to_Consolas)
        self.set_font_to_JetBrains_Mono_action.triggered.connect(self.set_font_to_JetBrains_Mono)
        self.enlarge_font_size_action.triggered.connect(self.enlarge_font_size)
        self.reduce_font_size_action.triggered.connect(self.reduce_font_size)
        self.set_light_theme_action.triggered.connect(self.set_light_theme)
        self.set_dark_theme_action.triggered.connect(self.set_dark_theme)
        self.top_action.triggered.connect(self.top)
        self.top_cancel_action.triggered.connect(self.top_cancel)
        self.set_win_size_1600x800_action.triggered.connect(self.set_win_size_1600x800)
        self.set_win_size_1200x600_action.triggered.connect(self.set_win_size_1200x600)

        # 启动项
        self._read_config()
        self.show_content_when_start()
        self.set_font_and_size_when_start()
        self.set_theme_when_start()

    def set_win_size_1600x800(self):
        """设置窗口尺寸1600x800"""
        # todo

    def set_win_size_1200x600(self):
        """设置窗口尺寸1200x600"""
        # todo

    def top(self):
        """置顶窗口"""
        self.setWindowFlag(Qt.WindowStaysOnTopHint, True)
        self.show()

    def top_cancel(self):
        """取消置顶"""
        self.setWindowFlag(Qt.WindowStaysOnTopHint, False)
        self.show()

    def show_files(self, files):
        """展示文件列表"""
        self.heroFiles_listWidget.clear()
        for f in files:
            item = QListWidgetItem(f)
            if os.path.exists(os.path.join(VPK_DIR, f)):
                item.setForeground(QColor("#ff00ff"))
            self.heroFiles_listWidget.addItem(item)

    def search(self, text):
        """模糊搜索"""
        text = text.strip().lower()
        hits = [f for f in self.files if text in f.lower()] if text else self.files
        self.show_files(hits)

    def open_file(self):
        """打开文件"""
        try:
            path = os.path.join(VPK_DIR, self.current_file)
            if not os.path.exists(path):
                path = os.path.join(NPC_DIR, self.current_file)
            self._show_content(path)
            self._change_title(path)

            if os.path.exists(NPP_PATH):
                subprocess.run([NPP_PATH, str(path)])
            elif os.path.exists(NPP_PATH_X86):
                subprocess.run([NPP_PATH_X86, str(path)])
            else:
                os.startfile(path)
            self._print(f'打开文件：{str(path)}')
        except Exception as e:
            self._print(f'异常：{str(e)}')

    def reset_file(self):
        """重置文件，把VPK_DIR目录里的文件名改成文件名1"""
        path = os.path.join(VPK_DIR, self.current_file)
        if not os.path.exists(path):
            return
        # dst = os.path.join(VPK_DIR, f"{self.current_file}_{time.strftime('%Y%m%d_%H%M%S')}")
        dst = os.path.join(VPK_DIR, f"{self.current_file}1")
        if os.path.exists(dst):
            os.remove(dst)
        os.rename(path, dst)
        self._refresh_files()
        self._change_title(os.path.join(NPC_DIR, self.current_file))
        self._print(f'重置文件：{dst}')

    def click_and_show(self, item):
        """点击文件名，展示文件内容"""
        self.current_file = item.text()
        path = os.path.join(VPK_DIR, self.current_file)
        if not os.path.exists(path):
            path = os.path.join(NPC_DIR, self.current_file)
        self._show_content(path)
        self._change_title(path)
        self.config['current_file'] = self.current_file
        self._save_config()
        self._print(f'加载文件：{path}')

    def show_content_when_start(self):
        """启动时，加载展示最近一次的文件内容"""
        self.current_file = self.config.get("current_file")
        path = os.path.join(VPK_DIR, self.current_file)
        if not os.path.exists(path):
            path = os.path.join(NPC_DIR, self.current_file)
        self._show_content(path)
        self._change_title(path)
        self._print(f'加载文件：{path}')

    def set_font_and_size_when_start(self):
        """启动时，设置字体和大小"""
        font, font_size = self.config.get("font"), self.config.get("font_size")
        if font is not None:
            self._set_font(font)
        if font_size is not None:
            self._set_font_size(font_size)

    def set_theme_when_start(self):
        """启动时，设置主题"""
        theme = self.config.get("theme")
        if theme == "dark":
            self.set_dark_theme()

    def save_file(self):
        """把文件内容保存到VPK_DIR目录里，NPC_DIR的文件内容不动"""
        os.makedirs(VPK_DIR, exist_ok=True)
        path = os.path.join(VPK_DIR, self.current_file)
        with open(path, "w", encoding="utf-8") as fh:
            lines = [self.content_listWidget.item(i).text() for i in range(self.content_listWidget.count())]
            fh.write("\n".join(lines))
        self._change_title(path)
        self.config['current_file'] = self.current_file
        self._save_config()
        self._refresh_files()
        self._print(f'保存文件：{path}')

    def reload_file(self):
        """重新加载文件内容"""
        path = os.path.join(VPK_DIR, self.current_file)
        if not os.path.exists(path):
            path = os.path.join(NPC_DIR, self.current_file)
        self._show_content(path)
        self._change_title(path)
        self._print(f'重载文件：{path}')

    def change_selected_item(self):
        """获取content_listWidget的选中行，然后修改好后，再写回该行"""
        try:
            self._read_config()
            sa_value, sp_value, sa_value2, sp_value2  = self.config.get("sa_value"), self.config.get("sp_value"), self.config.get("sa_value2"), self.config.get("sp_value2")
            ab_text = self._get_selected_item()
            has_keyword:bool = any(keyword in ab_text for keyword in KEYWORDS)
            if has_keyword:
                sa_value, sp_value = sa_value2, sp_value2
            new_text = self._change_text(ab_text, sa_value, sp_value)
            self._write_selected_item(new_text)
        except Exception as e:
            self._print(f'异常：{str(e)}')

    def enlarge_font_size(self):
        """放大 content_listWidget 和 content_plainTextEdit 的字体"""
        font = self.content_listWidget.font()
        size = font.pointSize() + 1
        self._set_font_size(size)
        self._print(f'设置字体大小为 {size}')

    def reduce_font_size(self):
        """缩小 content_listWidget 和 content_plainTextEdit 的字体"""
        font = self.content_listWidget.font()
        size = font.pointSize() - 1
        self._set_font_size(size)
        self._print(f'设置字体大小为 {size}')

    def set_font_to_JetBrains_Mono(self):
        """设置 content_listWidget 和 content_plainTextEdit 的字体为：JetBrains Mono"""
        self._set_font('JetBrains Mono')
        self._print('设置字体为 JetBrains Mono')

    def set_font_to_Consolas(self):
        """设置 content_listWidget 和 content_plainTextEdit 的字体为：Consolas"""
        self._set_font('Consolas')
        self._print('设置字体为 Consolas')

    def set_light_theme(self):
        """设置亮色主题"""
        QApplication.instance().setStyleSheet("")

    def set_dark_theme(self):
        """设置暗色主题"""
        QApplication.instance().setStyleSheet(
            "QWidget { background-color: #2d2d2d; color: #e0e0e0; }"
            "QListWidget, QPlainTextEdit, QLineEdit { background-color: #1e1e1e; color: #e0e0e0; }"
            "QListWidget::item:selected { background-color: #375a7f; color: #e6eef5; }"
            "QListWidget::item:hover:!selected { background-color: #3a3a3a; }"
        )

    def _save_win_size_and_position(self):
        """窗口关闭时，把尺寸和位置保存"""
        # todo
        self.config['win_size'] = '1600x800'
        self.config['win_position'] = '0,0'
        self._save_config()

    def _refresh_files(self):
        """刷新文件列表"""
        text = self.search_lineEdit.text()
        self.search(text)

    def _set_font_size(self, font_size):
        """设置字体大小"""
        font_size = int(font_size)
        if font_size < 1: font_size = 1
        font = self.content_listWidget.font()
        font.setPointSize(font_size)
        self.content_listWidget.setFont(font)
        self.content_plainTextEdit.setFont(font)
        self.config['font_size'] = font_size
        self._save_config()

    def _set_font(self, font_type):
        """设置字体"""
        font_type = str(font_type)
        font = QFont(font_type)
        self.content_listWidget.setFont(font)
        self.content_plainTextEdit.setFont(font)
        self.config['font'] = font_type
        self._save_config()

    def _change_text(self, ab_text, sa_value, sp_value):
        """修改选中行"""
        tab, ab_name, _, ab_value, _  = str(ab_text).split('"')
        if ab_name == 'value':
            new_text = MOD1.replace("[TAB]", tab).replace("[AB_NAME]", ab_name).replace("[AB_VALUE]", ab_value).replace("[SA_VALUE]", sa_value).replace("[SP_VALUE]", sp_value)
        else:
            new_text = MOD2.replace("[TAB]", tab).replace("[AB_NAME]", ab_name).replace("[AB_VALUE]", ab_value).replace("[SA_VALUE]", sa_value).replace("[SP_VALUE]", sp_value)
        tab = tab.replace('\t', '\\t')
        self._print(f'tab={tab}, ab_name={ab_name}, ab_value={ab_value}', show_in_bar=False)
        self._print(f'new_text=\n{new_text}', show_in_bar=False)
        return str(new_text)

    def _get_selected_item(self):
        """获取content_listWidget的选中行"""
        item = self.content_listWidget.currentItem()
        text = item.text() if item else ""
        return text

    def _write_selected_item(self, text):
        """写入content_listWidget的选中行"""
        item = self.content_listWidget.currentItem()
        if item:
            item.setText(text)

    def _change_title(self, title):
        """修改窗口标题"""
        self.setWindowTitle(str(title))

    def _show_content(self, path):
        """展示文件内容"""
        with open(path, encoding="utf-8", errors="ignore") as fh:
            lines = fh.read().splitlines()
        self.content_listWidget.clear()
        self.content_listWidget.addItems(lines)
        self.content_plainTextEdit.setPlainText("\n".join(lines))

    def _read_config(self):
        """读取config.json文件"""
        try:
            with open("config.json", encoding="utf-8") as fh:
                self.config = json.load(fh)
        except (FileNotFoundError, json.JSONDecodeError):
            pass

    def _save_config(self):
        """保存config.json文件"""
        with open("config.json", "w", encoding="utf-8") as fh:
            json.dump(self.config, fh, ensure_ascii=False, indent=2)

    def _print(self, msg = '', show_in_bar = True):
        """内部打印和状态栏打印"""
        msg = str(msg)
        print(msg)
        if show_in_bar is True:
            self.statusbar.showMessage(msg)


if __name__ == "__main__":
    app = QApplication([])
    win = Win()
    win.show()
    app.exec()
