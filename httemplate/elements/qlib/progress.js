/**
 * QLIB 1.0 Progress Control
 * Copyright (C) 2002 2003, Quazzle.com Serge Dolgov
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 * http://qlib.quazzle.com
 */

function QProgress_update() {
    with (this) {
        var i = low;
        for (var j=0; j<size; j++) {
            images[j].src = i < value ? imgsrc1 : imgsrc0;
            i += delta;
        }
    }
}

function QProgress_set(value) {
    this.value = value - 0;
    this.update();
}

function QProgress_setBounds(low, high) {
    this.low = Math.min(low, high);
    this.high = Math.max(low, high);
    this.delta = (this.high - this.low) / this.size;
    this.update();
}
 
function QProgress(parent, name, res, size, style) {
    this.init(parent, name);
    if (res) {
        this.res = res;
        this.value = 0;
        this.low = 0;
        this.high = 100;
        this.size = size || 10;
        this.delta = 100 / this.size;
        this.style = style || 0;
        this.images = new Array(this.size);
        this.imgsrc0 = res.list[0] && res.list[0].src;
        this.imgsrc1 = res.list[1] && res.list[1].src;
        this.set = QProgress_set;
        this.update = QProgress_update;
        this.setBounds = QProgress_setBounds;
        with (this) {
            var hor = this.style < 2;
            var rev = this.style % 2;
            document.write('<table class="qprogress" border="0"  cellspacing="0" cellpadding="0" unselectable="on" ' +
                (hor ? 'width="' + (size * res.width) + '" height="' + res.height + '"><tr>' : 'width="' + res.width +
                '" height="' + (size * res.height) + '">'));
            for (var j=0; j<size; j++) {
                document.write((hor ? '' : '<tr>') + '<td width="' + res.width + '" height="' + res.height +
                    '" unselectable="on"><img name="' + id + (rev ? size - j - 1 : j) + '" src="' + res.list[0].src +
                    '" border="0" width="' + res.width + '" height="' + res.height + '"></td>' + (hor ? '' : '</tr>'));
            }
            document.write((hor ? '</tr>' : '') + '</table>');
            for (var j=0; j<size; j++) {
                images[j] = document.images[id + j] || new Image(1, 1);
            }
        }
    } else {
        this.document.write("invalid resource");
    }
}
QProgress.prototype = new QControl();
QProgress.NORMAL    = 0;
QProgress.REVERSE   = 1;
QProgress.FALL      = 2;
QProgress.RISE      = 3;
