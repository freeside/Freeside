/**
 * QLIB 1.0 Text Label
 * Copyright (C) 2002 2003, Quazzle.com Serge Dolgov
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 * http://qlib.quazzle.com
 */

function QLabel_set_ie(value) {
    this.label.innerText = (this.value = value) || "\xA0";
}

function QLabel_set_dom2(value) {
    with (this.label) {
        replaceChild(this.document.createTextNode((this.value = value) || "\xA0"), firstChild);
    }
}

function QLabel_set_ns4(value) {
    this.value = value || "";
    with (this) {
        document.open();
        document.write('<div class="qlabel">' + (clickable ? '<a href="#" title="' + tooltip + '" onClick="return ' +
            name + '.doEvent()" onMouseOut="window.top.status=\'\'" onMouseOver="window.top.status=' + name +
            '.tooltip;return true">' + value + '</a>' : value) + '</div>');
        document.close();
    }
}

function QLabel_doEvent() {
    this.onClick(this.value, this.tag);
    return false;
}

function QLabel(parent, name, value, clickable, tooltip) {
    this.init(parent, name);
    this.value = value || "";
    this.clickable = clickable || false;
    this.tooltip = tooltip || "";
    this.doEvent = QLabel_doEvent;
    this.onClick = QControl.event;
    with (this) {
        if (document.getElementById || document.all) {
            document.write(clickable ? '<div class="qlabel" unselectable="on"><a id="' + id + '" href="#" title="' +
                tooltip + '" onClick="return ' + name + '.doEvent()" onMouseOver="window.top.status=' + name +
                '.tooltip;return true" onMouseOut="window.top.status=\'\'" hidefocus="true" unselectable="on">' +
                (value || '&nbsp;') + '</a></div>' : '<div id="' + id + '" class="qlabel" unselectable="on">' +
                (value || '&nbsp;') + '</div>');
            this.label = document.getElementById ? document.getElementById(id) :
                (document.all.item ? document.all.item(id) : document.all[id]);
            this.set = (label && (label.innerText ? QLabel_set_ie :
                (label.replaceChild && QLabel_set_dom2))) || QControl.nop;
        } else if (document.layers) {
            var suffix = "";
            for (var j=value.length; j<QLabel.TEXTQUOTA; j++) suffix += " &nbsp;";
            document.write('<div><ilayer id="i' + id + '"><layer id="' + id + '"><div class="qlabel">' +
                (clickable ? '<a href="#" title="' + tooltip + '" onClick="return ' + name +
                '.doEvent()" onMouseOver="window.top.status=' + name +
                '.tooltip;return true" onMouseOut="window.top.status=\'\'">' + value + suffix + '</a>' :
                value + suffix) + '</div></layer></ilayer></div>');
            this.label = (this.label = document.layers["i" + id]) && label.document.layers[id];
            this.document = label && label.document;
            this.set = (label && document) ? QLabel_set_ns4 : QControl.nop;
        } else {
            document.write("Object is not supported");
        }
    }
}
QLabel.prototype = new QControl();
QLabel.TEXTQUOTA = 50;
