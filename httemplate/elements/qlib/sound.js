/**
 * QLIB 1.0 Preloaded Sound
 * Copyright (C) 2002 2003, Quazzle.com Serge Dolgov
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 * http://qlib.quazzle.com
 */

function QSound_play(loop) {
    this._out.loop = loop || 0;
    this._out.src = this._buf.src;
}

function QSound_stop() {
    this._out.loop = 0;
    this._out.src = "";
}

function QSound_setVolume(volume) {
    this._out.volume = this.volume = volume;
}
 
function QSound(parent, name, src, volume) {
    this.init(parent, name);
    this.volume = volume || 0;
    this.play = this.stop = this.setVolume = QControl.nop;
    with (this) {
        document.write('<bgsound id="' + id + '" src="" volume="' + volume + '">');
        if (document.all && document.all.item) {
            this._out = document.all.item(id);
            if (_out && (typeof _out.src != "undefined") && (_out.volume === volume)) {
                document.write('<bgsound id="b' + id + '" src="' + src + '" volume="-10000">');
                this._buf = document.all.item("b" + id);
                if (_buf) {
                    this.play = QSound_play;
                    this.stop = QSound_stop;
                    this.setVolume = QSound_setVolume;

                    _out.onreadystatechange = new Function("alert(0)");
                }
            }
        }
    }
}
QSound.prototype = new QControl();
