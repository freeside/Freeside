/**
 * QLIB 1.0 Button Control
 * Copyright (C) 2002 2003, Quazzle.com Serge Dolgov
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 * http://qlib.quazzle.com
 */

function QButton_update() {
    with (this) {
        image.src = ((!enabled && res.imgD) || (value ? res.imgP : res.imgN)).src;
    }
}

function QButton_doEvent() {
    with (this) {
        if (enabled) {
            if (res.style == 1) {
                this.value = value ? 0 : 1;
                update();
            }
            onClick(value, tag);
        }
    }
    return false;
}

function QButton_enable(state) {
    this.enabled = state;
    this.update();
}

function QButton_set(value) {
    if (this.enabled) {
        this.value = value ? 1 : 0;
        this.update();
    }
    return true;
}

function QButton(parent, name, res, tooltip) {
    this.init(parent, name);
    if (res) {
        this.res = res;
        this.tip = tooltip || "";
        this.enabled = true;
        this.value = 0;
        this.set = QButton_set;
        this.enable = QButton_enable;
        this.update = QButton_update;
        this.doEvent = QButton_doEvent;
        this.onClick = QControl.event;
        with (this) {
            document.write('<a href="#" hidefocus="true" unselectable="on"' +
                (tip ? ' title="' + tip + '"' : '') + ' onClick="return ' + name +
                '.doEvent()" onMouseOver="' + (res.style == 2 ? name + '.set(1);' : '') +
                'window.top.status=' + name + '.tip;return true" onMouseOut="' +
                (!res.style || (res.style == 2) ? name + '.set();' : '') + 'window.top.status=\'\'"' +
                (!res.style ? ' onMouseDown="return ' + name + '.set(1)" onMouseUp="return ' + name + '.set()"' : '') +
                '><img class="qbutton" name="' + id + '" src="' + res.imgN.src + '" border="0" width="' +
                res.width + '" height="' + res.height + '"></a>');
            this.image = document.images[id] || new Image(1, 1);
        }
    } else {
        this.document.write("invalid resource");
    }
}
QButton.prototype = new QControl();
QButton.NORMAL    = 0;
QButton.CHECKBOX  = 1;
QButton.WEB       = 2;
QButton.SIGNAL    = 3;
