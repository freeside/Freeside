/**
 * QLIB 1.0 Box Resource
 * Copyright (C) 2002 2003, Quazzle.com Serge Dolgov
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 * http://qlib.quazzle.com
 */

function QBoxRes(t, r, b, l, tc, tr, mr, br, bc, bl, ml, tl, bgcolor, bgtile, effects, opacity) { 
    var args = QBoxRes.arguments.length;
    this.T = t;
    this.R = r;
    this.B = b;
    this.L = l;
    this.TC = new Image();
    this.TC.src = tc;
    this.TR = new Image(r, t);
    this.TR.src = tr;
    this.MR = new Image();
    this.MR.src = mr;
    this.BR = new Image(r, b);
    this.BR.src = br;
    this.BC = new Image();
    this.BC.src = bc;
    this.BL = new Image(l, b);
    this.BL.src = bl;
    this.ML = new Image();
    this.ML.src = ml;
    this.TL = new Image(l, t);
    this.TL.src = tl;
    this.bgcolor = bgcolor || "#FFFFFF";
    if (bgtile) {
        this.bgtile = new Image();
        this.bgtile.src = bgtile;
    } else {
        this.bgtile = false;
    }
    this.effects = (args > 13) ? effects : null;
    this.opacity = (args > 14) ? opacity : null;
}
