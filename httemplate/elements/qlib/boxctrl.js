/**
 * QLIB 1.0 Box Abstraction
 * Copyright (C) 2002 2003, Quazzle.com Serge Dolgov
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 * http://qlib.quazzle.com
 */

function QBoxCtrl_content() {
    with (this) {
        if (res) {
            this.cwidth = width - res.L - res.R - 8;
            this.cheight = height && (height - res.T - res.B - 8);
            var ec = '"><table border="0" cellspacing="0" cellpadding="0"><tr><td></td></tr></table></td>';
            document.write('<table class="qbox" border="0" cellspacing="0" cellpadding="0" width="' +
                (width - 8) + (height != null ? '" height="' + (height - 8) : '') + '"><tr><td width="' +
                res.L + '" height="' + res.T + '"><img src="' + res.TL.src + '" border="0" width="' +
                res.L + '" height="' + res.T + '"></td><td width="' + cwidth + '" height="' + res.T +
                '" background="' + res.TC.src + ec + '<td width="' + res.R + '" height="' + res.T +
                '"><img src="' + res.TR.src + '" border="0" width="' + res.R + '" height="' + res.T +
                '"></td></tr><tr><td width="' + res.L + (cheight != null ? '" height="' + cheight : '') +
                '" background="' + res.ML.src + ec + '<td width="' + cwidth + '" bgcolor="' + res.bgcolor +
                (cheight != null ? '" height="' + cheight : '') + (res.bgtile ? '" background="' +
                res.bgtile.src : '') + '" align="left" valign="top" class="body" unselectable="on">');
                if (typeof(body) == "function") {
                    this.body();
                } else {
                    document.write(body);
                }
            document.write('</td><td width="' + res.R + (cheight != null ? '" height="' + cheight : '') +
                '" background="' + res.MR.src + ec + '</tr><tr><td width="' + res.L + '" height="' + res.B +
                '"><img src="' + res.BL.src + '" border="0" width="' + res.L + '" height="' + res.B +
                '"></td><td width="' + cwidth + '" height="' + res.B + '" background="' + res.BC.src + ec +
                '<td width="' + res.R + '" height="' + res.B + '"><img src="' + res.BR.src +
                '" border="0" width="' + res.R + '" height="' + res.B + '"></td></tr></table><br>');
        }
    }
}

function QBoxCtrl() {
    this.res = false;
    this.body = "&nbsp;";
    this.cwidth = this.cheight = 0;
    this.content = QBoxCtrl_content;
}
QBoxCtrl.prototype = new QWndCtrl();
