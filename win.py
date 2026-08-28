import json
import os

from PySide6.QtGui import QColor
from PySide6.QtWidgets import QListWidgetItem

from ui.ui import *

NPC_DIR = os.path.join(os.path.dirname(__file__), "npc", "heroes")
VPK_DIR = os.path.join(os.path.dirname(__file__), "vpk", "pak01_dir", "scripts", "npc", "heroes")


class Win(QMainWindow, Ui_MainWindow):
    def __init__(self):
        super().__init__()
        self.setupUi(self)
        self.files = []  # 全部文件名缓存
        self.config = {}
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

        # 启动时恢复上次打开的文件
        self._read_config()
        self.show_content_when_start()

    def show_files(self, files):
        """展示文件列表"""
        self.heroFiles_listWidget.clear()
        for f in files:
            item = QListWidgetItem(f)
            if os.path.exists(os.path.join(VPK_DIR, f)):
                item.setForeground(QColor(0, 128, 0))  # VPK中存在则标绿
            self.heroFiles_listWidget.addItem(item)

    def search(self, text):
        """模糊搜索"""
        text = text.strip().lower()
        hits = [f for f in self.files if text in f.lower()] if text else self.files
        self.show_files(hits)

    def click_and_show(self, item):
        """点击文件名，展示文件内容"""
        self.current_file = item.text()
        path = os.path.join(VPK_DIR, self.current_file)
        if not os.path.exists(path):
            path = os.path.join(NPC_DIR, self.current_file)
        self._show_content(path)
        self._change_title(path)

    def show_content_when_start(self):
        """启动时，加载展示最近一次的文件内容"""
        path = self.config.get("last_path")
        if path and path != ""  and os.path.exists(path):
            self._show_content(path)
            self._change_title(path)

    def save_file(self):
        """把文件内容保存到VPK_DIR目录里，NPC_DIR的文件内容不动"""
        if not getattr(self, "current_file", None):
            return
        os.makedirs(VPK_DIR, exist_ok=True)
        path = os.path.join(VPK_DIR, self.current_file)
        with open(path, "w", encoding="utf-8") as fh:
            fh.write(self.content_plainTextEdit.toPlainText())
        self._change_title(path)

    def change_selected_item(self):
        """获取content_listWidget的选中行，然后修改好后，再写回该行"""
        text = self.get_selected_item()
        new_text = self._change_text(text)
        self._write_selected_item(new_text)


    def _change_text(self, text):
        """暂时加个一行hahaha就行"""
        new_text = str(text) + '123\n'
        return new_text


    def _get_selected_item(self):
        """获取content_listWidget的选中行"""
        # todo
        # todo:打印
        pass

    def _write_selected_item(self, text):
        """写入content_listWidget的选中行"""
        # todo
        # todo:打印
        pass

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
        self.config['last_path'] = path
        self._save_config()

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


if __name__ == "__main__":
    app = QApplication([])
    win = Win()
    win.show()
    app.exec()
