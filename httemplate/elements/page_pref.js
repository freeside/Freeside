function set_page_pref(prefname, tablenum, prefvalue, success) {
  jQuery.post( window.fsurl + 'misc/process/set_page_pref.html',
      { path: window.request_comp_path,
        name: prefname,
        num: tablenum,
        value: prefvalue
      },
      success
  );
}
