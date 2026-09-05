import json
import os
import subprocess
import time
import shutil
from datetime import datetime

from PySide6.QtCore import QEvent, Qt
from PySide6.QtGui import QColor, QFont, QTextCursor
from PySide6.QtWidgets import QListWidget, QListWidgetItem

from ui.ui import *

COLOR_REF = {'dark': '#c678dd', 'light': '#ff00ff'}

NPP_PATH = 'C:\\Program Files\\Notepad++\\notepad++.exe'
NPP_PATH_X86 = 'C:\\Program Files (x86)\\Notepad++\\notepad++.exe'

STEAM_DIRS = ['C:\\Program Files (x86)\\Steam', 
              'C:\\Program Files\\Steam', 
              'D:\\Program Files (x86)\\Steam', 
              'D:\\Program Files\\Steam', 
              'D:\\APP\\Steam',
              'E:\\GAME'] # 常用STEAM路径

KEYWORDS = ['CastPoint', 'Cooldown', 'ManaCost', 'RestoreTime']
KEYSYMBOLS = ['+', '-', '=']

ROOT_DIR = os.path.dirname(__file__)

VPK_DIR = os.path.join(ROOT_DIR, "vpk")
PAK_DIR = os.path.join(VPK_DIR, "pak01_dir")

VPK_EXE = os.path.join(VPK_DIR, "vpk.exe")
VPK_FILE = os.path.join(VPK_DIR, "pak01_dir.vpk")

NPC_DIR = os.path.join(ROOT_DIR, "npc")
NPC_DIR2 = os.path.join(VPK_DIR, "pak01_dir", "scripts", "npc")
HERO_DIR = os.path.join(NPC_DIR, "heroes")
HERO_DIR2 = os.path.join(NPC_DIR2, "heroes")

ITEM_FILE = os.path.join(NPC_DIR, "items.txt")
ITEM_FILE2 = os.path.join(NPC_DIR2, "items.txt")

NEURAL_FILE = os.path.join(NPC_DIR, "neutral_items.txt")
NEURAL_FILE2 = os.path.join(NPC_DIR2, "neutral_items.txt")

UNIT_FILE = os.path.join(NPC_DIR, "npc_units.txt")
UNIT_FILE2 = os.path.join(NPC_DIR2, "npc_units.txt")

MOD1 = '''[TAB]"[AB_NAME]"\t\t"[AB_VALUE]"
[TAB]"special_bonus_shard"\t\t"[SA_VALUE]"
[TAB]"special_bonus_scepter"\t\t"[SP_VALUE]"'''

MOD2 = '''[TAB]"[AB_NAME]"
[TAB]{
[TAB]\t"value"\t\t"[AB_VALUE]"
[TAB]\t"special_bonus_shard"\t\t"[SA_VALUE]"
[TAB]\t"special_bonus_scepter"\t\t"[SP_VALUE]"
[TAB]}'''

MOD3 = '''[TAB]"value"\t\t"0"
[TAB]"special_bonus_shard"\t\t"[AB_VALUE]"
[TAB]"special_bonus_scepter"\t\t"[AB_VALUE]"'''

MOD4 = '''[TAB]"value"\t\t"0"
[TAB]"special_bonus_shard"\t\t"[AB_VALUE]"
[TAB]"special_bonus_scepter"\t\t"[AB_VALUE]"
[TAB]"[AB_NAME]"\t\t"[AB_VALUE]"'''

MOD5 = '''[TAB]"AbilityCharges"
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
[TAB]}
[TAB]"AbilityCooldown"		
[TAB]{
[TAB]\t"value"\t\t"0"
[TAB]\t"special_bonus_shard"\t\t"-25%"
[TAB]\t"special_bonus_scepter"\t\t"-25%"
[TAB]}'''

MOD6 = '''[TAB]"AbilityCharges"
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
[TAB]\t"[UN_NAME]"\t\t"[UN_VALUE]"
[TAB]}
[TAB]"AbilityCooldown"		
[TAB]{
[TAB]\t"value"\t\t"0"
[TAB]\t"special_bonus_shard"\t\t"-25%"
[TAB]\t"special_bonus_scepter"\t\t"-25%"
[TAB]\t"[UN_NAME]"\t\t"[UN_VALUE]"
[TAB]}'''


class Win(QMainWindow, Ui_MainWindow):
    def __init__(self):
        super().__init__()
        self.setupUi(self)
        self.steam_dir = 'C:\\Program Files (x86)\\Steam'
        self.selected_row = 0
        self.addrows = []
        self.theme = 'dark'
        self.charge_tab = ''
        self.charge_ab_value = ''
        self.charge_un_name = ''
        self.charge_un_value = ''
        self.undos = []
        self.cuts = []
        self.files = []  # 全部文件名缓存
        self.config = {}
        self.current_file = 'npc_dota_hero_abaddon.txt'
        self.init()

    @property
    def dota2_dir(self):
        """DOTA2路径"""
        return os.path.join(self.steam_dir, "steamapps", "common", "dota 2 beta")

    @property
    def game_dir(self):
        """游戏路径"""
        return os.path.join(self.dota2_dir, "game")
    
    @property
    def mod_dir(self):
        """mod文件夹路径"""
        return os.path.join(self.game_dir, "mod")

    @property
    def mod_file(self):
        """mod文件路径"""
        return os.path.join(self.mod_dir, "pak01_dir.vpk")

    @property
    def vscripts_dir(self):
        """vscripts路径"""
        return os.path.join(self.game_dir, "dota", "scripts", "vscripts")

    @property
    def tinkering_dir(self):
        """BOT脚本tinkering路径"""
        return os.path.join(self.steam_dir, "steamapps", "workshop", "content", "570", "3139791706")

    @property
    def open_hyper_ai_dir(self):
        """BOT脚本open_hyper_ai路径"""
        return os.path.join(self.steam_dir, "steamapps", "workshop", "content", "570", "3246316298")

    def init(self):
        """初始化所有的控件绑定，按钮搜索框等控件，都使用该函数进行初始化绑定"""
        # 加载配置
        self._read_config()

        # 加载文件列表
        self.files = sorted(f for f in os.listdir(HERO_DIR) if f.endswith(".txt"))
        self.show_files(self.files)
        self.search_lineEdit.clear()

        # 绑定控件
        self.search_lineEdit.textChanged.connect(self.search)
        self.heroFiles_listWidget.itemClicked.connect(self.click_and_show)
        self.content_listWidget.itemClicked.connect(self._remember_row) # 记忆行号
        self.save_file_line_action.triggered.connect(self.save_file_line)
        self.save_file_text_action.triggered.connect(self.save_file_text)
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
        self.content_listWidget.setEditTriggers(QListWidget.DoubleClicked) # 行编辑器双击编辑
        self.content_listWidget.setSelectionMode(QListWidget.ExtendedSelection) # 行视图支持多选
        self.content_plainTextEdit.installEventFilter(self) # 文本编辑器的TAB/Shift+TAB缩进
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
        self.shortcut_ctrl_1_action.triggered.connect(lambda: self._change_selected_item("shortcut_ctrl_1_action"))
        self.shortcut_ctrl_2_action.triggered.connect(lambda: self._change_selected_item("shortcut_ctrl_2_action"))
        self.shortcut_ctrl_3_action.triggered.connect(lambda: self._change_selected_item("shortcut_ctrl_3_action"))
        self.shortcut_ctrl_4_action.triggered.connect(lambda: self._change_selected_item("shortcut_ctrl_4_action"))
        self.shortcut_ctrl_5_action.triggered.connect(lambda: self._change_selected_item("shortcut_ctrl_5_action"))
        self.shortcut_ctrl_6_action.triggered.connect(lambda: self._change_selected_item("shortcut_ctrl_6_action"))
        self.shortcut_ctrl_7_action.triggered.connect(lambda: self._change_selected_item("shortcut_ctrl_7_action"))
        self.shortcut_ctrl_8_action.triggered.connect(lambda: self._change_selected_item("shortcut_ctrl_8_action"))
        self.shortcut_ctrl_9_action.triggered.connect(lambda: self._change_selected_item("shortcut_ctrl_9_action"))
        self.shortcut_ctrl_0_action.triggered.connect(lambda: self._change_selected_item("shortcut_ctrl_0_action"))
        self.replace_min_action.triggered.connect(self.replace_min)
        self.replace_equal_action.triggered.connect(self.replace_equal)
        self.replace_add_action.triggered.connect(self.replace_add)
        self.cooldown_action.triggered.connect(lambda: self._change_selected_item("cooldown_action"))
        self.charge_copy_action.triggered.connect(self.charge_copy)
        self.charge_un_copy_action.triggered.connect(self.charge_un_copy)
        self.charge_paste_action.triggered.connect(self.charge_paste)
        self.root_dir_action.triggered.connect(self.root_dir)
        self.heroes_dir_action.triggered.connect(self.heroes_dir)
        self.unit_dir_action.triggered.connect(self.unit_dir)
        self.delete_selected_item_action.triggered.connect(self.delete_selected_item)
        self.generate_vpk_action.triggered.connect(self.generate_vpk)
        self.generate_vpk_and_move_action.triggered.connect(self.generate_vpk_and_move)
        self.game_dir_action.triggered.connect(self.go_to_game_dir)
        self.change_gold_and_xp_action.triggered.connect(self.change_gold_and_xp)
        self.change_items_action.triggered.connect(self.change_items)
        self.change_neutral_items_action.triggered.connect(self.change_neutral_items)
        self.vscripts_dir_action.triggered.connect(self.go_to_vscripts_dir)
        self.tinkering_dir_action.triggered.connect(self.go_to_tinkering_dir)
        self.open_hyper_ai_dir_action.triggered.connect(self.go_to_open_hyper_ai_dir)

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
        self.shortcut_ctrl_1_action.setText(self.config.get("shortcut_ctrl_1_action", ""))
        self.shortcut_ctrl_2_action.setText(self.config.get("shortcut_ctrl_2_action", ""))
        self.shortcut_ctrl_3_action.setText(self.config.get("shortcut_ctrl_3_action", ""))
        self.shortcut_ctrl_4_action.setText(self.config.get("shortcut_ctrl_4_action", ""))
        self.shortcut_ctrl_5_action.setText(self.config.get("shortcut_ctrl_5_action", ""))
        self.shortcut_ctrl_6_action.setText(self.config.get("shortcut_ctrl_6_action", ""))
        self.shortcut_ctrl_7_action.setText(self.config.get("shortcut_ctrl_7_action", ""))
        self.shortcut_ctrl_8_action.setText(self.config.get("shortcut_ctrl_8_action", ""))
        self.shortcut_ctrl_9_action.setText(self.config.get("shortcut_ctrl_9_action", ""))
        self.shortcut_ctrl_0_action.setText(self.config.get("shortcut_ctrl_0_action", ""))

        # 启动项
        self.show_content_when_start()
        self.set_font_and_size_when_start()
        self.set_theme_when_start()
        self.set_win_size_and_position_when_start()
        self.set_sidebar_when_start()
        self.find_steam_dir_when_start()
    
    def go_to_vscripts_dir(self):
        """打开vscripts目录"""
        if not os.path.exists(self.vscripts_dir):
            self._print(f'未找到vscripts目录:{self.vscripts_dir}')
            return
        os.startfile(self.vscripts_dir)
        self._print(f'打开vscripts目录:{self.vscripts_dir}')

    def go_to_tinkering_dir(self):
        """打开tinkering脚本目录"""
        if not os.path.exists(self.tinkering_dir):
            self._print(f'未找到tinkering脚本目录:{self.tinkering_dir}')
            return
        os.startfile(self.tinkering_dir)
        self._print(f'打开tinkering脚本目录:{self.tinkering_dir}')

    def go_to_open_hyper_ai_dir(self):
        """打开open_hyper_ai脚本目录"""
        if not os.path.exists(self.open_hyper_ai_dir):
            self._print(f'未找到open_hyper_ai脚本目录:{self.open_hyper_ai_dir}')
            return
        os.startfile(self.open_hyper_ai_dir)
        self._print(f'打开open_hyper_ai脚本目录:{self.open_hyper_ai_dir}')

    def change_gold_and_xp(self):
        """修改单位数据：金币和经验"""
        try:
            self._print(f'修改单位数据：金币和经验。。。', show_in_bar=False)
            self._read_config()
            xp_gold_mul = self.config.get('xp_gold_mul')
            if xp_gold_mul is None:
                self._print('配置文件：没有 xp_gold_mul 配置项，创建一个 xp_gold_mul = 2')
                xp_gold_mul = 2
                self.config['xp_gold_mul'] = xp_gold_mul
                self._save_config()
                return
            with open(UNIT_FILE, 'r') as f:
                lines = f.read().splitlines()
            lines2 = []
            for i, line in enumerate(lines, 1):
                if 'BountyGoldMin' in line or 'BountyGoldMax' in line or 'BountyXP' in line:
                    _, xp_gold, _, value, _ = line.split('"')
                    value2 = str(int(float(value) * float(xp_gold_mul)))
                    if value2 != value:
                        line = line.replace(value, value2)
                        self._print(f'修改单位数据：{i:5}行：{xp_gold} = {value} -> {value2}', show_in_bar=False)
                lines2.append(line)
            with open(UNIT_FILE2, 'w') as f:
                f.write('\n'.join(lines2))
            self._print(f'修改单位数据：金币和经验成功：{UNIT_FILE2}')
        except Exception as e:
            self._print(f'修改单位数据：金币和经验失败，{e}')
    
    def change_items(self):
        """修改商店物品：冷却时间"""
        pass

    def change_neutral_items(self):
        """修改中立物品数据：冷却时间"""
        try:
            self._read_config()
            times = self.config.get('neutral_items')
            if times is None:
                self.config['neutral_items'] = ["0:00", "5:00", "15:00", "25:00", "35:00", "40:00"]
                self._save_config()
                self._print(f'修配置文件：没有 neutral_items 配置项，创建一个 neutral_items = ["0:00", "5:00", "15:00", "25:00", "35:00", "40:00"]')
                return
            self._print(f'修改中立物品数据：冷却时间。。。', show_in_bar=False)
            with open(NEURAL_FILE, 'r') as f:
                lines = f.read().splitlines()
            lv = 1
            lines2 = []
            for i, line in enumerate(lines, 1):
                if 'madstone_no_limit_time' in line:
                    _, _, _, time, _ = line.split('"')
                    time2 = times[-1]
                    line = line.replace(time, time2)
                    self._print(f'修改中立物品数据：冷却时间：{i:5}行：5级中立物品(重新选择)：{time} -> {time2}', show_in_bar=False)
                elif 'start_time' in line:
                    _, _, _, time, _ = line.split('"')
                    time2 = times[lv-1]
                    line = line.replace(time, time2)
                    self._print(f'修改中立物品数据：冷却时间：{i:5}行：{lv}级中立物品：{time} -> {time2}', show_in_bar=False)
                    lv += 1
                lines2.append(line)
            with open(NEURAL_FILE2, 'w') as f:
                f.write('\n'.join(lines2))
            self._print(f'修改中立物品数据：冷却时间：{NEURAL_FILE2}')
        except Exception as e:
            self._print(f'修改中立物品数据：冷却时间，{e}')

    def find_steam_dir_when_start(self):
        """启动时，自动寻找STEAM文件夹，优先读配置，不行再自动寻找"""
        steam_dir = self.config.get('steam_dir')
        # 如果没有这个配置项，就创建一个
        if steam_dir is None: 
            self._print(f'配置文件：没有 steam_dir 配置项，创建一个')
            steam_dir = ''
            self.config['steam_dir'] = steam_dir
            self._save_config()
        # 读配置
        if steam_dir != '':
            if os.path.exists(steam_dir):
                self._print(f'配置文件：steam_dir 存在，steam_dir={steam_dir}')
                self.steam_dir = steam_dir
                self.config['steam_dir'] = steam_dir
                self._save_config()
                return
        # 自动寻找
        for steam_dir in STEAM_DIRS:
            if os.path.exists(steam_dir):
                self._print(f'自动寻找：steam_dir 存在，steam_dir={steam_dir}')
                self.steam_dir = steam_dir
                self.config['steam_dir'] = steam_dir
                self._save_config()
                return
        # 都没有就打印
        self._print(f'未能找到：steam_dir，默认使用{self.steam_dir}')

    def generate_vpk(self):
        """生成vpk"""
        try:
            if not os.path.exists(VPK_EXE):
                print(VPK_EXE)
                self._print(f'vpk.exe 不存在，请把 vpk.exe 放在 {VPK_DIR} 目录下')
                return
            subprocess.run([VPK_EXE, PAK_DIR]) # 指令：vpk.exe pak01_dir
            if os.path.exists(VPK_FILE):
                self._print(f'生成 vpk 成功，VPK_FILE={VPK_FILE}')
            else:
                self._print(f'生成 vpk 失败，VPK_EXE={VPK_EXE}，PAK_DIR={PAK_DIR}')
        except Exception as e:
            self._print(f'异常：{str(e)}')

    def generate_vpk_and_move(self):
        """生成vpk并移动到游戏目录MOD文件夹"""
        self.generate_vpk()
        if not os.path.exists(VPK_FILE):
            self._print(f'VPK_FILE 不存在，VPK_FILE={VPK_FILE}')
            return
        if not os.path.exists(self.game_dir):
            self._print(f'self.game_dir 不存在，self.game_dir={self.game_dir}')
            return
        if not os.path.exists(self.mod_dir):
            self._print(f'self.mod_dir 不存在，新建一个，self.game_dir={self.game_dir}')
            os.makedirs(self.mod_dir, exist_ok=True)
        shutil.move(VPK_FILE, self.mod_file) # 移动至目标路径，覆盖
        self._print(f'生成并移动，MOD_FILE={self.mod_file}')

    def delete_selected_item(self):
        """删除所有选中行"""
        rows = self._selected_rows()
        for row in reversed(rows):
            self.content_listWidget.takeItem(row)
        if rows:
            self._print(f'删除行：{len(rows)} 行')

    def replace_min(self):
        """替换为减号"""
        text = self._get_selected_item()
        for symbol in KEYSYMBOLS:
            if symbol in text:
                text = text.replace(symbol, '-')
                self._write_selected_item(text)
                return

    def replace_equal(self):
        """替换为等号"""
        text = self._get_selected_item()
        for symbol in KEYSYMBOLS:
            if symbol in text:
                text = text.replace(symbol, '=')
                self._write_selected_item(text)
                return

    def replace_add(self):
        """替换为加号"""
        text = self._get_selected_item()
        for symbol in KEYSYMBOLS:
            if symbol in text:
                text = text.replace(symbol, '+')
                self._write_selected_item(text)
                return

    def root_dir(self):
        """打开根目录"""
        os.startfile(ROOT_DIR)
        self._print(f'打开根目录:{ROOT_DIR}')

    def heroes_dir(self):
        """打开英雄目录"""
        os.startfile(HERO_DIR2)
        self._print(f'打开英雄目录:{HERO_DIR2}')

    def unit_dir(self):
        """打开单位目录"""
        os.startfile(NPC_DIR2)
        self._print(f'打开单位目录:{NPC_DIR2}')

    def go_to_game_dir(self):
        """打开游戏目录"""
        if os.path.exists(self.game_dir):
            os.startfile(self.game_dir)
            self._print(f'打开游戏目录:{self.game_dir}')
        else:
            self._print(f'游戏目录不存在:{self.game_dir}')

    def charge_copy(self):
        """充能复制"""
        ab_text = self._get_selected_item()
        charge_tab, ab_name, _, charge_ab_value, _  = str(ab_text).split('"')
        if ab_name == 'value':
            charge_tab = charge_tab[:-1]    # 减少一层缩进
        self.charge_tab = charge_tab
        self.charge_ab_value = charge_ab_value
        self._print(f'charge_tab={charge_tab}, charge_ab_value={charge_ab_value}', show_in_bar=False)
        self._print(f'充能复制，charge_ab_value={charge_ab_value}')

    def charge_un_copy(self):
        """充能复制(unique)"""
        ab_text = self._get_selected_item()
        _, un_name, _, un_value, _  = str(ab_text).split('"')
        self.charge_un_name = un_name
        self.charge_un_value = un_value
        self._print(f'un_name={un_name}, un_value={un_value}', show_in_bar=False)
        self._print(f'充能复制(unique)，un_name={un_name}, un_value={un_value}')

    def charge_paste(self):
        """充能粘贴"""
        if self.charge_ab_value == '':
            return
        text = self._get_selected_item()
        if self.charge_un_value != '':
            mod_text = MOD6.replace("[TAB]", self.charge_tab).replace("[AB_VALUE]", self.charge_ab_value).replace("[UN_NAME]", self.charge_un_name).replace("[UN_VALUE]", self.charge_un_value)
        else:
            mod_text = MOD5.replace("[TAB]", self.charge_tab).replace("[AB_VALUE]", self.charge_ab_value)
        new_text = text + '\n' + mod_text
        self._write_selected_item(new_text)   
        self._print(f'充能粘贴')
        self.charge_tab = ''
        self.charge_ab_value = ''
        self.charge_un_name = ''
        self.charge_un_value = ''

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
        self.addrows = self.addrows[:-1]

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
        """缩进所有选中行"""
        for item in self._selected_items():
            self._set_item_text(item, '\t' + item.text())

    def back(self):
        """反缩进所有选中行"""
        for item in self._selected_items():
            t = item.text()
            self._set_item_text(item, t[1:] if t.startswith('\t') else t)

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
            if os.path.exists(os.path.join(HERO_DIR2, f)):
                color = self._get_color(self.theme)
                item.setForeground(QColor(color))
            self.heroFiles_listWidget.addItem(item)

    def search(self, text):
        """模糊搜索"""
        text = text.strip().lower()
        hits = [f for f in self.files if text in f.lower()] if text else self.files
        self.show_files(hits)

    def open_file(self):
        """打开文件"""
        try:
            self.save_file_line()
            path = os.path.join(HERO_DIR2, self.current_file)
            if not os.path.exists(path):
                path = os.path.join(HERO_DIR, self.current_file)
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
        path = os.path.join(HERO_DIR2, self.current_file)
        if not os.path.exists(path):
            return
        dst = os.path.join(HERO_DIR2, f"{self.current_file}1")
        if os.path.exists(dst):
            os.remove(dst)
        os.rename(path, dst)
        self._change_title(os.path.join(HERO_DIR, self.current_file))
        self._print(f'重置文件：{dst}')
        self.reload_file()

    def click_and_show(self, item):
        """点击文件名，展示文件内容"""
        self.current_file = item.text()
        path = os.path.join(HERO_DIR2, self.current_file)
        if not os.path.exists(path):
            path = os.path.join(HERO_DIR, self.current_file)
        self._show_content(path)
        self._change_title(path)
        self.config['current_file'] = self.current_file
        self._save_config()
        self._print(f'加载文件：{path}')

    def show_content_when_start(self):
        """启动时，加载展示最近一次的文件内容"""
        self.current_file = self.config.get("current_file")
        path = os.path.join(HERO_DIR2, self.current_file)
        if not os.path.exists(path):
            path = os.path.join(HERO_DIR, self.current_file)
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
        else:
            self.set_light_theme()

    def save_file_line(self):
        """把行视图的文件内容保存到VPK_DIR目录里，NPC_DIR的文件内容不动"""
        os.makedirs(HERO_DIR2, exist_ok=True)
        path = os.path.join(HERO_DIR2, self.current_file)
        with open(path, "w", encoding="utf-8") as fh:
            lines = [self.content_listWidget.item(i).text() for i in range(self.content_listWidget.count())]
            fh.write("\n".join(lines))
        self._change_title(path)
        self.config['current_file'] = self.current_file
        self._save_config()
        self._refresh_files()
        self._print(f'保存文件：{path}')

    def save_file_text(self):
        """把文本视图的文件内容保存到VPK_DIR目录里，NPC_DIR的文件内容不动"""
        os.makedirs(HERO_DIR2, exist_ok=True)
        path = os.path.join(HERO_DIR2, self.current_file)
        with open(path, "w", encoding="utf-8") as fh:
            text = self.content_plainTextEdit.toPlainText()
            fh.write(text)
        self._change_title(path)
        self.config['current_file'] = self.current_file
        self._save_config()
        self._refresh_files()
        self._print(f'保存文件：{path}')

    def reload_file(self):
        """重新加载文件内容"""
        path = os.path.join(HERO_DIR2, self.current_file)
        if not os.path.exists(path):
            path = os.path.join(HERO_DIR, self.current_file)
        self._show_content(path)
        self._change_title(path)
        self._refresh_files()
        self._go_to_row()
        self._print(f'重载文件：{path}')

    def change_selected_item(self):
        """对所有选中行：读取配置后修改并写回"""
        try:
            self._read_config()
            sa_value, sp_value, sa_value2, sp_value2 = self.config.get("sa_value"), self.config.get("sp_value"), self.config.get("sa_value2"), self.config.get("sp_value2")
            for item in self._selected_items():
                ab_text = item.text()
                sa, sp = (sa_value2, sp_value2) if any(k in ab_text for k in KEYWORDS) else (sa_value, sp_value)
                self._set_item_text(item, self._change_text(ab_text, sa, sp))
        except Exception as e:
            self._print(f'异常：{str(e)}')

    def _change_selected_item(self, action_name):
        """对所有选中行：用指定动作值修改并写回"""
        try:
            self._read_config()
            action_value = self.config.get(action_name, "=666")
            for item in self._selected_items():
                new_text = self._change_text(item.text(), action_value, action_value) # 修改文本
                self._set_item_text(item, new_text) # 写回修改后的文本
                self.addrows.append(len(new_text.split('\n')) - 1 ) # 记录新增行数
            # 记录动作次数
            if self.config.get('shortcut_count') is None:
                self.config['shortcut_count'] = {}
            if self.config.get('shortcut_count').get(action_name) is None:
                self.config['shortcut_count'][action_name] = 0
            self.config['shortcut_count'][action_name] += 1
            self._save_config()
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
        self.theme = 'light'
        self._print('设置主题为亮色', show_in_bar=False)

    def set_dark_theme(self):
        """设置暗色主题"""
        QApplication.instance().setStyleSheet(
            "QWidget { background-color: #21252b; color: #e0e0e0; }"
            "QListWidget, QPlainTextEdit, QLineEdit { background-color: #282c34; color: #98c379; }"
            "QListWidget::item:selected { background-color: #44474e; color: #98c379; }"
            "QListWidget::item:hover:!selected { background-color: #44474e; }"
        )
        self.theme = 'dark'
        self._print('设置主题为暗色', show_in_bar=False)

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
        elif ab_name == 'special_bonus_shard' or ab_name == 'special_bonus_scepter':
            if '+' not in ab_value:  ab_value = '+' + ab_value
            new_text = MOD3.replace("[TAB]", tab).replace("[AB_VALUE]", ab_value)
        elif 'special_bonus_unique' in ab_name:
            if '+' not in ab_value:  ab_value = '+' + ab_value
            new_text = MOD4.replace("[TAB]", tab).replace("[AB_NAME]", ab_name).replace("[AB_VALUE]", ab_value)
        else:
            new_text = MOD2.replace("[TAB]", tab).replace("[AB_NAME]", ab_name).replace("[AB_VALUE]", ab_value).replace("[SA_VALUE]", sa_value).replace("[SP_VALUE]", sp_value)
        tab = tab.replace('\t', '\\t')
        self.undos.append(ab_text) # 记录撤回
        self.addrows.append(len(new_text.split('\n')) - 1 ) # 记录新增行数
        self._print(f'tab={tab}, ab_name={ab_name}, ab_value={ab_value}', show_in_bar=False)
        self._print(f'new_text=\n{new_text}', show_in_bar=False)
        # self._print(f'self.undos={self.undos}', show_in_bar=False)
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
            color = self._get_color(self.theme)
            item.setForeground(QColor(color))

    def _get_color(self, theme):
        """根据主题获取颜色"""
        return QColor(COLOR_REF.get(theme, '#ff00ff'))

    def _selected_rows(self):
        """返回选中行的行号（升序）"""
        return sorted(i.row() for i in self.content_listWidget.selectedIndexes())

    def _selected_items(self):
        """返回选中行对应的 item（按行号升序）"""
        return [self.content_listWidget.item(r) for r in self._selected_rows()]

    def _set_item_text(self, item, text):
        """写入某 item 的文本并刷新主题色"""
        item.setText(text)
        item.setForeground(self._get_color(self.theme))

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

    def _remember_row(self, item):
        """content_listWidget 单击时记忆行号"""
        self.selected_row = self.content_listWidget.row(item)

    def _go_to_row(self):
        """跳转到记忆行"""
        row = self.selected_row + sum(self.addrows)
        if row < 0 or row >= self.content_listWidget.count():
            return
        item = self.content_listWidget.item(self.selected_row)
        self.content_listWidget.setCurrentItem(item)
        self.content_listWidget.scrollToItem(item, QListWidget.PositionAtCenter)

    def eventFilter(self, obj, event):
        """content_plainTextEdit 的 TAB/Shift+TAB 缩进所选多行"""
        if obj is self.content_plainTextEdit and event.type() == QEvent.Type.KeyPress:
            if event.key() in (Qt.Key_Tab, Qt.Key_Backtab):
                self._indent_selection(event.modifiers() & Qt.ShiftModifier)
                return True
        return super().eventFilter(obj, event)

    def _indent_selection(self, dedent):
        """缩进/反缩进文本编辑器中选中的多行"""
        te = self.content_plainTextEdit
        cursor = te.textCursor()
        if not cursor.hasSelection():
            return
        doc = te.document()
        first = doc.findBlock(cursor.selectionStart())
        last = doc.findBlock(cursor.selectionEnd())
        cursor.beginEditBlock()
        b = first
        while b.isValid():
            c = QTextCursor(b)
            if dedent:
                t = b.text()
                if t[:1] == '\t':
                    c.deleteChar()
                elif t[:4] == ' ' * 4:
                    for _ in range(4):
                        c.deleteChar()
            else:
                c.insertText('\t')
            if b == last:
                break
            b = b.next()
        cursor.endEditBlock()

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
        now = datetime.now()
        time_str = now.strftime("%Y-%m-%d %H:%M:%S") + f".{now.strftime('%f')[:3]}"
        msg = str(msg)
        print(msg)
        log = f'[{time_str}] {msg}'
        self.log_plainTextEdit.appendPlainText(log)
        if show_in_bar is True:
            self.statusbar.showMessage(msg)

if __name__ == "__main__":
    app = QApplication([])
    win = Win()
    win.show()
    app.exec()
