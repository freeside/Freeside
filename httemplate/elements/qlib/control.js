/**
 * QLIB 1.0 Base Abstract Control
 * Copyright (C) 2002 2003, Quazzle.com Serge Dolgov
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 * http://qlib.quazzle.com
 */

function QControl_init(parent, name) {
    this.parent = parent || self;
    this.window = (parent && parent.window) || self;
    this.document = (parent && parent.document) || self.document;
    this.name = (parent && parent.name) ? (parent.name + "." + name) : ("self." + name);
    this.id = "Q";
    var h = this.hash(this.name);
    for (var j=0; j<8; j++) {
        this.id += QControl.HEXTABLE.charAt(h & 15);
        h >>>= 4;
    }
}

function QControl_hash(str) {
    var h = 0;
    if (str) {
        for (var j=str.length-1; j>=0; j--) {
            h ^= QControl.ANTABLE.indexOf(str.charAt(j)) + 1;
            for (var i=0; i<3; i++) {
                var m = (h = h<<7 | h>>>25) & 150994944;
                h ^= m ? (m == 150994944 ? 1 : 0) : 1;
            }
        }
    }
    return h;
}

function QControl_nop() {
}

function QControl() {
    this.init = QControl_init;
    this.hash = QControl_hash;
    this.window = self;
    this.document = self.document;
    this.tag = null;
}
QControl.ANTABLE  = "w5Q2KkFts3deLIPg8Nynu_JAUBZ9YxmH1XW47oDpa6lcjMRfi0CrhbGSOTvqzEV";
QControl.HEXTABLE = "0123456789ABCDEF";
QControl.nop = QControl_nop;
QControl.event = QControl_nop;
