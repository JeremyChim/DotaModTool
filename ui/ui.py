# -*- coding: utf-8 -*-

################################################################################
## Form generated from reading UI file 'ui.ui'
##
## Created by: Qt User Interface Compiler version 6.6.3
##
## WARNING! All changes made in this file will be lost when recompiling UI file!
################################################################################

from PySide6.QtCore import (QCoreApplication, QDate, QDateTime, QLocale,
    QMetaObject, QObject, QPoint, QRect,
    QSize, QTime, QUrl, Qt)
from PySide6.QtGui import (QAction, QBrush, QColor, QConicalGradient,
    QCursor, QFont, QFontDatabase, QGradient,
    QIcon, QImage, QKeySequence, QLinearGradient,
    QPainter, QPalette, QPixmap, QRadialGradient,
    QTransform)
from PySide6.QtWidgets import (QApplication, QFrame, QHBoxLayout, QLineEdit,
    QListWidget, QListWidgetItem, QMainWindow, QMenu,
    QMenuBar, QPlainTextEdit, QPushButton, QSizePolicy,
    QStatusBar, QTabWidget, QVBoxLayout, QWidget)

class Ui_MainWindow(object):
    def setupUi(self, MainWindow):
        if not MainWindow.objectName():
            MainWindow.setObjectName(u"MainWindow")
        MainWindow.resize(1600, 800)
        self.action = QAction(MainWindow)
        self.action.setObjectName(u"action")
        self.load_file_action = QAction(MainWindow)
        self.load_file_action.setObjectName(u"load_file_action")
        self.save_file_line_action = QAction(MainWindow)
        self.save_file_line_action.setObjectName(u"save_file_line_action")
        self.reload_file_action = QAction(MainWindow)
        self.reload_file_action.setObjectName(u"reload_file_action")
        self.change_selected_item_action = QAction(MainWindow)
        self.change_selected_item_action.setObjectName(u"change_selected_item_action")
        self.get_selected_item_action = QAction(MainWindow)
        self.get_selected_item_action.setObjectName(u"get_selected_item_action")
        self.set_font_to_Consolas_action = QAction(MainWindow)
        self.set_font_to_Consolas_action.setObjectName(u"set_font_to_Consolas_action")
        self.set_font_to_JetBrains_Mono_action = QAction(MainWindow)
        self.set_font_to_JetBrains_Mono_action.setObjectName(u"set_font_to_JetBrains_Mono_action")
        self.set_light_theme_action = QAction(MainWindow)
        self.set_light_theme_action.setObjectName(u"set_light_theme_action")
        self.set_dark_theme_action = QAction(MainWindow)
        self.set_dark_theme_action.setObjectName(u"set_dark_theme_action")
        self.top_action = QAction(MainWindow)
        self.top_action.setObjectName(u"top_action")
        self.top_cancel_action = QAction(MainWindow)
        self.top_cancel_action.setObjectName(u"top_cancel_action")
        self.enlarge_font_size_action = QAction(MainWindow)
        self.enlarge_font_size_action.setObjectName(u"enlarge_font_size_action")
        self.reduce_font_size_action = QAction(MainWindow)
        self.reduce_font_size_action.setObjectName(u"reduce_font_size_action")
        self.open_file_action = QAction(MainWindow)
        self.open_file_action.setObjectName(u"open_file_action")
        self.reset_file_action = QAction(MainWindow)
        self.reset_file_action.setObjectName(u"reset_file_action")
        self.set_win_size_1600x800_action = QAction(MainWindow)
        self.set_win_size_1600x800_action.setObjectName(u"set_win_size_1600x800_action")
        self.set_win_size_1800x900_action = QAction(MainWindow)
        self.set_win_size_1800x900_action.setObjectName(u"set_win_size_1800x900_action")
        self.tab_action = QAction(MainWindow)
        self.tab_action.setObjectName(u"tab_action")
        self.back_action = QAction(MainWindow)
        self.back_action.setObjectName(u"back_action")
        self.cut_action = QAction(MainWindow)
        self.cut_action.setObjectName(u"cut_action")
        self.paste_action = QAction(MainWindow)
        self.paste_action.setObjectName(u"paste_action")
        self.undo_action = QAction(MainWindow)
        self.undo_action.setObjectName(u"undo_action")
        self.expand_sidebar_action = QAction(MainWindow)
        self.expand_sidebar_action.setObjectName(u"expand_sidebar_action")
        self.collapse_sidebar_action = QAction(MainWindow)
        self.collapse_sidebar_action.setObjectName(u"collapse_sidebar_action")
        self.shortcut_1_action = QAction(MainWindow)
        self.shortcut_1_action.setObjectName(u"shortcut_1_action")
        self.shortcut_2_action = QAction(MainWindow)
        self.shortcut_2_action.setObjectName(u"shortcut_2_action")
        self.shortcut_3_action = QAction(MainWindow)
        self.shortcut_3_action.setObjectName(u"shortcut_3_action")
        self.shortcut_4_action = QAction(MainWindow)
        self.shortcut_4_action.setObjectName(u"shortcut_4_action")
        self.shortcut_5_action = QAction(MainWindow)
        self.shortcut_5_action.setObjectName(u"shortcut_5_action")
        self.shortcut_6_action = QAction(MainWindow)
        self.shortcut_6_action.setObjectName(u"shortcut_6_action")
        self.shortcut_7_action = QAction(MainWindow)
        self.shortcut_7_action.setObjectName(u"shortcut_7_action")
        self.shortcut_8_action = QAction(MainWindow)
        self.shortcut_8_action.setObjectName(u"shortcut_8_action")
        self.shortcut_9_action = QAction(MainWindow)
        self.shortcut_9_action.setObjectName(u"shortcut_9_action")
        self.shortcut_0_action = QAction(MainWindow)
        self.shortcut_0_action.setObjectName(u"shortcut_0_action")
        self.replace_min_action = QAction(MainWindow)
        self.replace_min_action.setObjectName(u"replace_min_action")
        self.replace_equal_action = QAction(MainWindow)
        self.replace_equal_action.setObjectName(u"replace_equal_action")
        self.replace_add_action = QAction(MainWindow)
        self.replace_add_action.setObjectName(u"replace_add_action")
        self.charge_copy_action = QAction(MainWindow)
        self.charge_copy_action.setObjectName(u"charge_copy_action")
        self.charge_paste_action = QAction(MainWindow)
        self.charge_paste_action.setObjectName(u"charge_paste_action")
        self.cooldown_action = QAction(MainWindow)
        self.cooldown_action.setObjectName(u"cooldown_action")
        self.unit_dir_action = QAction(MainWindow)
        self.unit_dir_action.setObjectName(u"unit_dir_action")
        self.heroes_dir_action = QAction(MainWindow)
        self.heroes_dir_action.setObjectName(u"heroes_dir_action")
        self.root_dir_action = QAction(MainWindow)
        self.root_dir_action.setObjectName(u"root_dir_action")
        self.generate_vpk_action = QAction(MainWindow)
        self.generate_vpk_action.setObjectName(u"generate_vpk_action")
        self.change_units_action = QAction(MainWindow)
        self.change_units_action.setObjectName(u"change_units_action")
        self.change_neutral_items_action = QAction(MainWindow)
        self.change_neutral_items_action.setObjectName(u"change_neutral_items_action")
        self.game_dir_action = QAction(MainWindow)
        self.game_dir_action.setObjectName(u"game_dir_action")
        self.save_file_text_action = QAction(MainWindow)
        self.save_file_text_action.setObjectName(u"save_file_text_action")
        self.charge_un_copy_action = QAction(MainWindow)
        self.charge_un_copy_action.setObjectName(u"charge_un_copy_action")
        self.delete_selected_item_action = QAction(MainWindow)
        self.delete_selected_item_action.setObjectName(u"delete_selected_item_action")
        self.shortcut_ctrl_1_action = QAction(MainWindow)
        self.shortcut_ctrl_1_action.setObjectName(u"shortcut_ctrl_1_action")
        self.action_2 = QAction(MainWindow)
        self.action_2.setObjectName(u"action_2")
        self.shortcut_ctrl_2_action = QAction(MainWindow)
        self.shortcut_ctrl_2_action.setObjectName(u"shortcut_ctrl_2_action")
        self.shortcut_ctrl_3_action = QAction(MainWindow)
        self.shortcut_ctrl_3_action.setObjectName(u"shortcut_ctrl_3_action")
        self.shortcut_ctrl_4_action = QAction(MainWindow)
        self.shortcut_ctrl_4_action.setObjectName(u"shortcut_ctrl_4_action")
        self.shortcut_ctrl_5_action = QAction(MainWindow)
        self.shortcut_ctrl_5_action.setObjectName(u"shortcut_ctrl_5_action")
        self.shortcut_ctrl_6_action = QAction(MainWindow)
        self.shortcut_ctrl_6_action.setObjectName(u"shortcut_ctrl_6_action")
        self.shortcut_ctrl_7_action = QAction(MainWindow)
        self.shortcut_ctrl_7_action.setObjectName(u"shortcut_ctrl_7_action")
        self.shortcut_ctrl_8_action = QAction(MainWindow)
        self.shortcut_ctrl_8_action.setObjectName(u"shortcut_ctrl_8_action")
        self.shortcut_ctrl_9_action = QAction(MainWindow)
        self.shortcut_ctrl_9_action.setObjectName(u"shortcut_ctrl_9_action")
        self.shortcut_ctrl_0_action = QAction(MainWindow)
        self.shortcut_ctrl_0_action.setObjectName(u"shortcut_ctrl_0_action")
        self.generate_vpk_and_move_action = QAction(MainWindow)
        self.generate_vpk_and_move_action.setObjectName(u"generate_vpk_and_move_action")
        self.change_items_action = QAction(MainWindow)
        self.change_items_action.setObjectName(u"change_items_action")
        self.tinkering_dir_action = QAction(MainWindow)
        self.tinkering_dir_action.setObjectName(u"tinkering_dir_action")
        self.open_hyper_ai_dir_action = QAction(MainWindow)
        self.open_hyper_ai_dir_action.setObjectName(u"open_hyper_ai_dir_action")
        self.vscripts_dir_action = QAction(MainWindow)
        self.vscripts_dir_action.setObjectName(u"vscripts_dir_action")
        self.config_file_action = QAction(MainWindow)
        self.config_file_action.setObjectName(u"config_file_action")
        self.ues_tinkering_action = QAction(MainWindow)
        self.ues_tinkering_action.setObjectName(u"ues_tinkering_action")
        self.ues_open_hyper_ai_action = QAction(MainWindow)
        self.ues_open_hyper_ai_action.setObjectName(u"ues_open_hyper_ai_action")
        self.update_gi_action = QAction(MainWindow)
        self.update_gi_action.setObjectName(u"update_gi_action")
        self.reset_gi_action = QAction(MainWindow)
        self.reset_gi_action.setObjectName(u"reset_gi_action")
        self.open_gi_action = QAction(MainWindow)
        self.open_gi_action.setObjectName(u"open_gi_action")
        self.centralwidget = QWidget(MainWindow)
        self.centralwidget.setObjectName(u"centralwidget")
        self.horizontalLayout_5 = QHBoxLayout(self.centralwidget)
        self.horizontalLayout_5.setObjectName(u"horizontalLayout_5")
        self.frame_3 = QFrame(self.centralwidget)
        self.frame_3.setObjectName(u"frame_3")
        self.frame_3.setFrameShape(QFrame.Shape.NoFrame)
        self.horizontalLayout_4 = QHBoxLayout(self.frame_3)
        self.horizontalLayout_4.setSpacing(0)
        self.horizontalLayout_4.setObjectName(u"horizontalLayout_4")
        self.horizontalLayout_4.setContentsMargins(0, 0, 0, 0)
        self.sidebar_frame = QFrame(self.frame_3)
        self.sidebar_frame.setObjectName(u"sidebar_frame")
        self.sidebar_frame.setMaximumSize(QSize(255, 16777215))
        self.sidebar_frame.setFrameShape(QFrame.Shape.NoFrame)
        self.verticalLayout_2 = QVBoxLayout(self.sidebar_frame)
        self.verticalLayout_2.setObjectName(u"verticalLayout_2")
        self.search_lineEdit = QLineEdit(self.sidebar_frame)
        self.search_lineEdit.setObjectName(u"search_lineEdit")

        self.verticalLayout_2.addWidget(self.search_lineEdit)

        self.heroFiles_listWidget = QListWidget(self.sidebar_frame)
        QListWidgetItem(self.heroFiles_listWidget)
        self.heroFiles_listWidget.setObjectName(u"heroFiles_listWidget")

        self.verticalLayout_2.addWidget(self.heroFiles_listWidget)


        self.horizontalLayout_4.addWidget(self.sidebar_frame)

        self.frame_2 = QFrame(self.frame_3)
        self.frame_2.setObjectName(u"frame_2")
        self.frame_2.setFrameShape(QFrame.Shape.NoFrame)
        self.horizontalLayout_3 = QHBoxLayout(self.frame_2)
        self.horizontalLayout_3.setObjectName(u"horizontalLayout_3")
        self.view_tabWidget = QTabWidget(self.frame_2)
        self.view_tabWidget.setObjectName(u"view_tabWidget")
        self.line_tab = QWidget()
        self.line_tab.setObjectName(u"line_tab")
        self.line_tab.setEnabled(True)
        self.horizontalLayout = QHBoxLayout(self.line_tab)
        self.horizontalLayout.setObjectName(u"horizontalLayout")
        self.content_listWidget = QListWidget(self.line_tab)
        QListWidgetItem(self.content_listWidget)
        self.content_listWidget.setObjectName(u"content_listWidget")

        self.horizontalLayout.addWidget(self.content_listWidget)

        self.view_tabWidget.addTab(self.line_tab, "")
        self.text_tab = QWidget()
        self.text_tab.setObjectName(u"text_tab")
        self.text_tab.setEnabled(True)
        sizePolicy = QSizePolicy(QSizePolicy.Policy.Preferred, QSizePolicy.Policy.Preferred)
        sizePolicy.setHorizontalStretch(0)
        sizePolicy.setVerticalStretch(0)
        sizePolicy.setHeightForWidth(self.text_tab.sizePolicy().hasHeightForWidth())
        self.text_tab.setSizePolicy(sizePolicy)
        self.text_tab.setMouseTracking(False)
        self.text_tab.setContextMenuPolicy(Qt.ContextMenuPolicy.NoContextMenu)
        self.horizontalLayout_2 = QHBoxLayout(self.text_tab)
        self.horizontalLayout_2.setObjectName(u"horizontalLayout_2")
        self.content_plainTextEdit = QPlainTextEdit(self.text_tab)
        self.content_plainTextEdit.setObjectName(u"content_plainTextEdit")

        self.horizontalLayout_2.addWidget(self.content_plainTextEdit)

        self.view_tabWidget.addTab(self.text_tab, "")
        self.log_tab = QWidget()
        self.log_tab.setObjectName(u"log_tab")
        self.horizontalLayout_6 = QHBoxLayout(self.log_tab)
        self.horizontalLayout_6.setObjectName(u"horizontalLayout_6")
        self.log_plainTextEdit = QPlainTextEdit(self.log_tab)
        self.log_plainTextEdit.setObjectName(u"log_plainTextEdit")

        self.horizontalLayout_6.addWidget(self.log_plainTextEdit)

        self.view_tabWidget.addTab(self.log_tab, "")
        self.cmd_tab = QWidget()
        self.cmd_tab.setObjectName(u"cmd_tab")
        self.horizontalLayout_7 = QHBoxLayout(self.cmd_tab)
        self.horizontalLayout_7.setObjectName(u"horizontalLayout_7")
        self.cmd_plainTextEdit = QPlainTextEdit(self.cmd_tab)
        self.cmd_plainTextEdit.setObjectName(u"cmd_plainTextEdit")

        self.horizontalLayout_7.addWidget(self.cmd_plainTextEdit)

        self.view_tabWidget.addTab(self.cmd_tab, "")
        self.tab = QWidget()
        self.tab.setObjectName(u"tab")
        self.verticalLayout = QVBoxLayout(self.tab)
        self.verticalLayout.setObjectName(u"verticalLayout")
        self.config_plainTextEdit = QPlainTextEdit(self.tab)
        self.config_plainTextEdit.setObjectName(u"config_plainTextEdit")

        self.verticalLayout.addWidget(self.config_plainTextEdit)

        self.save_config_pushButton = QPushButton(self.tab)
        self.save_config_pushButton.setObjectName(u"save_config_pushButton")

        self.verticalLayout.addWidget(self.save_config_pushButton)

        self.view_tabWidget.addTab(self.tab, "")
        self.cn_name_tab = QWidget()
        self.cn_name_tab.setObjectName(u"cn_name_tab")
        self.horizontalLayout_8 = QHBoxLayout(self.cn_name_tab)
        self.horizontalLayout_8.setObjectName(u"horizontalLayout_8")
        self.cn_name_plainTextEdit = QPlainTextEdit(self.cn_name_tab)
        self.cn_name_plainTextEdit.setObjectName(u"cn_name_plainTextEdit")

        self.horizontalLayout_8.addWidget(self.cn_name_plainTextEdit)

        self.view_tabWidget.addTab(self.cn_name_tab, "")

        self.horizontalLayout_3.addWidget(self.view_tabWidget)


        self.horizontalLayout_4.addWidget(self.frame_2)


        self.horizontalLayout_5.addWidget(self.frame_3)

        MainWindow.setCentralWidget(self.centralwidget)
        self.menubar = QMenuBar(MainWindow)
        self.menubar.setObjectName(u"menubar")
        self.menubar.setGeometry(QRect(0, 0, 1600, 33))
        self.menu = QMenu(self.menubar)
        self.menu.setObjectName(u"menu")
        self.menu_2 = QMenu(self.menubar)
        self.menu_2.setObjectName(u"menu_2")
        self.menu_3 = QMenu(self.menubar)
        self.menu_3.setObjectName(u"menu_3")
        self.menu_4 = QMenu(self.menu_3)
        self.menu_4.setObjectName(u"menu_4")
        self.menu_5 = QMenu(self.menu_3)
        self.menu_5.setObjectName(u"menu_5")
        self.menu_6 = QMenu(self.menu_3)
        self.menu_6.setObjectName(u"menu_6")
        self.menu_6.setGeometry(QRect(464, 176, 121, 202))
        self.menu_7 = QMenu(self.menubar)
        self.menu_7.setObjectName(u"menu_7")
        self.menu_9 = QMenu(self.menu_7)
        self.menu_9.setObjectName(u"menu_9")
        self.menu_8 = QMenu(self.menubar)
        self.menu_8.setObjectName(u"menu_8")
        MainWindow.setMenuBar(self.menubar)
        self.statusbar = QStatusBar(MainWindow)
        self.statusbar.setObjectName(u"statusbar")
        MainWindow.setStatusBar(self.statusbar)

        self.menubar.addAction(self.menu.menuAction())
        self.menubar.addAction(self.menu_2.menuAction())
        self.menubar.addAction(self.menu_8.menuAction())
        self.menubar.addAction(self.menu_3.menuAction())
        self.menubar.addAction(self.menu_7.menuAction())
        self.menu.addAction(self.save_file_line_action)
        self.menu.addAction(self.save_file_text_action)
        self.menu.addAction(self.reload_file_action)
        self.menu.addAction(self.open_file_action)
        self.menu.addAction(self.reset_file_action)
        self.menu_2.addAction(self.change_selected_item_action)
        self.menu_2.addAction(self.delete_selected_item_action)
        self.menu_2.addSeparator()
        self.menu_2.addAction(self.replace_min_action)
        self.menu_2.addAction(self.replace_equal_action)
        self.menu_2.addAction(self.replace_add_action)
        self.menu_2.addSeparator()
        self.menu_2.addAction(self.cooldown_action)
        self.menu_2.addAction(self.charge_copy_action)
        self.menu_2.addAction(self.charge_un_copy_action)
        self.menu_2.addAction(self.charge_paste_action)
        self.menu_2.addSeparator()
        self.menu_2.addAction(self.tab_action)
        self.menu_2.addAction(self.back_action)
        self.menu_2.addAction(self.cut_action)
        self.menu_2.addAction(self.paste_action)
        self.menu_2.addAction(self.undo_action)
        self.menu_3.addAction(self.menu_4.menuAction())
        self.menu_3.addAction(self.menu_5.menuAction())
        self.menu_3.addAction(self.menu_6.menuAction())
        self.menu_4.addAction(self.enlarge_font_size_action)
        self.menu_4.addAction(self.reduce_font_size_action)
        self.menu_4.addSeparator()
        self.menu_4.addAction(self.set_font_to_JetBrains_Mono_action)
        self.menu_4.addAction(self.set_font_to_Consolas_action)
        self.menu_5.addAction(self.set_light_theme_action)
        self.menu_5.addAction(self.set_dark_theme_action)
        self.menu_6.addAction(self.top_action)
        self.menu_6.addAction(self.top_cancel_action)
        self.menu_6.addSeparator()
        self.menu_6.addAction(self.expand_sidebar_action)
        self.menu_6.addAction(self.collapse_sidebar_action)
        self.menu_6.addSeparator()
        self.menu_6.addAction(self.set_win_size_1600x800_action)
        self.menu_6.addAction(self.set_win_size_1800x900_action)
        self.menu_7.addAction(self.root_dir_action)
        self.menu_7.addAction(self.unit_dir_action)
        self.menu_7.addAction(self.heroes_dir_action)
        self.menu_7.addAction(self.game_dir_action)
        self.menu_7.addAction(self.menu_9.menuAction())
        self.menu_7.addSeparator()
        self.menu_7.addAction(self.ues_tinkering_action)
        self.menu_7.addAction(self.ues_open_hyper_ai_action)
        self.menu_7.addSeparator()
        self.menu_7.addAction(self.update_gi_action)
        self.menu_7.addAction(self.reset_gi_action)
        self.menu_7.addAction(self.open_gi_action)
        self.menu_7.addSeparator()
        self.menu_7.addAction(self.change_units_action)
        self.menu_7.addAction(self.change_neutral_items_action)
        self.menu_7.addAction(self.change_items_action)
        self.menu_7.addSeparator()
        self.menu_7.addAction(self.config_file_action)
        self.menu_7.addAction(self.generate_vpk_action)
        self.menu_7.addAction(self.generate_vpk_and_move_action)
        self.menu_9.addAction(self.vscripts_dir_action)
        self.menu_9.addAction(self.tinkering_dir_action)
        self.menu_9.addAction(self.open_hyper_ai_dir_action)
        self.menu_8.addAction(self.shortcut_1_action)
        self.menu_8.addAction(self.shortcut_2_action)
        self.menu_8.addAction(self.shortcut_3_action)
        self.menu_8.addAction(self.shortcut_4_action)
        self.menu_8.addAction(self.shortcut_5_action)
        self.menu_8.addAction(self.shortcut_6_action)
        self.menu_8.addAction(self.shortcut_7_action)
        self.menu_8.addAction(self.shortcut_8_action)
        self.menu_8.addAction(self.shortcut_9_action)
        self.menu_8.addAction(self.shortcut_0_action)
        self.menu_8.addSeparator()
        self.menu_8.addAction(self.shortcut_ctrl_1_action)
        self.menu_8.addAction(self.shortcut_ctrl_2_action)
        self.menu_8.addAction(self.shortcut_ctrl_3_action)
        self.menu_8.addAction(self.shortcut_ctrl_4_action)
        self.menu_8.addAction(self.shortcut_ctrl_5_action)
        self.menu_8.addAction(self.shortcut_ctrl_6_action)
        self.menu_8.addAction(self.shortcut_ctrl_7_action)
        self.menu_8.addAction(self.shortcut_ctrl_8_action)
        self.menu_8.addAction(self.shortcut_ctrl_9_action)
        self.menu_8.addAction(self.shortcut_ctrl_0_action)

        self.retranslateUi(MainWindow)

        self.view_tabWidget.setCurrentIndex(5)


        QMetaObject.connectSlotsByName(MainWindow)
    # setupUi

    def retranslateUi(self, MainWindow):
        MainWindow.setWindowTitle(QCoreApplication.translate("MainWindow", u"MainWindow", None))
        self.action.setText(QCoreApplication.translate("MainWindow", u"\u7f6e\u9876", None))
        self.load_file_action.setText(QCoreApplication.translate("MainWindow", u"\u8f7d\u5165", None))
        self.save_file_line_action.setText(QCoreApplication.translate("MainWindow", u"\u4fdd\u5b58(\u884c)", None))
#if QT_CONFIG(shortcut)
        self.save_file_line_action.setShortcut(QCoreApplication.translate("MainWindow", u"S", None))
#endif // QT_CONFIG(shortcut)
        self.reload_file_action.setText(QCoreApplication.translate("MainWindow", u"\u91cd\u8f7d", None))
#if QT_CONFIG(shortcut)
        self.reload_file_action.setShortcut(QCoreApplication.translate("MainWindow", u"R", None))
#endif // QT_CONFIG(shortcut)
        self.change_selected_item_action.setText(QCoreApplication.translate("MainWindow", u"\u4fee\u6539\u9009\u4e2d\u884c", None))
#if QT_CONFIG(shortcut)
        self.change_selected_item_action.setShortcut(QCoreApplication.translate("MainWindow", u"Space", None))
#endif // QT_CONFIG(shortcut)
        self.get_selected_item_action.setText(QCoreApplication.translate("MainWindow", u"\u5199\u5165\u9009\u4e2d\u884c", None))
        self.set_font_to_Consolas_action.setText(QCoreApplication.translate("MainWindow", u"Consolas", None))
        self.set_font_to_JetBrains_Mono_action.setText(QCoreApplication.translate("MainWindow", u"JetBrains Mono", None))
        self.set_light_theme_action.setText(QCoreApplication.translate("MainWindow", u"\u4eae\u8272", None))
        self.set_dark_theme_action.setText(QCoreApplication.translate("MainWindow", u"\u6697\u8272", None))
        self.top_action.setText(QCoreApplication.translate("MainWindow", u"\u7f6e\u9876", None))
#if QT_CONFIG(shortcut)
        self.top_action.setShortcut(QCoreApplication.translate("MainWindow", u"T", None))
#endif // QT_CONFIG(shortcut)
        self.top_cancel_action.setText(QCoreApplication.translate("MainWindow", u"\u53d6\u6d88\u7f6e\u9876", None))
#if QT_CONFIG(shortcut)
        self.top_cancel_action.setShortcut(QCoreApplication.translate("MainWindow", u"Ctrl+T", None))
#endif // QT_CONFIG(shortcut)
        self.enlarge_font_size_action.setText(QCoreApplication.translate("MainWindow", u"\u653e\u5927\u5b57\u4f53", None))
#if QT_CONFIG(shortcut)
        self.enlarge_font_size_action.setShortcut(QCoreApplication.translate("MainWindow", u"Ctrl+=", None))
#endif // QT_CONFIG(shortcut)
        self.reduce_font_size_action.setText(QCoreApplication.translate("MainWindow", u"\u7f29\u5c0f\u5b57\u4f53", None))
#if QT_CONFIG(shortcut)
        self.reduce_font_size_action.setShortcut(QCoreApplication.translate("MainWindow", u"Ctrl+-", None))
#endif // QT_CONFIG(shortcut)
        self.open_file_action.setText(QCoreApplication.translate("MainWindow", u"\u6253\u5f00", None))
#if QT_CONFIG(shortcut)
        self.open_file_action.setShortcut(QCoreApplication.translate("MainWindow", u"O", None))
#endif // QT_CONFIG(shortcut)
        self.reset_file_action.setText(QCoreApplication.translate("MainWindow", u"\u91cd\u7f6e", None))
#if QT_CONFIG(shortcut)
        self.reset_file_action.setShortcut(QCoreApplication.translate("MainWindow", u"Ctrl+R", None))
#endif // QT_CONFIG(shortcut)
        self.set_win_size_1600x800_action.setText(QCoreApplication.translate("MainWindow", u"1600x800", None))
        self.set_win_size_1800x900_action.setText(QCoreApplication.translate("MainWindow", u"1800x900", None))
        self.tab_action.setText(QCoreApplication.translate("MainWindow", u"\u7f29\u8fdb", None))
#if QT_CONFIG(shortcut)
        self.tab_action.setShortcut(QCoreApplication.translate("MainWindow", u"Tab", None))
#endif // QT_CONFIG(shortcut)
        self.back_action.setText(QCoreApplication.translate("MainWindow", u"\u9000\u683c", None))
#if QT_CONFIG(shortcut)
        self.back_action.setShortcut(QCoreApplication.translate("MainWindow", u"Backspace", None))
#endif // QT_CONFIG(shortcut)
        self.cut_action.setText(QCoreApplication.translate("MainWindow", u"\u526a\u5207", None))
#if QT_CONFIG(shortcut)
        self.cut_action.setShortcut(QCoreApplication.translate("MainWindow", u"X", None))
#endif // QT_CONFIG(shortcut)
        self.paste_action.setText(QCoreApplication.translate("MainWindow", u"\u7c98\u8d34", None))
#if QT_CONFIG(shortcut)
        self.paste_action.setShortcut(QCoreApplication.translate("MainWindow", u"V", None))
#endif // QT_CONFIG(shortcut)
        self.undo_action.setText(QCoreApplication.translate("MainWindow", u"\u64a4\u56de", None))
#if QT_CONFIG(shortcut)
        self.undo_action.setShortcut(QCoreApplication.translate("MainWindow", u"Z", None))
#endif // QT_CONFIG(shortcut)
        self.expand_sidebar_action.setText(QCoreApplication.translate("MainWindow", u"\u4fa7\u680f\u5c55\u5f00", None))
#if QT_CONFIG(shortcut)
        self.expand_sidebar_action.setShortcut(QCoreApplication.translate("MainWindow", u"`", None))
#endif // QT_CONFIG(shortcut)
        self.collapse_sidebar_action.setText(QCoreApplication.translate("MainWindow", u"\u4fa7\u680f\u6536\u8d77", None))
#if QT_CONFIG(shortcut)
        self.collapse_sidebar_action.setShortcut(QCoreApplication.translate("MainWindow", u"Ctrl+`", None))
#endif // QT_CONFIG(shortcut)
        self.shortcut_1_action.setText(QCoreApplication.translate("MainWindow", u"\u5feb\u6377\u952e1", None))
#if QT_CONFIG(shortcut)
        self.shortcut_1_action.setShortcut(QCoreApplication.translate("MainWindow", u"1", None))
#endif // QT_CONFIG(shortcut)
        self.shortcut_2_action.setText(QCoreApplication.translate("MainWindow", u"\u5feb\u6377\u952e2", None))
#if QT_CONFIG(shortcut)
        self.shortcut_2_action.setShortcut(QCoreApplication.translate("MainWindow", u"2", None))
#endif // QT_CONFIG(shortcut)
        self.shortcut_3_action.setText(QCoreApplication.translate("MainWindow", u"\u5feb\u6377\u952e3", None))
#if QT_CONFIG(shortcut)
        self.shortcut_3_action.setShortcut(QCoreApplication.translate("MainWindow", u"3", None))
#endif // QT_CONFIG(shortcut)
        self.shortcut_4_action.setText(QCoreApplication.translate("MainWindow", u"\u5feb\u6377\u952e4", None))
#if QT_CONFIG(shortcut)
        self.shortcut_4_action.setShortcut(QCoreApplication.translate("MainWindow", u"4", None))
#endif // QT_CONFIG(shortcut)
        self.shortcut_5_action.setText(QCoreApplication.translate("MainWindow", u"\u5feb\u6377\u952e5", None))
#if QT_CONFIG(shortcut)
        self.shortcut_5_action.setShortcut(QCoreApplication.translate("MainWindow", u"5", None))
#endif // QT_CONFIG(shortcut)
        self.shortcut_6_action.setText(QCoreApplication.translate("MainWindow", u"\u5feb\u6377\u952e6", None))
#if QT_CONFIG(shortcut)
        self.shortcut_6_action.setShortcut(QCoreApplication.translate("MainWindow", u"6", None))
#endif // QT_CONFIG(shortcut)
        self.shortcut_7_action.setText(QCoreApplication.translate("MainWindow", u"\u5feb\u6377\u952e7", None))
#if QT_CONFIG(shortcut)
        self.shortcut_7_action.setShortcut(QCoreApplication.translate("MainWindow", u"7", None))
#endif // QT_CONFIG(shortcut)
        self.shortcut_8_action.setText(QCoreApplication.translate("MainWindow", u"\u5feb\u6377\u952e8", None))
#if QT_CONFIG(shortcut)
        self.shortcut_8_action.setShortcut(QCoreApplication.translate("MainWindow", u"8", None))
#endif // QT_CONFIG(shortcut)
        self.shortcut_9_action.setText(QCoreApplication.translate("MainWindow", u"\u5feb\u6377\u952e9", None))
#if QT_CONFIG(shortcut)
        self.shortcut_9_action.setShortcut(QCoreApplication.translate("MainWindow", u"9", None))
#endif // QT_CONFIG(shortcut)
        self.shortcut_0_action.setText(QCoreApplication.translate("MainWindow", u"\u5feb\u6377\u952e0", None))
#if QT_CONFIG(shortcut)
        self.shortcut_0_action.setShortcut(QCoreApplication.translate("MainWindow", u"0", None))
#endif // QT_CONFIG(shortcut)
        self.replace_min_action.setText(QCoreApplication.translate("MainWindow", u"\u66ff\u6362\u6210-", None))
#if QT_CONFIG(shortcut)
        self.replace_min_action.setShortcut(QCoreApplication.translate("MainWindow", u"-", None))
#endif // QT_CONFIG(shortcut)
        self.replace_equal_action.setText(QCoreApplication.translate("MainWindow", u"\u66ff\u6362\u6210=", None))
#if QT_CONFIG(shortcut)
        self.replace_equal_action.setShortcut(QCoreApplication.translate("MainWindow", u"=", None))
#endif // QT_CONFIG(shortcut)
        self.replace_add_action.setText(QCoreApplication.translate("MainWindow", u"\u66ff\u6362\u6210+", None))
#if QT_CONFIG(shortcut)
        self.replace_add_action.setShortcut(QCoreApplication.translate("MainWindow", u"+", None))
#endif // QT_CONFIG(shortcut)
        self.charge_copy_action.setText(QCoreApplication.translate("MainWindow", u"\u5145\u80fd\u590d\u5236", None))
#if QT_CONFIG(shortcut)
        self.charge_copy_action.setShortcut(QCoreApplication.translate("MainWindow", u"G", None))
#endif // QT_CONFIG(shortcut)
        self.charge_paste_action.setText(QCoreApplication.translate("MainWindow", u"\u5145\u80fd\u7c98\u8d34", None))
#if QT_CONFIG(shortcut)
        self.charge_paste_action.setShortcut(QCoreApplication.translate("MainWindow", u"H", None))
#endif // QT_CONFIG(shortcut)
        self.cooldown_action.setText(QCoreApplication.translate("MainWindow", u"\u51b7\u5374\u4fee\u6539", None))
#if QT_CONFIG(shortcut)
        self.cooldown_action.setShortcut(QCoreApplication.translate("MainWindow", u"D", None))
#endif // QT_CONFIG(shortcut)
        self.unit_dir_action.setText(QCoreApplication.translate("MainWindow", u"\u5355\u4f4d\u76ee\u5f55", None))
#if QT_CONFIG(shortcut)
        self.unit_dir_action.setShortcut(QCoreApplication.translate("MainWindow", u"F2", None))
#endif // QT_CONFIG(shortcut)
        self.heroes_dir_action.setText(QCoreApplication.translate("MainWindow", u"\u82f1\u96c4\u76ee\u5f55", None))
#if QT_CONFIG(shortcut)
        self.heroes_dir_action.setShortcut(QCoreApplication.translate("MainWindow", u"F3", None))
#endif // QT_CONFIG(shortcut)
        self.root_dir_action.setText(QCoreApplication.translate("MainWindow", u"\u6839\u76ee\u5f55", None))
#if QT_CONFIG(shortcut)
        self.root_dir_action.setShortcut(QCoreApplication.translate("MainWindow", u"F1", None))
#endif // QT_CONFIG(shortcut)
        self.generate_vpk_action.setText(QCoreApplication.translate("MainWindow", u"\u751f\u6210vpk", None))
#if QT_CONFIG(shortcut)
        self.generate_vpk_action.setShortcut(QCoreApplication.translate("MainWindow", u"F5", None))
#endif // QT_CONFIG(shortcut)
        self.change_units_action.setText(QCoreApplication.translate("MainWindow", u"\u4fee\u6539\u5355\u4f4d\u6570\u636e", None))
        self.change_neutral_items_action.setText(QCoreApplication.translate("MainWindow", u"\u4fee\u6539\u4e2d\u7acb\u7269\u54c1", None))
        self.game_dir_action.setText(QCoreApplication.translate("MainWindow", u"\u6e38\u620f\u76ee\u5f55", None))
#if QT_CONFIG(shortcut)
        self.game_dir_action.setShortcut(QCoreApplication.translate("MainWindow", u"F4", None))
#endif // QT_CONFIG(shortcut)
        self.save_file_text_action.setText(QCoreApplication.translate("MainWindow", u"\u4fdd\u5b58(\u6587\u672c)", None))
#if QT_CONFIG(shortcut)
        self.save_file_text_action.setShortcut(QCoreApplication.translate("MainWindow", u"Ctrl+S", None))
#endif // QT_CONFIG(shortcut)
        self.charge_un_copy_action.setText(QCoreApplication.translate("MainWindow", u"\u5145\u80fd\u590d\u5236(\u5929\u8d4b)", None))
#if QT_CONFIG(shortcut)
        self.charge_un_copy_action.setShortcut(QCoreApplication.translate("MainWindow", u"U", None))
#endif // QT_CONFIG(shortcut)
        self.delete_selected_item_action.setText(QCoreApplication.translate("MainWindow", u"\u5220\u9664\u9009\u4e2d\u884c", None))
#if QT_CONFIG(shortcut)
        self.delete_selected_item_action.setShortcut(QCoreApplication.translate("MainWindow", u"Del", None))
#endif // QT_CONFIG(shortcut)
        self.shortcut_ctrl_1_action.setText(QCoreApplication.translate("MainWindow", u"\u5feb\u6377\u952eCtrl+1", None))
#if QT_CONFIG(shortcut)
        self.shortcut_ctrl_1_action.setShortcut(QCoreApplication.translate("MainWindow", u"Ctrl+1", None))
#endif // QT_CONFIG(shortcut)
        self.action_2.setText(QCoreApplication.translate("MainWindow", u"\u5feb\u6377\u64cd\u4f5c", None))
        self.shortcut_ctrl_2_action.setText(QCoreApplication.translate("MainWindow", u"\u5feb\u6377\u952eCtrl+2", None))
#if QT_CONFIG(shortcut)
        self.shortcut_ctrl_2_action.setShortcut(QCoreApplication.translate("MainWindow", u"Ctrl+2", None))
#endif // QT_CONFIG(shortcut)
        self.shortcut_ctrl_3_action.setText(QCoreApplication.translate("MainWindow", u"\u5feb\u6377\u952eCtrl+3", None))
#if QT_CONFIG(shortcut)
        self.shortcut_ctrl_3_action.setShortcut(QCoreApplication.translate("MainWindow", u"Ctrl+3", None))
#endif // QT_CONFIG(shortcut)
        self.shortcut_ctrl_4_action.setText(QCoreApplication.translate("MainWindow", u"\u5feb\u6377\u952eCtrl+4", None))
#if QT_CONFIG(shortcut)
        self.shortcut_ctrl_4_action.setShortcut(QCoreApplication.translate("MainWindow", u"Ctrl+4", None))
#endif // QT_CONFIG(shortcut)
        self.shortcut_ctrl_5_action.setText(QCoreApplication.translate("MainWindow", u"\u5feb\u6377\u952eCtrl+5", None))
#if QT_CONFIG(shortcut)
        self.shortcut_ctrl_5_action.setShortcut(QCoreApplication.translate("MainWindow", u"Ctrl+5", None))
#endif // QT_CONFIG(shortcut)
        self.shortcut_ctrl_6_action.setText(QCoreApplication.translate("MainWindow", u"\u5feb\u6377\u952eCtrl+6", None))
#if QT_CONFIG(shortcut)
        self.shortcut_ctrl_6_action.setShortcut(QCoreApplication.translate("MainWindow", u"Ctrl+6", None))
#endif // QT_CONFIG(shortcut)
        self.shortcut_ctrl_7_action.setText(QCoreApplication.translate("MainWindow", u"\u5feb\u6377\u952eCtrl+7", None))
#if QT_CONFIG(shortcut)
        self.shortcut_ctrl_7_action.setShortcut(QCoreApplication.translate("MainWindow", u"Ctrl+7", None))
#endif // QT_CONFIG(shortcut)
        self.shortcut_ctrl_8_action.setText(QCoreApplication.translate("MainWindow", u"\u5feb\u6377\u952eCtrl+8", None))
#if QT_CONFIG(shortcut)
        self.shortcut_ctrl_8_action.setShortcut(QCoreApplication.translate("MainWindow", u"Ctrl+8", None))
#endif // QT_CONFIG(shortcut)
        self.shortcut_ctrl_9_action.setText(QCoreApplication.translate("MainWindow", u"\u5feb\u6377\u952eCtrl+9", None))
#if QT_CONFIG(shortcut)
        self.shortcut_ctrl_9_action.setShortcut(QCoreApplication.translate("MainWindow", u"Ctrl+9", None))
#endif // QT_CONFIG(shortcut)
        self.shortcut_ctrl_0_action.setText(QCoreApplication.translate("MainWindow", u"\u5feb\u6377\u952eCtrl+0", None))
#if QT_CONFIG(shortcut)
        self.shortcut_ctrl_0_action.setShortcut(QCoreApplication.translate("MainWindow", u"Ctrl+0", None))
#endif // QT_CONFIG(shortcut)
        self.generate_vpk_and_move_action.setText(QCoreApplication.translate("MainWindow", u"\u751f\u6210vpk\u5e76\u79fb\u52a8", None))
#if QT_CONFIG(shortcut)
        self.generate_vpk_and_move_action.setShortcut(QCoreApplication.translate("MainWindow", u"F6", None))
#endif // QT_CONFIG(shortcut)
        self.change_items_action.setText(QCoreApplication.translate("MainWindow", u"\u4fee\u6539\u5546\u5e97\u7269\u54c1", None))
        self.tinkering_dir_action.setText(QCoreApplication.translate("MainWindow", u"tinkering", None))
        self.open_hyper_ai_dir_action.setText(QCoreApplication.translate("MainWindow", u"open_hyper_ai", None))
        self.vscripts_dir_action.setText(QCoreApplication.translate("MainWindow", u"vscripts", None))
        self.config_file_action.setText(QCoreApplication.translate("MainWindow", u"\u6253\u5f00\u914d\u7f6e", None))
        self.ues_tinkering_action.setText(QCoreApplication.translate("MainWindow", u"\u4f7f\u7528\uff1atinkering", None))
        self.ues_open_hyper_ai_action.setText(QCoreApplication.translate("MainWindow", u"\u4f7f\u7528\uff1aopen_hyper_ai", None))
        self.update_gi_action.setText(QCoreApplication.translate("MainWindow", u"\u66f4\u65b0gi", None))
        self.reset_gi_action.setText(QCoreApplication.translate("MainWindow", u"\u91cd\u7f6egi", None))
        self.open_gi_action.setText(QCoreApplication.translate("MainWindow", u"\u6253\u5f00gi", None))
        self.search_lineEdit.setText("")
        self.search_lineEdit.setPlaceholderText(QCoreApplication.translate("MainWindow", u"\u641c\u7d22...", None))

        __sortingEnabled = self.heroFiles_listWidget.isSortingEnabled()
        self.heroFiles_listWidget.setSortingEnabled(False)
        ___qlistwidgetitem = self.heroFiles_listWidget.item(0)
        ___qlistwidgetitem.setText(QCoreApplication.translate("MainWindow", u"\u672a\u627e\u5230\u6587\u4ef6\u5217\u8868...", None));
        self.heroFiles_listWidget.setSortingEnabled(__sortingEnabled)


        __sortingEnabled1 = self.content_listWidget.isSortingEnabled()
        self.content_listWidget.setSortingEnabled(False)
        ___qlistwidgetitem1 = self.content_listWidget.item(0)
        ___qlistwidgetitem1.setText(QCoreApplication.translate("MainWindow", u"\u672a\u52a0\u8f7d\u6587\u4ef6...", None));
        self.content_listWidget.setSortingEnabled(__sortingEnabled1)

        self.view_tabWidget.setTabText(self.view_tabWidget.indexOf(self.line_tab), QCoreApplication.translate("MainWindow", u"\u884c\u89c6\u56fe", None))
        self.content_plainTextEdit.setPlainText(QCoreApplication.translate("MainWindow", u"\u672a\u52a0\u8f7d\u6587\u4ef6...", None))
        self.view_tabWidget.setTabText(self.view_tabWidget.indexOf(self.text_tab), QCoreApplication.translate("MainWindow", u"\u6587\u672c\u89c6\u56fe", None))
#if QT_CONFIG(accessibility)
        self.log_tab.setAccessibleName("")
#endif // QT_CONFIG(accessibility)
#if QT_CONFIG(tooltip)
        self.log_plainTextEdit.setToolTip("")
#endif // QT_CONFIG(tooltip)
        self.log_plainTextEdit.setPlainText("")
        self.view_tabWidget.setTabText(self.view_tabWidget.indexOf(self.log_tab), QCoreApplication.translate("MainWindow", u"\u811a\u672c\u65e5\u5fd7", None))
#if QT_CONFIG(tooltip)
        self.cmd_plainTextEdit.setToolTip("")
#endif // QT_CONFIG(tooltip)
        self.cmd_plainTextEdit.setPlainText(QCoreApplication.translate("MainWindow", u"steam\u542f\u52a8\u9879\uff1a+con_enable 1 -noforcemaccel -noforcemspd -useforcedmparms -windowed -noborder -high -map dota -nod3d9ex -nohltv -novr -nojoy -novid\n"
"\n"
"bot\u811a\u672c\u6307\u4ee41\uff1asv_cheats 1; script_reload_code bots/Buff/buff\n"
"\n"
"bot\u811a\u672c\u6307\u4ee42\uff1asv_cheats 1; script_reload_code bots/fretbots", None))
        self.view_tabWidget.setTabText(self.view_tabWidget.indexOf(self.cmd_tab), QCoreApplication.translate("MainWindow", u"\u5e38\u7528\u6307\u4ee4", None))
#if QT_CONFIG(tooltip)
        self.config_plainTextEdit.setToolTip("")
#endif // QT_CONFIG(tooltip)
        self.config_plainTextEdit.setPlainText("")
        self.save_config_pushButton.setText(QCoreApplication.translate("MainWindow", u"\u4fdd\u5b58", None))
#if QT_CONFIG(shortcut)
        self.save_config_pushButton.setShortcut(QCoreApplication.translate("MainWindow", u"Ctrl+Shift+S", None))
#endif // QT_CONFIG(shortcut)
        self.view_tabWidget.setTabText(self.view_tabWidget.indexOf(self.tab), QCoreApplication.translate("MainWindow", u"\u914d\u7f6e\u6587\u4ef6", None))
#if QT_CONFIG(tooltip)
        self.cn_name_plainTextEdit.setToolTip("")
#endif // QT_CONFIG(tooltip)
        self.cn_name_plainTextEdit.setPlainText(QCoreApplication.translate("MainWindow", u"{\n"
"    \"npc_dota_hero_abaddon\": \"\u4e9a\u5df4\u987f\",\n"
"    \"npc_dota_hero_abyssal_underlord\": \"\u5b7d\u4e3b\",\n"
"    \"npc_dota_hero_alchemist\": \"\u70bc\u91d1\u672f\u58eb\",\n"
"    \"npc_dota_hero_ancient_apparition\": \"\u8fdc\u53e4\u51b0\u9b44\",\n"
"    \"npc_dota_hero_antimage\": \"\u654c\u6cd5\u5e08\",\n"
"    \"npc_dota_hero_arc_warden\": \"\u5929\u7a79\u5b88\u671b\u8005\",\n"
"    \"npc_dota_hero_axe\": \"\u65a7\u738b\",\n"
"    \"npc_dota_hero_bane\": \"\u7978\u4e71\u4e4b\u6e90\",\n"
"    \"npc_dota_hero_batrider\": \"\u8759\u8760\u9a91\u58eb\",\n"
"    \"npc_dota_hero_beastmaster\": \"\u517d\u738b\",\n"
"    \"npc_dota_hero_bloodseeker\": \"\u8840\u9b54\",\n"
"    \"npc_dota_hero_bounty_hunter\": \"\u8d4f\u91d1\u730e\u4eba\",\n"
"    \"npc_dota_hero_brewmaster\": \"\u9152\u4ed9\",\n"
"    \"npc_dota_hero_bristleback\": \"\u94a2\u80cc\u517d\",\n"
"    \"npc_dota_hero_broodmother\": \"\u80b2\u6bcd\u8718\u86db\",\n"
"    \"npc_dota_hero_centaur\": \"\u534a\u4eba\u9a6c\u6218\u884c\u8005\""
                        ",\n"
"    \"npc_dota_hero_chaos_knight\": \"\u6df7\u6c8c\u9a91\u58eb\",\n"
"    \"npc_dota_hero_chen\": \"\u9648\",\n"
"    \"npc_dota_hero_clinkz\": \"\u514b\u6797\u514b\u5179\",\n"
"    \"npc_dota_hero_crystal_maiden\": \"\u6c34\u6676\u5ba4\u5973\",\n"
"    \"npc_dota_hero_dark_seer\": \"\u9ed1\u6697\u8d24\u8005\",\n"
"    \"npc_dota_hero_dark_willow\": \"\u90aa\u5f71\u82b3\u7075\",\n"
"    \"npc_dota_hero_dawnbreaker\": \"\u7834\u6653\u8fb0\u661f\",\n"
"    \"npc_dota_hero_dazzle\": \"\u6234\u6cfd\",\n"
"    \"npc_dota_hero_death_prophet\": \"\u6b7b\u4ea1\u5148\u77e5\",\n"
"    \"npc_dota_hero_disruptor\": \"\u5e72\u6270\u8005\",\n"
"    \"npc_dota_hero_doom_bringer\": \"\u672b\u65e5\u4f7f\u8005\",\n"
"    \"npc_dota_hero_dragon_knight\": \"\u9f99\u9a91\u58eb\",\n"
"    \"npc_dota_hero_drow_ranger\": \"\u5353\u5c14\u6e38\u4fa0\",\n"
"    \"npc_dota_hero_earth_spirit\": \"\u5927\u5730\u4e4b\u7075\",\n"
"    \"npc_dota_hero_earthshaker\": \"\u64bc\u5730\u8005\",\n"
"    \"npc_dota_hero_elder_titan\": \"\u4e0a"
                        "\u53e4\u5de8\u795e\",\n"
"    \"npc_dota_hero_ember_spirit\": \"\u7070\u70ec\u4e4b\u7075\",\n"
"    \"npc_dota_hero_enchantress\": \"\u9b45\u60d1\u9b54\u5973\",\n"
"    \"npc_dota_hero_enigma\": \"\u8c1c\u56e2\",\n"
"    \"npc_dota_hero_faceless_void\": \"\u865a\u7a7a\u5047\u9762\",\n"
"    \"npc_dota_hero_furion\": \"\u5148\u77e5\",\n"
"    \"npc_dota_hero_grimstroke\": \"\u5929\u6daf\u58a8\u5ba2\",\n"
"    \"npc_dota_hero_gyrocopter\": \"\u77ee\u4eba\u76f4\u5347\u673a\",\n"
"    \"npc_dota_hero_hoodwink\": \"\u68ee\u6d77\u98de\u971e\",\n"
"    \"npc_dota_hero_huskar\": \"\u54c8\u65af\u5361\",\n"
"    \"npc_dota_hero_invoker\": \"\u7948\u6c42\u8005\",\n"
"    \"npc_dota_hero_jakiro\": \"\u6770\u5947\u6d1b\",\n"
"    \"npc_dota_hero_juggernaut\": \"\u4e3b\u5bb0\",\n"
"    \"npc_dota_hero_keeper_of_the_light\": \"\u5149\u4e4b\u5b88\u536b\",\n"
"    \"npc_dota_hero_kez\": \"\u51ef\",\n"
"    \"npc_dota_hero_kunkka\": \"\u6606\u5361\",\n"
"    \"npc_dota_hero_legion_commander\": \"\u519b\u56e2\u6307\u6325\u5b98\""
                        ",\n"
"    \"npc_dota_hero_leshrac\": \"\u62c9\u5e2d\u514b\",\n"
"    \"npc_dota_hero_lich\": \"\u5deb\u5996\",\n"
"    \"npc_dota_hero_life_stealer\": \"\u566c\u9b42\u9b3c\",\n"
"    \"npc_dota_hero_lina\": \"\u8389\u5a1c\",\n"
"    \"npc_dota_hero_lion\": \"\u83b1\u6069\",\n"
"    \"npc_dota_hero_lone_druid\": \"\u5fb7\u9c81\u4f0a\",\n"
"    \"npc_dota_hero_luna\": \"\u9732\u5a1c\",\n"
"    \"npc_dota_hero_lycan\": \"\u72fc\u4eba\",\n"
"    \"npc_dota_hero_magnataur\": \"\u9a6c\u683c\u7eb3\u65af\",\n"
"    \"npc_dota_hero_marci\": \"\u9a6c\u897f\",\n"
"    \"npc_dota_hero_mars\": \"\u9a6c\u5c14\u65af\",\n"
"    \"npc_dota_hero_medusa\": \"\u7f8e\u675c\u838e\",\n"
"    \"npc_dota_hero_meepo\": \"\u7c73\u6ce2\",\n"
"    \"npc_dota_hero_mirana\": \"\u7c73\u62c9\u5a1c\",\n"
"    \"npc_dota_hero_monkey_king\": \"\u9f50\u5929\u5927\u5723\",\n"
"    \"npc_dota_hero_morphling\": \"\u53d8\u4f53\u7cbe\u7075\",\n"
"    \"npc_dota_hero_muerta\": \"\u743c\u82f1\u78a7\u7075\",\n"
"    \"npc_dota_hero_naga_siren\": \"\u5a1c"
                        "\u8fe6\u6d77\u5996\",\n"
"    \"npc_dota_hero_necrolyte\": \"\u761f\u75ab\u6cd5\u5e08\",\n"
"    \"npc_dota_hero_nevermore\": \"\u5f71\u9b54\",\n"
"    \"npc_dota_hero_night_stalker\": \"\u6697\u591c\u9b54\u738b\",\n"
"    \"npc_dota_hero_nyx_assassin\": \"\u53f8\u591c\u523a\u5ba2\",\n"
"    \"npc_dota_hero_obsidian_destroyer\": \"\u6b81\u5883\u795e\u8680\u8005\",\n"
"    \"npc_dota_hero_ogre_magi\": \"\u98df\u4eba\u9b54\u9b54\u6cd5\u5e08\",\n"
"    \"npc_dota_hero_omniknight\": \"\u5168\u80fd\u9a91\u58eb\",\n"
"    \"npc_dota_hero_oracle\": \"\u795e\u8c15\u8005\",\n"
"    \"npc_dota_hero_pangolier\": \"\u77f3\u9cde\u5251\u58eb\",\n"
"    \"npc_dota_hero_phantom_assassin\": \"\u5e7b\u5f71\u523a\u5ba2\",\n"
"    \"npc_dota_hero_phantom_lancer\": \"\u5e7b\u5f71\u957f\u77db\u624b\",\n"
"    \"npc_dota_hero_phoenix\": \"\u51e4\u51f0\",\n"
"    \"npc_dota_hero_primal_beast\": \"\u517d\",\n"
"    \"npc_dota_hero_puck\": \"\u5e15\u514b\",\n"
"    \"npc_dota_hero_pudge\": \"\u5e15\u5409\",\n"
"    \"npc_dota_hero_pugn"
                        "a\": \"\u5e15\u683c\u7eb3\",\n"
"    \"npc_dota_hero_queenofpain\": \"\u75db\u82e6\u5973\u738b\",\n"
"    \"npc_dota_hero_rattletrap\": \"\u53d1\u6761\u6280\u5e08\",\n"
"    \"npc_dota_hero_razor\": \"\u5243\u5200\",\n"
"    \"npc_dota_hero_riki\": \"\u529b\u4e38\",\n"
"    \"npc_dota_hero_ringmaster\": \"\u767e\u620f\u5927\u738b\",\n"
"    \"npc_dota_hero_rubick\": \"\u62c9\u6bd4\u514b\",\n"
"    \"npc_dota_hero_sand_king\": \"\u6c99\u738b\",\n"
"    \"npc_dota_hero_shadow_demon\": \"\u6697\u5f71\u6076\u9b54\",\n"
"    \"npc_dota_hero_shadow_shaman\": \"\u6697\u5f71\u8428\u6ee1\",\n"
"    \"npc_dota_hero_shredder\": \"\u4f10\u6728\u673a\",\n"
"    \"npc_dota_hero_silencer\": \"\u6c89\u9ed8\u672f\u58eb\",\n"
"    \"npc_dota_hero_skeleton_king\": \"\u51a5\u9b42\u5927\u5e1d\",\n"
"    \"npc_dota_hero_skywrath_mage\": \"\u5929\u6012\u6cd5\u5e08\",\n"
"    \"npc_dota_hero_slardar\": \"\u65af\u62c9\u8fbe\",\n"
"    \"npc_dota_hero_slark\": \"\u65af\u62c9\u514b\",\n"
"    \"npc_dota_hero_snapfire\": \"\u7535\u708e\u7edd"
                        "\u624b\",\n"
"    \"npc_dota_hero_sniper\": \"\u72d9\u51fb\u624b\",\n"
"    \"npc_dota_hero_spectre\": \"\u5e7d\u9b3c\",\n"
"    \"npc_dota_hero_spirit_breaker\": \"\u88c2\u9b42\u4eba\",\n"
"    \"npc_dota_hero_storm_spirit\": \"\u98ce\u66b4\u4e4b\u7075\",\n"
"    \"npc_dota_hero_sven\": \"\u65af\u6e29\",\n"
"    \"npc_dota_hero_target_dummy\": \"\u76ee\u6807\u5047\u4eba\",\n"
"    \"npc_dota_hero_techies\": \"\u5de5\u7a0b\u5e08\",\n"
"    \"npc_dota_hero_templar_assassin\": \"\u5723\u5802\u523a\u5ba2\",\n"
"    \"npc_dota_hero_terrorblade\": \"\u6050\u6016\u5229\u5203\",\n"
"    \"npc_dota_hero_tidehunter\": \"\u6f6e\u6c50\u730e\u4eba\",\n"
"    \"npc_dota_hero_tinker\": \"\u4fee\u8865\u5320\",\n"
"    \"npc_dota_hero_tiny\": \"\u5c0f\u5c0f\",\n"
"    \"npc_dota_hero_treant\": \"\u6811\u7cbe\u536b\u58eb\",\n"
"    \"npc_dota_hero_troll_warlord\": \"\u5de8\u9b54\u6218\u5c06\",\n"
"    \"npc_dota_hero_tusk\": \"\u5de8\u7259\u6d77\u6c11\",\n"
"    \"npc_dota_hero_undying\": \"\u4e0d\u673d\u5c38\u738b\",\n"
"    "
                        "\"npc_dota_hero_ursa\": \"\u718a\u6218\u58eb\",\n"
"    \"npc_dota_hero_vengefulspirit\": \"\u590d\u4ec7\u4e4b\u9b42\",\n"
"    \"npc_dota_hero_venomancer\": \"\u5267\u6bd2\u672f\u58eb\",\n"
"    \"npc_dota_hero_viper\": \"\u51a5\u754c\u4e9a\u9f99\",\n"
"    \"npc_dota_hero_visage\": \"\u7ef4\u8428\u5409\",\n"
"    \"npc_dota_hero_void_spirit\": \"\u865a\u65e0\u4e4b\u7075\",\n"
"    \"npc_dota_hero_warlock\": \"\u672f\u58eb\",\n"
"    \"npc_dota_hero_weaver\": \"\u7f16\u7ec7\u8005\",\n"
"    \"npc_dota_hero_windrunner\": \"\u98ce\u884c\u8005\",\n"
"    \"npc_dota_hero_winter_wyvern\": \"\u5bd2\u51ac\u98de\u9f99\",\n"
"    \"npc_dota_hero_wisp\": \"\u827e\u6b27\",\n"
"    \"npc_dota_hero_witch_doctor\": \"\u5deb\u533b\",\n"
"    \"npc_dota_hero_zuus\": \"\u5b99\u65af\"\n"
"}", None))
        self.view_tabWidget.setTabText(self.view_tabWidget.indexOf(self.cn_name_tab), QCoreApplication.translate("MainWindow", u"\u4e2d\u6587\u8bd1\u540d", None))
        self.menu.setTitle(QCoreApplication.translate("MainWindow", u"\u6587\u4ef6", None))
        self.menu_2.setTitle(QCoreApplication.translate("MainWindow", u"\u7f16\u8f91", None))
        self.menu_3.setTitle(QCoreApplication.translate("MainWindow", u"\u8bbe\u7f6e", None))
        self.menu_4.setTitle(QCoreApplication.translate("MainWindow", u"\u5b57\u4f53", None))
        self.menu_5.setTitle(QCoreApplication.translate("MainWindow", u"\u4e3b\u9898", None))
        self.menu_6.setTitle(QCoreApplication.translate("MainWindow", u"\u7a97\u53e3", None))
        self.menu_7.setTitle(QCoreApplication.translate("MainWindow", u"\u811a\u672c", None))
        self.menu_9.setTitle(QCoreApplication.translate("MainWindow", u"\u811a\u672c\u76ee\u5f55", None))
        self.menu_8.setTitle(QCoreApplication.translate("MainWindow", u"\u9884\u8bbe", None))
    # retranslateUi

