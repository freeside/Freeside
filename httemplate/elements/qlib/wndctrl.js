/**
 * QLIB 1.0 Window Abstraction
 * Copyright (C) 2002 2003, Quazzle.com Serge Dolgov
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 * http://qlib.quazzle.com
 */

function QWndCtrl_center_ie4() {
    var b = this.document.body;
    this.moveTo(b.scrollLeft + Math.max(0, Math.floor((b.clientWidth -
        this.width) / 2)), b.scrollTop + 100);
}

function QWndCtrl_center_moz() {
    this.moveTo(self.pageXOffset + Math.max(0, Math.floor((self.innerWidth -
        this.width) / 2)), self.pageYOffset + 100);
}

function QWndCtrl_setEffects_ie4(fx) {
    this.effects = fx;
    with (this.wnd) {
        filters[0].enabled = (fx & 256) != 0;
        filters[1].enabled = (fx & 512) != 0;
        filters[2].enabled = (fx & 1024) != 0;
        filters[4].enabled = (fx & 2048) != 0;
    }
}

function QWndCtrl_setEffects_moz(fx) {
    this.effects = fx;
}

function QWndCtrl_setOpacity_ie4(op) {
    this.opacity = Math.max(0, Math.min(100, Math.floor(op - 0)));
    this.wnd.filters[3].opacity = this.opacity;
    this.wnd.filters[3].enabled = (this.opacity < 100);
}

function QWndCtrl_setOpacity_moz(op) {
    this.opacity = Math.max(0, Math.min(100, Math.floor(op - 0)));
    this.wnd.style.MozOpacity = this.opacity + "%";
}

function QWndCtrl_setSize_css(w, h) {
    this.wnd.style.width = (this.width = Math.floor(w - 0)) + "px";
    this.wnd.style.height = typeof(h) == "number" ? (this.height = Math.floor(h)) + "px" : "auto";
}

function QWndCtrl_setSize_ns4(w, h) {
    this.wnd.clip.width = this.width = Math.floor(w - 0);
    if (typeof(h) == "number") {
        this.wnd.clip.height = this.height = Math.floor(h);
    }
}

function QWndCtrl_focus() {
    this.setZIndex(QWndCtrl.TOPZINDEX++);
}

function QWndCtrl_setZIndex_css(z) {
    this.wnd.style.zIndex = this.zindex = z || 0;
}

function QWndCtrl_setZIndex_ns4(z) {
    this.wnd.zIndex = this.zindex = z || 0;
}

function QWndCtrl_moveTo_css(x, y) {
    this.wnd.style.left = (this.x = Math.floor(x - 0)) + "px";
    this.wnd.style.top = (this.y = Math.floor(y - 0)) + "px";
}

function QWndCtrl_moveTo_ns4(x, y) {
    this.wnd.moveTo(this.x = Math.floor(x - 0), this.y = Math.floor(y - 0));
}

function QWndCtrl_fxhandler() {
    this.fxhandler = QControl.nop;
    this.onShow(this.visible, this.tag);
}

function QWndCtrl_show_ie4(show) {
    if (this.visible != show) {
        var fx = false;
        switch (show ? this.effects & 15 : (this.effects & 240) >>> 4) {
            case 1:
                fx = this.wnd.filters[5];
                break;
            case 2:
                (fx = this.wnd.filters[6]).transition = show ? 1 : 0;
                break;
            case 3:
                (fx = this.wnd.filters[6]).transition = show ? 3 : 2;
                break;
            case 4:
                (fx = this.wnd.filters[6]).transition = show ? 5 : 4;
                break;
            case 5:
                (fx = this.wnd.filters[6]).transition = show ? 14 : 13;
                break;
            case 6:
                (fx = this.wnd.filters[6]).transition = show ? 16 : 15;
                break;
            case 7:
                (fx = this.wnd.filters[6]).transition = 12;
                break;
            case 8:
                (fx = this.wnd.filters[6]).transition = 8;
                break;
            case 9:
                (fx = this.wnd.filters[6]).transition = 9;
        }
        if (fx) {
            fx.apply();
            this.wnd.style.visibility = (this.visible = show) ? "visible" : "hidden";
            this.fxhandler = QWndCtrl_fxhandler;
            fx.play(0.3);
        } else {
            this.wnd.style.visibility = (this.visible = show) ? "visible" : "hidden";
            this.onShow(show, this.tag);
        }
    }
}

function QWndCtrl_fade_moz(op, step) {
    this._wndt = false;
    if (step) {
        op += step;
        if ((op > 0) && (op < this.opacity)) {
            this.wnd.style.MozOpacity = op + "%";
            this._wndt = setTimeout(this.name + ".fade(" + op + "," + step + ")", 50);
        } else {
            if (op <= 0) {
                this.wnd.style.visibility = "hidden";
                this.visible = false;
            }
            this.wnd.style.MozOpacity = this.opacity + "%";
            this.onShow(this.visible, this.tag);
        }
    }
}

function QWndCtrl_show_moz(show) {
    if (this.visible != show) {
        if (this._wndt) {
            clearTimeout(this._wndt);
            this._wndt = false;
        }
        var step = show ? ((this.effects & 15) == 1) && Math.floor(this.opacity / 5) :
            ((this.effects & 240) == 16) && -Math.floor(this.opacity / 5);
        if (step) {
            if (this.visible) {
                this.fade(this.opacity - 0, step);
            } else {
                this.wnd.style.MozOpacity = "0%";
                this.wnd.style.visibility = "visible";
                this.visible = true;
                this.fade(0, step);
            }
        } else {
            this.wnd.style.visibility = (this.visible = show) ? "visible" : "hidden";
            this.onShow(show, this.tag);
        }
    }
}

function QWndCtrl_show_css(show) {
    if (this.visible != show) {
        this.wnd.style.visibility = (this.visible = show) ? "visible" : "hidden";
        this.onShow(show, this.tag);
    }
}

function QWndCtrl_show_ns4(show) {
    if (this.visible != show) {
        this.wnd.visibility = (this.visible = show) ? "show" : "hidden";
        this.onShow(show, this.tag);
    }
}

function QWndCtrl_create_dom2() {
    with (this) {
        this.fxhandler = QControl.nop;
        var ie4 = document.body && document.body.filters;
        var moz = document.body && document.body.style &&
            typeof(document.body.style.MozOpacity) == "string";
        document.write('<div unselectable="on" id="' + id +
            (ie4 ? '" onfilterchange="' + name + '.fxhandler()': '') +
            '" style="position:absolute;left:' + x + 'px;top:' + y +
            'px;width:' + width + (height != null ? 'px;height:' + height : '') +
            'px;visibility:' + (visible ? 'visible' : 'hidden') +
            ';overflow:hidden' + (zindex ? ';z-index:' + zindex : '') +
            (ie4 ? ';filter:Gray(enabled=' + (effects & 256 ? '1' : '0') +
            ') Xray(enabled=' + (effects & 512 ? '1' : '0') +
            ') Invert(enabled=' + (effects & 1024 ? '1' : '0') +
            ') alpha(enabled=' + (opacity < 100 ? '1' : '0') + ',opacity=' + opacity +
            ') shadow(enabled=' + (effects & 2048 ? '1' : '0') +
            ',direction=135) BlendTrans(enabled=0) RevealTrans(enabled=0)' : '') +
            (moz && (opacity < 100) ? ';-moz-opacity:' + opacity + '%' : '') +
            '"><div unselectable="on" class="qwindow">');
        if (typeof(content) == "function") {
            this.content();
        } else {
            document.write(content);
        }
        document.write('</div></div>');
        if (this.wnd = document.getElementById ? document.getElementById(id) :
            (document.all.item ? document.all.item(id) : document.all[id])) {
            if (wnd.style) {
                ie4 = ie4 && wnd.filters;
                moz = moz && typeof(wnd.style.MozOpacity) == "string";
                this.moveTo = QWndCtrl_moveTo_css;
                this.setZIndex = QWndCtrl_setZIndex_css;
                this.focus = QWndCtrl_focus;
                this.setSize = QWndCtrl_setSize_css;
                this.show = ie4 ? QWndCtrl_show_ie4 : (moz ? QWndCtrl_show_moz : QWndCtrl_show_css);
                this.fade = moz ? QWndCtrl_fade_moz : QControl.nop;
                this.setOpacity = ie4 ? QWndCtrl_setOpacity_ie4 : (moz ? QWndCtrl_setOpacity_moz : QControl.nop);
                this.setEffects = ie4 ? QWndCtrl_setEffects_ie4 : (moz ? QWndCtrl_setEffects_moz : QControl.nop);
                this.center = self.innerWidth ? QWndCtrl_center_moz :
                    (document.body && document.body.clientWidth ? QWndCtrl_center_ie4 : QControl.nop);
            }
        }
    }
}

function QWndCtrl_create_ns4(finalize) {
    with (this) {
        if (finalize) {
            if (_wnde) {
                parent.window.onload = _wnde;
                parent.window.onload();
            }
            document.open();
            document.write('<div class="qwindow">');
            this.content();
            document.write('</div>');
            document.close();
        } else {
            document.write('<layer id="' + id + '" left="' + x + '" top="' + y +
                '" width="' + width + '" visibility="' + (visible ? 'show' : 'hidden') +
                (height != null ? '" height="' + height + '" clip="' + width + ',' + height : '') +
                (zindex ? '" z-index="' + zindex : '') + (typeof(content) != "function" ?
                '"><div class="qwindow">' + content + '</div></layer>' : '">&nbsp;</layer>'));
            if (this.window = this.wnd = document.layers[id]) {
                if (this.document = wnd.document) {
                    this.show = QWndCtrl_show_ns4;
                    this.moveTo = QWndCtrl_moveTo_ns4;
                    this.setZIndex = QWndCtrl_setZIndex_ns4;
                    this.focus = QWndCtrl_focus;
                    this.center = QWndCtrl_center_moz;
                    this.setSize = QWndCtrl_setSize_ns4;
                    if (typeof(content) == "function") {
                        this._wnde = parent.window.onload;
                        parent.window.onload = new Function(name + ".create(true)");
                    }
                }
            }
        }
    }
}

function QWndCtrl_create_na() {
    this.document.write('Object is not supported.');
    this.wnd = null;
}

function QWndCtrl_create() {
    with (this) {
        this.create = (document.getElementById || document.all) ? QWndCtrl_create_dom2 :
            (document.layers ? QWndCtrl_create_ns4 : QWndCtrl_create_na);
        create();
    }
}

function QWndCtrl() {
    this.x = this.y = 0;
    this.width = this.height = 0;
    this.content = "";
    this.visible = true;
    this.effects = 0;
    this.opacity = 100;
    this.zindex = null;
    this._wndt = this._wnde = false;
    this.create = QWndCtrl_create;
    this.show = QControl.nop;
    this.focus = QControl.nop;
    this.center = QControl.nop;
    this.moveTo = QControl.nop;
    this.setSize = QControl.nop;
    this.setOpacity = QControl.nop;
    this.setEffects = QControl.nop;
    this.setZIndex  = QControl.nop;
    this.onShow = QControl.event;
}
QWndCtrl.prototype = new QControl();
QWndCtrl.TOPZINDEX = 1000;
QWndCtrl.GRAY      = 256;
QWndCtrl.XRAY      = 512;
QWndCtrl.INVERT    = 1024;
QWndCtrl.SHADOW    = 2048;
QWndCtrl.FADEIN    = 1;
QWndCtrl.FADEOUT   = 16;
QWndCtrl.BOXIN     = 2;
QWndCtrl.BOXOUT    = 32;
QWndCtrl.CIRCLEIN  = 3;
QWndCtrl.CIRCLEOUT = 48;
QWndCtrl.WIPEIN    = 4;
QWndCtrl.WIPEOUT   = 64;
QWndCtrl.HBARNIN   = 5;
QWndCtrl.HBARNOUT  = 80;
QWndCtrl.VBARNIN   = 6;
QWndCtrl.VBARNOUT  = 96;
QWndCtrl.DISSOLVEIN  = 7;
QWndCtrl.DISSOLVEOUT = 112;
QWndCtrl.HBLINDSIN   = 8;
QWndCtrl.HBLINDSOUT  = 128;
QWndCtrl.VBLINDSIN   = 9;
QWndCtrl.VBLINDSOUT  = 144;
