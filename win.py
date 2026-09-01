import json
import os
import subprocess
import time

from PySide6.QtCore import QUrl, Qt
from PySide6.QtGui import QColor, QDesktopServices, QFont
from PySide6.QtWidgets import QListWidget, QListWidgetItem

from ui.ui import *

NPP_PATH = 'C:\\Program Files\\Notepad++\\notepad++.exe'
NPP_PATH_X86 = 'C:\\Program Files (x86)\\Notepad++\\notepad++.exe'

KEYWORDS = ['CastPoint', 'Cooldown', 'ManaCost', 'RestoreTime']

ROOT_DIR = os.path.dirname(__file__)
NPC_DIR = os.path.join(ROOT_DIR, "npc", "heroes")
VPK_DIR = os.path.join(ROOT_DIR, "vpk", "pak01_dir", "scripts", "npc", "heroes")
UNIT_DIR = os.path.join(ROOT_DIR, "vpk", "pak01_dir", "scripts", "npc")

MOD1 = '''[TAB]"[AB_NAME]"\t\t"[AB_VALUE]"
[TAB]"special_bonus_shard"\t\t"[SA_VALUE]"
[TAB]"special_bonus_scepter"\t\t"[SP_VALUE]"'''
MOD2 = '''[TAB]"[AB_NAME]"
[TAB]{
[TAB]\t"value"\t\t"[AB_VALUE]"
[TAB]\t"special_bonus_shard"\t\t"[SA_VALUE]"
[TAB]\t"special_bonus_scepter"\t\t"[SP_VALUE]"
[TAB]}'''
MOD3 = '''
[TAB]"AbilityCharges"
[TAB]{
[TAB]\t"value"\t\t"1"
[TAB]\t"special_bonus_shard"\t\t"+1"
[TAB]\t"special_bonus_scepter"\t\t"+1"
[TAB]}
[TAB]"AbilityChargeRestoreTime"
[TAB]{
[TAB]\t"value"\t\t"[AB_VALUE]"
[TAB]\t"special_bonus_shard"\t\t"-25%"
[TAB]\t"special_bonus_scepter"\t\t"-25%"
[TAB]\t"special_bonus_unique_xxx"\t\t"-50%"
[TAB]}
[TAB]"AbilityCooldown"		
[TAB]{
[TAB]\t"value"\t\t"0"
[TAB]\t"special_bonus_shard"\t\t"-25%"
[TAB]\t"special_bonus_scepter"\t\t"-25%"
[TAB]\t"special_bonus_unique_xxx"\t\t"-50%"
[TAB]}
'''


class Win(QMainWindow, Ui_MainWindow):
    def __init__(self):
        super().__init__()
        self.setupUi(self)
        self.charge = ''
        self.undos = []
        self.cuts = []
        self.files = []  # 全部文件名缓存
        self.config = {}
        self.current_file = 'npc_dota_hero_abaddon.txt'
        self.init()

    def init(self):
        """初始化所有的控件绑定，按钮搜索框等控件，都使用该函数进行初始化绑定"""
        # 加载配置
        self._read_config()

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
        self.set_win_size_1800x900_action.triggered.connect(self.set_win_size_1800x900)
        self.tab_action.triggered.connect(self.tab)
        self.back_action.triggered.connect(self.back)
        self.cut_action.triggered.connect(self.cut)
        self.paste_action.triggered.connect(self.paste)
        self.undo_action.triggered.connect(self.undo)
        self.expand_sidebar_action.triggered.connect(self.expand_sidebar)
        self.collapse_sidebar_action.triggered.connect(self.collapse_sidebar)
        self.content_listWidget.setEditTriggers(QListWidget.DoubleClicked)
        self.shortcut_1_action.triggered.connect(lambda: self._change_selected_item("shortcut_1_action"))
        self.shortcut_2_action.triggered.connect(lambda: self._change_selected_item("shortcut_2_action"))
        self.shortcut_3_action.triggered.connect(lambda: self._change_selected_item("shortcut_3_action"))
        self.shortcut_4_action.triggered.connect(lambda: self._change_selected_item("shortcut_4_action"))
        self.shortcut_5_action.triggered.connect(lambda: self._change_selected_item("shortcut_5_action"))
        self.shortcut_6_action.triggered.connect(lambda: self._change_selected_item("shortcut_6_action"))
        self.shortcut_7_action.triggered.connect(lambda: self._change_selected_item("shortcut_7_action"))
        self.shortcut_8_action.triggered.connect(lambda: self._change_selected_item("shortcut_8_action"))
        self.shortcut_9_action.triggered.connect(lambda: self._change_selected_item("shortcut_9_action"))
        self.shortcut_0_action.triggered.connect(lambda: self._change_selected_item("shortcut_0_action"))
        self.shortcut_min_action.triggered.connect(lambda: self._change_selected_item("shortcut_min_action"))
        self.shortcut_equal_action.triggered.connect(lambda: self._change_selected_item("shortcut_equal_action"))
        self.shortcut_add_action.triggered.connect(lambda: self._change_selected_item("shortcut_add_action"))
        self.cooldown_action.triggered.connect(lambda: self._change_selected_item("cooldown_action"))
        self.charge_copy_action.triggered.connect(self.charge_copy)
        self.charge_paste_action.triggered.connect(self.charge_paste)
        self.root_dir_action.triggered.connect(self.root_dir)
        self.heroes_dir_action.triggered.connect(self.heroes_dir)
        self.unit_dir_action.triggered.connect(self.unit_dir)
        
        # 控件改名
        self.shortcut_1_action.setText(self.config.get("shortcut_1_action", ""))
        self.shortcut_2_action.setText(self.config.get("shortcut_2_action", ""))
        self.shortcut_3_action.setText(self.config.get("shortcut_3_action", ""))
        self.shortcut_4_action.setText(self.config.get("shortcut_4_action", ""))
        self.shortcut_5_action.setText(self.config.get("shortcut_5_action", ""))
        self.shortcut_6_action.setText(self.config.get("shortcut_6_action", ""))
        self.shortcut_7_action.setText(self.config.get("shortcut_7_action", ""))
        self.shortcut_8_action.setText(self.config.get("shortcut_8_action", ""))
        self.shortcut_9_action.setText(self.config.get("shortcut_9_action", ""))
        self.shortcut_0_action.setText(self.config.get("shortcut_0_action", ""))
        self.shortcut_min_action.setText(self.config.get("shortcut_min_action", ""))
        self.shortcut_equal_action.setText(self.config.get("shortcut_equal_action", ""))
        self.shortcut_add_action.setText(self.config.get("shortcut_add_action", ""))

        # 启动项
        self.show_content_when_start()
        self.set_font_and_size_when_start()
        self.set_theme_when_start()
        self.set_win_size_and_position_when_start()
        self.set_sidebar_when_start()

    def root_dir(self):
        """打开根目录"""
        os.startfile(ROOT_DIR)

    def heroes_dir(self):
        """打开heroes目录"""
        os.startfile(VPK_DIR)

    def unit_dir(self):
        """打开unit目录"""
        os.startfile(UNIT_DIR)

    def charge_copy(self):
        """充能复制"""
        ab_text = self._get_selected_item()
        tab, ab_name, _, ab_value, _  = str(ab_text).split('"')
        charge_text = MOD3.replace("[TAB]", tab).replace("[AB_VALUE]", ab_value)
        self._print(f'tab={tab}, ab_name={ab_name}, ab_value={ab_value}', show_in_bar=False)
        self._print(f'charge_text=\n{charge_text}', show_in_bar=False)
        self.charge = str(charge_text)
        self._print(f'充能复制，ab_value={ab_value}')

    def charge_paste(self):
        """充能粘贴"""
        if self.charge == '':
            return
        text = self._get_selected_item()
        new_text = text + '\n' + self.charge
        self._write_selected_item(new_text)
        self._print(f'充能粘贴')
        self.charge = ''

    def set_sidebar_when_start(self):
        """启动时，展开或收起侧栏"""
        sidebar_expand = self.config.get('sidebar_expand')
        if sidebar_expand is True:
            self.expand_sidebar()
        else:
            self.collapse_sidebar()

    def expand_sidebar(self):
        """侧栏宽度设置为255"""
        self.sidebar_frame.setFixedWidth(255)
        self.config['sidebar_expand'] = True

    def collapse_sidebar(self):
        """侧栏宽度设置为5"""
        self.sidebar_frame.setFixedWidth(5)
        self.config['sidebar_expand'] = False

    def undo(self):
        """撤回"""
        if self.undos == []:
            return
        text = self._get_selected_item()
        new_text = self.undos[-1]
        self._write_selected_item(new_text)
        self._print(f'撤回：{len(self.undos)}')
        self.undos = self.undos[:-1]

    def cut(self):
        """剪切"""
        text = self._get_selected_item()
        tab_text = self._tab_text(text)
        self.cuts.append(tab_text)
        self._write_selected_item('')
        self._print(f'剪切：{len(self.cuts)}')

    def paste(self):
        """粘贴"""
        if self.cuts == []:
            return
        text = self._get_selected_item()
        new_text = text + '\n' + '\n'.join(self.cuts)
        self._write_selected_item(new_text)
        self._print(f'粘贴：{len(self.cuts)}')
        self.cuts = []

    def tab(self):
        """缩进"""
        try:
            text = self._get_selected_item()
            texts = ['\t'+ i  for i in text.split('\n')]
            tab_text = '\n'.join(texts)
            self._write_selected_item(tab_text)
        except Exception as e:
            self._print(f'异常：{str(e)}', show_in_bar=False)

    def back(self):
        """退格"""
        try:
            text = self._get_selected_item()
            texts = []
            for line in text.split('\n'):
                if line.startswith('\t'):
                    line = line[1:]
                texts.append(line)
            new_text = '\n'.join(texts)
            self._write_selected_item(new_text)
        except Exception as e:
            self._print(f'异常：{str(e)}', show_in_bar=False)

    def closeEvent(self, event):
        """重写窗口关闭事件"""
        self._save_win_size_and_position_when_win_close()

    def set_win_size_and_position_when_start(self):
        """启动时，设置窗口尺寸和位置"""
        try:
            win_size, win_position = self.config.get('win_size'), self.config.get('win_position')
            w, h = win_size.split('x')
            x, y = win_position.split(',')
            x, y, w, h = int(x), int(y), int(w), int(h)
            self.setGeometry(x, y, w, h)
            self._print(f'设置窗口位置：{x, y}，窗口尺寸：{w, h}', show_in_bar=False)
        except Exception as e:
            self._print(f'异常：{str(e)}', show_in_bar=False)
        
    def set_win_size_1600x800(self):
        """设置窗口尺寸1600x800"""
        geo = self.geometry()
        x, y, w, h = int(geo.x()), int(geo.y()), 1600, 800
        self.setGeometry(x, y, w, h)
        self._print('设置窗口尺寸 1600x800')

    def set_win_size_1800x900(self):
        """设置窗口尺寸1800x900"""
        geo = self.geometry()
        x, y, w, h = int(geo.x()), int(geo.y()), 1800, 900
        self.setGeometry(x, y, w, h)
        self._print('设置窗口尺寸 1800x900')

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
        dst = os.path.join(VPK_DIR, f"{self.current_file}1")
        if os.path.exists(dst):
            os.remove(dst)
        os.rename(path, dst)
        self._refresh_files()
        self._change_title(os.path.join(NPC_DIR, self.current_file))
        self._print(f'重置文件：{dst}')
        self.reload_file()

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

    def _change_selected_item(self, action_name):
        """获取content_listWidget的选中行，然后修改好后，再写回该行"""
        try:
            self._read_config()
            action_value = self.config.get(action_name, "=666")
            ab_text = self._get_selected_item()
            new_text = self._change_text(ab_text, action_value, action_value)
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

    def _tab_text(self, text):
        """加缩进"""
        texts = ['\t'+ i  for i in text.split('\n')]
        tab_text = '\n'.join(texts)
        return tab_text

    def _save_win_size_and_position_when_win_close(self):
        """窗口关闭时，把尺寸和位置保存"""
        geo = self.geometry()
        x, y, w, h = int(geo.x()), int(geo.y()), int(geo.width()), int(geo.height())
        self.config['win_position'] = f'{x},{y}'
        self.config['win_size'] = f'{w}x{h}'
        self._print(f'保存窗口位置：{x, y}，窗口尺寸：{w, h}', show_in_bar=False)
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
        self.undos.append(ab_text)
        self._print(f'tab={tab}, ab_name={ab_name}, ab_value={ab_value}', show_in_bar=False)
        self._print(f'new_text=\n{new_text}', show_in_bar=False)
        self._print(f'self.undos={self.undos}', show_in_bar=False)
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
        for line in lines:
            item = QListWidgetItem(line)
            item.setFlags(item.flags() | Qt.ItemIsEditable)
            self.content_listWidget.addItem(item)
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
