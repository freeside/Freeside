/**
 * QLIB 1.0 ImageList Resource
 * Copyright (C) 2002 2003, Quazzle.com Serge Dolgov
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 * http://qlib.quazzle.com
 */

function QImageList(width, height) {
    var len = QImageList.arguments.length - 2;
    if (len > 0) {
        this.list = new Array(len);
        this.length = len;
        this.width = width;
        this.height = height;
        var im;
        for (var j=0; j<len; j++) {
            im = new Image(width, height);
            im.src = QImageList.arguments[j + 2];
            this.list[j] = im;
        }
    }
}