/**
 * QLIB 1.0 Sprite Object
 * Copyright (C) 2002 2003, Quazzle.com Serge Dolgov
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 * http://qlib.quazzle.com
 */

function QSprite_load(src) {
    if (src) {
        this.face = new Image(this.cwidth, this.cheight);
        this.face.src = src;
        this.valid = false;
    }
}
 
function QSprite_show(show) {
    if (show && !this.valid && this.face.complete) {
        this._img.src = this.face.src;
        this.valid = true;
    }
    this._show(show);
}

function QSprite_moveTo(x, y) {
    this.stop();
    this._move(x, y);
}

function QSprite_slideTo(x, y) {
    this.stop();
    if (this.visible) {
        this.doSlide(++this._spro, x, y);
    } else {
        this.moveTo(x, y);
    }
}

function QSprite_shake() {
    this.stop();
    if (this.visible) {
        this.doShake(++this._spro, 0, this.x, this.y);
    }
}

function QSprite_stop() {
    this._spro++;
    if (this._sprt) {
        clearTimeout(this._sprt);
        this._sprt = false;
    }
}

function QSprite_doSlide(id, x, y) {
    if (this._spro == id) {
        this._sprt = false;
        var dx = Math.round(x - this.x);
        var dy = Math.round(y - this.y);
        if (dx || dy) {
            if (dx) dx = dx > 0 ? Math.ceil(dx/4) : Math.floor(dx/4);
            if (dy) dy = dy > 0 ? Math.ceil(dy/4) : Math.floor(dy/4);
            this._move(this.x + dx, this.y + dy);
            this._sprt = setTimeout(this.name + ".doSlide(" + id + "," + x + "," + y + ")", 30);
        } else {
            this._move(x, y);
        }
    }
}

function QSprite_doShake(id, phase, x, y) {
    if (this._spro == id) {
        this._sprt = false;
        if (phase < 20) {
            var m = 3 * Math.sin(.16 * phase);
            this._move(x + m * Math.sin(phase), y + m * Math.cos(phase));
            this._sprt = setTimeout(this.name + ".doShake(" + id + "," + (++phase) + "," + x + "," + y + ")", 20);
        } else {
            this._move(x, y);
        }
    }
}

function QSprite_doClick() {
    if (!this._sprt) {
        this.onClick(this.tag);
    }
    return false;
}

function QSprite(parent, name, x, y, width, height, src, visible, effects, opacity, zindex) {
    this.init(parent, name);
    this.x = x - 0;
    this.y = y - 0;
    this.width = (this.cwidth = width - 0) + 8;
    this.height = (this.cheight = height - 0) + 8;
    var j = QSprite.arguments.length;
    this.visible = (j > 7) ? visible : true;
    this.effects = (j > 8) ? effects : 0;
    this.opacity = (j > 9) ? opacity : 100;
    this.zindex  = (j > 10) ? zindex : null;
    this.valid = !!src;
    this.content = '<a href="#" title="" onclick="return false" onmousedown="return ' + this.name +
        '.doClick()" onmouseover="window.top.status=\'\';return true" hidefocus="true" unselectable="on"><img name="' +
        this.id + '" src="' + (src || '') + '" border="0" width="' + this.cwidth + '" height="' + this.cheight +
        '" alt="" unselectable="on"></a>';
    this.doClick = QSprite_doClick;
    this.doSlide = QSprite_doSlide;
    this.doShake = QSprite_doShake;
    this.onClick = QControl.event;
    this.create();
    this.face = this._img = this.document.images[this.id] || new Image(1, 1);
    this._spro = 0;
    this._sprt = false;
    this._show = this.show;
    this._move = this.moveTo;
    this.load = QSprite_load;
    this.show = QSprite_show;
    this.moveTo = QSprite_moveTo;
    this.slideTo = QSprite_slideTo;
    this.shake = QSprite_shake;
    this.stop = QSprite_stop;
}
QSprite.prototype = new QWndCtrl();
