/***********************************************************************
                       Masked Input version 1.1
************************************************************************
Author: Kendall Conrad
Home page: http://www.angelwatt.com/coding/masked_input.php
Created:  2008-12-16
Modified: 2010-04-14
Description:
License: This work is licensed under a Creative Commons Attribution-Share Alike
  3.0 United States License http://creativecommons.org/licenses/by-sa/3.0/us/

Argument pieces:
- elm:        [req] text input node to apply the mask on
- format:     [req] string format for the mask
- allowed:    [opt, '0123456789'] string with chars allowed to be typed
- sep:        [opt, '\/:-'] string of char(s) used as separators in mask
- typeon:     [opt, '_YMDhms'] string of chars in mask that can be typed on
- onbadkey:   [opt, null] function to run when user types a unallowed key
- badkeywait: [opt, 0] used with onbadkey. Indicates how long (in ms) to lock
  text input for onbadkey function to run
***********************************************************************/
function MaskedInput(args)
{
  if (args['elm'] === null || args['format'] === null) { return false; }
  var el     = args['elm'],
    format   = args['format'],
    allowed  = args['allowed']    || '0123456789',
    sep      = args['separator']  || '\/:-',
    open     = args['typeon']     || '_YMDhms',
    onbadkey = args['onbadkey']   || function(){},
    badwait  = args['badkeywait'] || 0;
  
  var locked = false, hold = 0;
  el.value = format;
  // Assign events
  el.onkeydown  = KeyHandlerDown;  //
  el.onkeypress = KeyHandlerPress; // add event handlers to element
  el.onkeyup    = KeyHandlerUp;    //

  function GetKey(code)
  {
    code = code || window.event, ch = '';
    var keyCode = code.which, evt = code.type;
    if (keyCode == null) { keyCode = code.keyCode; }
    if (keyCode === null) { return ''; } // no key, no play
    // deal with special keys
    switch (keyCode) {
    case 8:  ch = 'bksp'; break;
    case 46: // handle del and . both being 46
      ch = (evt == 'keydown') ? 'del' : '.'; break;
    case 16: ch = 'shift'; break;//shift
    case 0:/*CRAP*/ case 9:/*TAB*/ case 13:/*ENTER*/
      ch = 'etc'; break;
    case 37: case 38: case 39: case 40: // arrow keys
      ch = (!code.shiftKey &&
           (code.charCode != 39 && code.charCode !== undefined)) ?
        'etc' : String.fromCharCode(keyCode);
      break;
    // default to thinking it's a character or digit
    default: ch = String.fromCharCode(keyCode);
    }
    return ch;
  }
  function KeyHandlerDown(e)
  {
    e = e || event;
    if (locked) { return false; }
    var key = GetKey(e);
    if (el.value == '') { el.value = format; SetTextCursor(el,0); }
    // Only do update for bksp del
    if (key == 'bksp' || key == 'del') { Update(key); return false; }
    else if (key == 'etc' || key == 'shift') { return true; }
    else { return true; }    
  }
  function KeyHandlerPress(e)
  {
    e = e || event;
    if (locked) { return false; }
    var key = GetKey(e);
    // Check if modifier key is being pressed; command
    if (key=='etc' || e.metaKey || e.ctrlKey || e.altKey) { return true; }
    if (key != 'bksp' && key != 'del' && key != 'etc' && key != 'shift') {
      if (!GoodOnes(key)) { return false; }
      return Update(key);
    }
    else { return false; }
  }
  function KeyHandlerUp(e) { hold = 0; }
  function Update(key)
  {
    var p = GetTextCursor(el), c = el.value, val = '';
    // Handle keys now
    switch (true) {
    case (allowed.indexOf(key) != -1):
      if (++p > format.length) { return false; } // if text csor at end
      // Handle cases where user places csor before separator
      while (sep.indexOf(c.charAt(p-1)) != -1 && p <= format.length) { p++; }
      val = c.substr(0, p-1) + key + c.substr(p);
      // Move csor up a spot if next char is a separator char
      if (allowed.indexOf(c.charAt(p)) == -1
          && open.indexOf(c.charAt(p)) == -1) { p++; }
      break;
    case (key=='bksp'): // backspace
      if (--p < 0) return false; // at start of field
      // If previous char is a separator, move a little more
      while (allowed.indexOf(c.charAt(p)) == -1
             && open.indexOf(c.charAt(p)) == -1
             && p > 1) { p--; }
      val = c.substr(0, p) + format.substr(p,1) + c.substr(p+1);
      break;
    case (key=='del'): // forward delete
      if (p >= c.length) { return false; } // at end of field
      // If next char is a separator and not the end of the text field
      while (sep.indexOf(c.charAt(p)) != -1
             && c.charAt(p) != '') { p++; }
      val = c.substr(0, p) + format.substr(p,1) + c.substr(p+1);
      p++; // Move position forward
      break;
    case (key=='etc'): return true; // Catch other allowed chars
    default: return false;   // Ignore the rest
    }
    el.value = '';        // blank it first (Firefox issue)
    el.value = val;       // put updated value back in
    SetTextCursor(el, p); // Set the text cursor
    return false;
  }
  function GetTextCursor(node)
  {
    try {
      if (node.selectionStart >= 0) { return node.selectionStart; }
      else if (document.selection) {// IE
        var ntxt = node.value; // getting starting text
        var rng = document.selection.createRange();
        rng.text = '|%|';
        var start = node.value.indexOf('|%|');
        rng.moveStart('character', -3);
        rng.text = '';
        // put starting text back in,
        // fixes issue if all text was highlighted
        node.value = ntxt;
        return start;
      } return -1;
    } catch(e) { return false; }
  }
  function SetTextCursor(node, pos)
  {
    try {
      if (node.selectionStart) {
        node.focus();
        node.setSelectionRange(pos,pos);
      }
      else if (node.createTextRange) { // IE
        var rng = node.createTextRange();
        rng.move('character', pos);
        rng.select();
      }
    } catch(e) { return false; }
  }
  function GoodOnes(k)
  {
    if (allowed.indexOf(k) == -1 && k!='bksp' && k!='del' && k!='etc') {
      var p = GetTextCursor(el); // Need to ensure cursor position not lost
      locked = true; onbadkey();
      // Hold lock long enough for onbadkey function to run
      setTimeout(function(){locked=false; SetTextCursor(el,p);}, badwait);
      return false;
    } return true;
  }
  function resetField() {
    el.value = format;
  }
  function setAllowed(a) {
    allowed = a;
    resetField();
  }
  function setFormat(f) {
    format = f;
    resetField();
  }
  function setSeparator(s) {
    sep = s;
    resetField();
  }
  function setTypeon(t) {
    open = t;
    resetField();
  }
  return {
    resetField:resetField,
    setAllowed:setAllowed,
    setFormat:setFormat,
    setSeparator:setSeparator,
    setTypeon:setTypeon
  }
}
