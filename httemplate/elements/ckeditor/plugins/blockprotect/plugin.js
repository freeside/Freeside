/**
 * The "blockprotect" plugin.  Adapted from the "placeholder" plugin.
 */

(function() {
        var delim_o = '{';
        var delim_c = '}';

        var create_block = function(content, inside) {
          // fix nbsp's
          content = content.replace(/&nbsp;/gi, ' ');
          // escape the content
          var el = document.createElement('SPAN');
          // IE8 compat
          if( typeof(el.textContent) != 'undefined' ) {
            el.textContent = content;
          } else if( typeof(el.innerText) != 'undefined' ) {
            el.innerText = content;
          }
          el.setAttribute('class', 'cke_blockprotect');
          if (inside) {
            return el.innerHTML; // escapes the contents but doesn't wrap
                                 // them in a <span>
          } else {
            return el.outerHTML;
          }
        };
        var block_writeHtml = function( element ) {
          // to unescape the element contents, write it out as HTML,
          // stick that into a SPAN element, and then extract the text
          // content of that.
          var inner_writer = new CKEDITOR.htmlParser.basicWriter;
          element.writeChildrenHtml(inner_writer);

          var el = document.createElement('SPAN');
          el.innerHTML = inner_writer.getHtml();
          if( typeof(el.textContent) != 'undefined' ) {
            return el.textContent;
          } else if( typeof(el.innerText) != 'undefined' ) {
            return el.innerText;
          }
        };
        var to_protected_html = function(data) {
          var depth = 0;
          var chunk = '';
          var out = '';
          var in_tag = false;
          var p = 0; // position in the string
          while( 1 ) {
            // find the next delimiter of either kind
            var i = data.indexOf(delim_o, p);
            var j = data.indexOf(delim_c, p);
            if (i == -1 && j == -1) {
              // then there are no more delimiters
              break;
            } else if ((i < j || j == -1) && i != -1) {
              // next delimiter is an open
              // push everything from current position to 
              // the delimiter
              if ( i > p ) chunk += data.substr(p, i - p);
              p = i + 1;
              if ( depth == 0 ) {
                // we're in document text. find whether an HTML tag starts, 
                // or ends, before the next delimiter, so that we know whether
                // to output the next block in a SPAN or just as escaped text
                for(var q = 0; q < chunk.length; q++ ) {
                  if (chunk[q] == '<') in_tag = true;
                  if (chunk[q] == '>') in_tag = false;
                }

                // then output the chunk, and go to the start of the 
                // protected block
                out += chunk;
                chunk = '';
              }
              chunk += delim_o;
              depth++;
            } else if ((j < i || i == -1) && j != -1) {
              // next delimiter is a close
              if ( j > p ) chunk += data.substr(p, j - p);
              p = j + 1;
              depth--;
              chunk += delim_c;
              if ( depth == 0 ) {
                // end of a protected block
                out += create_block(chunk, in_tag);
                chunk = '';
              } else if ( depth < 0 ) {
                depth = 0;
              }
            } else {
              // can't happen
            }
          }
          // append any text after the last delimiter
          if ( depth ) {
            out += create_block(data.substr(p), in_tag);
          } else {
            out += data.substr(p);
          }
          return out;
        };

	CKEDITOR.plugins.add( 'blockprotect', {
		afterInit: function( editor ) {
			CKEDITOR.addCss( '.cke_blockprotect' +
			'{' +
					'background-color: #ffff88;' +
					( CKEDITOR.env.gecko ? 'cursor: default;' : '' ) +
				'}'
                        );
                      
                        // keep these from getting stripped out 
                        editor.filter.allow('span(cke_blockprotect)',
                                            'blockprotect', true);

                        // add filter at the front of toHtml
                        editor.on( 'toHtml',
                          function( evt ) {
                            evt.data.dataValue =
                              to_protected_html(evt.data.dataValue);
                            return evt;
                          },
                          this, null, 0
                        );

                        editor.dataProcessor.htmlFilter.addRules({
                          elements: {
                            span: function( element ) {
                              if ( element.className = 'cke_blockprotect' ) {
                                // defeat HTML escaping
                                var content = block_writeHtml(element);
                                element.writeHtml = function(writer, filter) {
                                  writer.text(content);
                                }
                              }
                            } // span function
                          } // elements
                        });
                }
        }); // plugins.add
}) ();

