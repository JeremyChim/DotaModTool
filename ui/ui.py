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
    QMenuBar, QPlainTextEdit, QSizePolicy, QStatusBar,
    QTabWidget, QVBoxLayout, QWidget)

class Ui_MainWindow(object):
    def setupUi(self, MainWindow):
        if not MainWindow.objectName():
            MainWindow.setObjectName(u"MainWindow")
        MainWindow.resize(1112, 838)
        self.action = QAction(MainWindow)
        self.action.setObjectName(u"action")
        self.load_file_action = QAction(MainWindow)
        self.load_file_action.setObjectName(u"load_file_action")
        self.save_file_action = QAction(MainWindow)
        self.save_file_action.setObjectName(u"save_file_action")
        self.reload_file_action = QAction(MainWindow)
        self.reload_file_action.setObjectName(u"reload_file_action")
        self.action_2 = QAction(MainWindow)
        self.action_2.setObjectName(u"action_2")
        self.action_3 = QAction(MainWindow)
        self.action_3.setObjectName(u"action_3")
        self.centralwidget = QWidget(MainWindow)
        self.centralwidget.setObjectName(u"centralwidget")
        self.horizontalLayout_5 = QHBoxLayout(self.centralwidget)
        self.horizontalLayout_5.setObjectName(u"horizontalLayout_5")
        self.frame_3 = QFrame(self.centralwidget)
        self.frame_3.setObjectName(u"frame_3")
        self.frame_3.setFrameShape(QFrame.StyledPanel)
        self.frame_3.setFrameShadow(QFrame.Raised)
        self.horizontalLayout_4 = QHBoxLayout(self.frame_3)
        self.horizontalLayout_4.setSpacing(0)
        self.horizontalLayout_4.setObjectName(u"horizontalLayout_4")
        self.horizontalLayout_4.setContentsMargins(0, 0, 0, 0)
        self.frame = QFrame(self.frame_3)
        self.frame.setObjectName(u"frame")
        self.frame.setMaximumSize(QSize(255, 16777215))
        self.frame.setFrameShape(QFrame.StyledPanel)
        self.frame.setFrameShadow(QFrame.Raised)
        self.verticalLayout_2 = QVBoxLayout(self.frame)
        self.verticalLayout_2.setObjectName(u"verticalLayout_2")
        self.search_lineEdit = QLineEdit(self.frame)
        self.search_lineEdit.setObjectName(u"search_lineEdit")

        self.verticalLayout_2.addWidget(self.search_lineEdit)

        self.heroFiles_listWidget = QListWidget(self.frame)
        QListWidgetItem(self.heroFiles_listWidget)
        self.heroFiles_listWidget.setObjectName(u"heroFiles_listWidget")

        self.verticalLayout_2.addWidget(self.heroFiles_listWidget)


        self.horizontalLayout_4.addWidget(self.frame)

        self.frame_2 = QFrame(self.frame_3)
        self.frame_2.setObjectName(u"frame_2")
        self.frame_2.setFrameShape(QFrame.StyledPanel)
        self.frame_2.setFrameShadow(QFrame.Raised)
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
        QListWidgetItem(self.content_listWidget)
        QListWidgetItem(self.content_listWidget)
        self.content_listWidget.setObjectName(u"content_listWidget")

        self.horizontalLayout.addWidget(self.content_listWidget)

        self.view_tabWidget.addTab(self.line_tab, "")
        self.text_tab = QWidget()
        self.text_tab.setObjectName(u"text_tab")
        self.horizontalLayout_2 = QHBoxLayout(self.text_tab)
        self.horizontalLayout_2.setObjectName(u"horizontalLayout_2")
        self.content_plainTextEdit = QPlainTextEdit(self.text_tab)
        self.content_plainTextEdit.setObjectName(u"content_plainTextEdit")

        self.horizontalLayout_2.addWidget(self.content_plainTextEdit)

        self.view_tabWidget.addTab(self.text_tab, "")

        self.horizontalLayout_3.addWidget(self.view_tabWidget)


        self.horizontalLayout_4.addWidget(self.frame_2)


        self.horizontalLayout_5.addWidget(self.frame_3)

        MainWindow.setCentralWidget(self.centralwidget)
        self.menubar = QMenuBar(MainWindow)
        self.menubar.setObjectName(u"menubar")
        self.menubar.setGeometry(QRect(0, 0, 1112, 23))
        self.menu = QMenu(self.menubar)
        self.menu.setObjectName(u"menu")
        self.menu_2 = QMenu(self.menubar)
        self.menu_2.setObjectName(u"menu_2")
        self.menu_3 = QMenu(self.menubar)
        self.menu_3.setObjectName(u"menu_3")
        self.menu_4 = QMenu(self.menubar)
        self.menu_4.setObjectName(u"menu_4")
        self.menu_5 = QMenu(self.menubar)
        self.menu_5.setObjectName(u"menu_5")
        MainWindow.setMenuBar(self.menubar)
        self.statusbar = QStatusBar(MainWindow)
        self.statusbar.setObjectName(u"statusbar")
        MainWindow.setStatusBar(self.statusbar)

        self.menubar.addAction(self.menu.menuAction())
        self.menubar.addAction(self.menu_3.menuAction())
        self.menubar.addAction(self.menu_4.menuAction())
        self.menubar.addAction(self.menu_5.menuAction())
        self.menubar.addAction(self.menu_2.menuAction())
        self.menu.addAction(self.load_file_action)
        self.menu.addAction(self.save_file_action)
        self.menu.addAction(self.reload_file_action)
        self.menu_2.addAction(self.action_2)
        self.menu_2.addAction(self.action_3)
        self.menu_4.addAction(self.action)

        self.retranslateUi(MainWindow)

        self.view_tabWidget.setCurrentIndex(0)


        QMetaObject.connectSlotsByName(MainWindow)
    # setupUi

    def retranslateUi(self, MainWindow):
        MainWindow.setWindowTitle(QCoreApplication.translate("MainWindow", u"MainWindow", None))
        self.action.setText(QCoreApplication.translate("MainWindow", u"\u7f6e\u9876", None))
        self.load_file_action.setText(QCoreApplication.translate("MainWindow", u"\u8f7d\u5165", None))
        self.save_file_action.setText(QCoreApplication.translate("MainWindow", u"\u4fdd\u5b58", None))
        self.reload_file_action.setText(QCoreApplication.translate("MainWindow", u"\u91cd\u8f7d", None))
        self.action_2.setText(QCoreApplication.translate("MainWindow", u"\u83b7\u53d6\u9009\u4e2d\u884c", None))
        self.action_3.setText(QCoreApplication.translate("MainWindow", u"\u5199\u5165\u9009\u4e2d\u884c", None))
        self.search_lineEdit.setText(QCoreApplication.translate("MainWindow", u"\u641c\u7d22\u680f", None))

        __sortingEnabled = self.heroFiles_listWidget.isSortingEnabled()
        self.heroFiles_listWidget.setSortingEnabled(False)
        ___qlistwidgetitem = self.heroFiles_listWidget.item(0)
        ___qlistwidgetitem.setText(QCoreApplication.translate("MainWindow", u"\u6587\u4ef6\u540d.txt", None));
        self.heroFiles_listWidget.setSortingEnabled(__sortingEnabled)


        __sortingEnabled1 = self.content_listWidget.isSortingEnabled()
        self.content_listWidget.setSortingEnabled(False)
        ___qlistwidgetitem1 = self.content_listWidget.item(0)
        ___qlistwidgetitem1.setText(QCoreApplication.translate("MainWindow", u"\u6587\u672c\u7b2c1\u884c", None));
        ___qlistwidgetitem2 = self.content_listWidget.item(1)
        ___qlistwidgetitem2.setText(QCoreApplication.translate("MainWindow", u"\u6587\u672c\u7b2c2\u884c", None));
        ___qlistwidgetitem3 = self.content_listWidget.item(2)
        ___qlistwidgetitem3.setText(QCoreApplication.translate("MainWindow", u"\u6587\u672c\u7b2c3\u884c", None));
        self.content_listWidget.setSortingEnabled(__sortingEnabled1)

        self.view_tabWidget.setTabText(self.view_tabWidget.indexOf(self.line_tab), QCoreApplication.translate("MainWindow", u"\u884c\u89c6\u56fe", None))
        self.content_plainTextEdit.setPlainText(QCoreApplication.translate("MainWindow", u"\u6587\u672c\u7b2c1\u884c\n"
"\u6587\u672c\u7b2c2\u884c\n"
"\u6587\u672c\u7b2c3\u884c", None))
        self.view_tabWidget.setTabText(self.view_tabWidget.indexOf(self.text_tab), QCoreApplication.translate("MainWindow", u"\u6587\u672c\u89c6\u56fe", None))
        self.menu.setTitle(QCoreApplication.translate("MainWindow", u"\u6587\u4ef6", None))
        self.menu_2.setTitle(QCoreApplication.translate("MainWindow", u"\u64cd\u4f5c", None))
        self.menu_3.setTitle(QCoreApplication.translate("MainWindow", u"\u7f16\u8f91", None))
        self.menu_4.setTitle(QCoreApplication.translate("MainWindow", u"\u7a97\u53e3", None))
        self.menu_5.setTitle(QCoreApplication.translate("MainWindow", u"\u8bbe\u7f6e", None))
    # retranslateUi

