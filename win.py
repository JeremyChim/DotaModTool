import os

from ui.ui import *

NPC_DIR = os.path.join(os.path.dirname(__file__), "npc", "heroes")
VPK_DIR = os.path.join(os.path.dirname(__file__), "vpk", "pak01_dir", "scripts", "npc", "heroes")


class Win(QMainWindow, Ui_MainWindow):
    def __init__(self):
        super().__init__()
        self.setupUi(self)
        self.files = []  # 全部文件名缓存
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

    def show_files(self, flies):
        """展示文件列表"""
        # todo: 如果VPK_DIR有这个文件，那么字体变成绿色
        self.heroFiles_listWidget.clear()
        self.heroFiles_listWidget.addItems(flies)

    def search(self, text):
        """模糊搜索"""
        text = text.strip().lower()
        hits = [f for f in self.files if text in f.lower()] if text else self.files
        self.show_files(hits)

    def click_and_show(self, item):
        """点击文件名，展示文件内容"""
        with open(os.path.join(NPC_DIR, item.text()), encoding="utf-8", errors="ignore") as fh:
            lines = fh.read().splitlines()
        self.content_listWidget.clear()
        self.content_listWidget.addItems(lines)
        self.content_plainTextEdit.setPlainText("\n".join(lines))

    def save_file():
        """把文件内容保存到VPK_DIR目录里，NPC_DIR的文件内容不动"""
        # todo


if __name__ == "__main__":
    app = QApplication([])
    win = Win()
    win.show()
    app.exec()
