/**
 * QLIB 1.0 Window Control
 * Copyright (C) 2002 2003, Quazzle.com Serge Dolgov
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 * http://qlib.quazzle.com
 */

function QWindow(parent, name, x, y, width, height, content, visible, effects, opacity, zindex) {
    this.init(parent, name);
    this.x = x - 0;
    this.y = y - 0;
    this.width = width - 0;
    this.height = (typeof(height) == "number") ? height : null;
    this.content = content;
    var j = QWindow.arguments.length;
    this.visible = (j > 7) ? visible : true;
    this.effects = (j > 8) ? effects : 0;
    this.opacity = (j > 9) ? opacity : 100;
    this.zindex  = (j > 10) ? zindex : null;
    this.create();
}
QWindow.prototype = new QWndCtrl();
