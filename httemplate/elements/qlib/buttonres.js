/**
 * QLIB 1.0 Button Resource
 * Copyright (C) 2002 2003, Quazzle.com Serge Dolgov
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 * http://qlib.quazzle.com
 */

function QButtonRes(style, width, height, normal, pressed, disabled) {
    this.style = style;
    this.width = width;
    this.height = height;
    this.imgN = new Image(width, height);
    this.imgN.src = normal;
    this.imgP = new Image(width, height);
    this.imgP.src = pressed;
    if (disabled) {
        this.imgD = new Image(width, height);
        this.imgD.src = disabled;
    }
}
