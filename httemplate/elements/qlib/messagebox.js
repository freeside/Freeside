/**
 * QLIB 1.0 Message Box Control
 * Copyright (C) 2002 2003, Quazzle.com Serge Dolgov
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 * http://qlib.quazzle.com
 */

function QMessageBox_alert(msg) {
    if (typeof(msg) == "string") {
        this.label.set(this.value = msg);
    }
    this.center();
    this.focus();
    this.show(true);
}

function QMessageBox_close() {
    with (this.parent) {
        if (!onClose(tag)) show(false);
    }
}

function QMessageBox_body() {
    with (this) {
        document.write('<table border="0" width="' + cwidth + '"><tr><td align="left" valign="top" unselectable="on">');
        this.label = new QLabel(this, "label", value);
        document.write('</td></tr><tr><td height="' + (bres.height + 14) + '" align="center" valign="bottom" unselectable="on">');
        this.button = new QButton(this, "button", bres, "Close");
        document.write('</td></tr></table>');
        button.onClick = QMessageBox_close;
    }
}

function QMessageBox(parent, name, box, btn, msg, effects, opacity) {
    this.init(parent, name);
    if ((this.res = box) && (this.bres = btn)) {
        this.value = typeof(msg) == "string" ? msg : "";
        this.width = Math.max(200, Math.floor(Math.sqrt(555 * this.value.length)));
        this.height = null;
        this.x = this.y = 0;
        this.visible = false;
        this.zindex = null;
        this.body = QMessageBox_body;
        var j = QMessageBox.arguments.length;
        this.effects = j > 5 ? effects : (box.effects != null ? box.effects : 0);
        this.opacity = j > 6 ? opacity : (box.opacity != null ? box.opacity : 100);
        this.create();
        this.alert = QMessageBox_alert;
        this.onClose = QControl.event;
    } else {
        this.document.write("invalid resource");
    }
}
QMessageBox.prototype = new QBoxCtrl();
