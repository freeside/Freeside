/**
 * QLIB 1.0 Box Control
 * Copyright (C) 2002 2003, Quazzle.com Serge Dolgov
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 * http://qlib.quazzle.com
 */

function QBox(parent, name, res, x, y, width, height, body, visible, effects, opacity, zindex) {
    this.init(parent, name);
    if (this.res = res) {
        this.x = x - 0;
        this.y = y - 0;
        this.width = width - 0;
        this.height = (typeof(height) == "number") ? height : null;
        this.body = body || "&nbsp;";
        var j = QBox.arguments.length;
        this.visible = (j > 8) ? visible : true;
        this.effects = (j > 9) ? effects : (res.effects || 0);
        this.opacity = (j > 10) ? opacity : (res.opacity != null ? res.opacity : 100);
        this.zindex  = (j > 11) ? zindex : null;
        this.create();
    } else {
        this.document.write("invalid resource");
    }
}
QBox.prototype = new QBoxCtrl();
