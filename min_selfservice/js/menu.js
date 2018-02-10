$(document).ready(function() {
	$('#menu_ul > li').hover(function(){
		$('a:first', this).addClass('hover');
		$('ul:first', this).show();
		if ($('.current_menu:first', this).length == 0) {
			$('img[src*="dropdown_arrow_white"]', this).show();
			$('img[src*="dropdown_arrow_grey"]', this).hide();
		}
	}, function(){
		$('ul:first', this).hide();
		$('a:first', this).removeClass('hover');
		if ($('.current_menu:first', this).length == 0) {
			$('img[src*="dropdown_arrow_white"]', this).hide();
			$('img[src*="dropdown_arrow_grey"]', this).show();
		}
	});
});
