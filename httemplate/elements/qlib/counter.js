/**
 * QLIB 1.0 Animated Digital Counter
 * Copyright (C) 2002 2003, Quazzle.com Serge Dolgov
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 * http://qlib.quazzle.com
 */

function QCounter_update() {
    with (this) {
        var v = Math.max(value, 0);
        var mod;
        for (var j=0; j<size; j++) {
            mod = Math.floor(v % 10);
            images[j].src = (v >= 1) || (!j) ? res.list[mod].src : res.list[10].src;
            v /= 10;
        }
    }
}

function QCounter_count(value, step) {
    this._cntt = false;
    this.value += step; 
    if ((step * (this.value - value)) >= 0) {
        this.value = value - 0;  // convert to number
    } else {
        this._cntt = setTimeout(this.name + ".count(" + value + "," + step + ")", 50);
    }
    this.update();
}
         
function QCounter_set(value) {
    this.setval = value;
    if (value != this.value) {
        if (this._cntt) {
            clearTimeout(this._cntt);
            this._cntt = false;
        }
        var dv = value - this.value;
        if (this.effect == 2) {
            dv = dv / Math.min(10, Math.abs(dv));
        } else if (this.effect == 3) {
            dv = dv / Math.abs(dv);
        }
        this.count(value, dv);
    }
}

function QCounter(parent, name, res, size, effect) {
    this.init(parent, name);
    if (res) {
        this.res = res;
        this.setval = this.value = 0;
        this.size = size || 4;
        this.effect = effect || 2;
        this._cntt = false;
        this.images = new Array(this.size);
        this.set = QCounter_set;
        this.update = QCounter_update;
        this.count = QCounter_count;
        with (this) {
            document.write('<table class="qcounter" width="' + (res.width * size) + '" height="' + res.height +
                '" border="0" cellspacing="0" cellpadding="0" unselectable="on"><tr>');
            for (var j=(size - 1); j>=0; j--) {
                document.write('<td width="' + res.width + '" height="' + res.height +
                    '" unselectable="on"><img name="' + id + j + '" src="' + (j ? res.list[10].src : res.list[0].src) +
                    '" border="0" width="' + res.width + '" height="' + res.height + '"></td>');
                images[j] = document.images[id + j] || new Image(1, 1);
            }
            document.write('</tr></table>');
        }
    } else {
        this.document.write("invalid resource");
    }
}
QCounter.prototype = new QControl();
QCounter.INSTANT   = 1;
QCounter.FAST      = 2;
QCounter.SLOW      = 3;
