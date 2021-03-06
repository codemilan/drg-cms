/*
# Copyright (c) 2012+ Damjan Rems
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

/*******************************************************************
 * Find and extract parameters value from url
 *******************************************************************/
$.getUrlParam = function(name) {
  var results = new RegExp('[\\?&]' + name + '=([^&#]*)').exec(window.location.href);
  return results[1] || 0;
};

/*******************************************************************
 * Dump all attributes to console
 *******************************************************************/
dumpAttributes = function(obj) {
  console.log('Dumping attributes:');
  $.each(obj.attributes, function() {
    console.log(this.name,this.value);
  });
};

/*******************************************************************
 * Trying to remove background from iframe element. It is not yet working.
 *******************************************************************/
remove_background_from_iframe = function(obj) {
  var head = obj.head;
  var css = '<style type="text/css">' +
            'body{background: none; background-picture:none; } ' +
            '</style>';
  $(head).append(css);    
};
  
/*******************************************************************
 * Activate jquery UI tooltip. This needs jquery.ui >= 1.9
 *******************************************************************/
/*
$(function() {
  $( document ).tooltip();
});
*/

/*******************************************************************
 * Process json result from ajax call and update parts of document.
 * I invented my own protocol which is arguably good or wrong.
 * 
 * Protocol consists of operation and value which are returned as json by
 * called controller. Controller will return an ajax call usually like this:
 *    render json: {operation: value}.to_json
 *    
 * Operation is further divided into source and determinator which are divided by underline char.
 *    render json: {#div_status: 'OK!'}.to_json
 * will replace html in div="status" with value 'OK!'. Source is '#div' determinator is 'status'.
 * 
 * Possible operators are:
 *  record_name: will replace value of record[name] field on a form with supplied value
 *
 *  msg_error: will display error message.
 *  msg_warn: will display warning message.
 *  msg_info: will display informational message.
 *  
 *  #div_divname : will replace divname with value
 *  #div+_divname : will append value to divname
 *  #+div_divname : will prepend value to divname 
 *  .div_classname : will replace all accurencess of classname with value
 *  .+div_classname : will prepend value to all accurencess of classname
 *  .div+_classname : will append value to all accurencess of classname
 *  
 *  url_: Will force loading of url supplied in value into same window
 *  window_: Will force loading of url supplied in value into new window
 *  reload_: Will reload current window
 *  
 *  Operations can be chained and are executed sequentialy.
 *    render json: {'window_' => "/dokument.pdf", 'reload_' => 1}.to_json
 *  will open /dokument.pdf in new window and reload current window.
 *  
 *    render json: {'record_name' => "Damjan", 'record_surname' => 'Rems'}.to_json
 *  will replace values of two fields on the form.
 *******************************************************************/
process_json_result = function(json) {
  var c = '';
  $.each(json, function(key, val) {
    i = key.search('_');
    if (i > 1) {
      oper = key.substring(0,i);
      what = key.substring(i+1,100);
      switch (oper) {
      /* update field */
      case 'record':
        $('#'+key).val(val);
        break;
      /* display message */  
      case 'msg': 
        selector = 'dc-form-' + what;
        if ($('.'+selector).length == 0) {
          val = '<div class="' + selector + '">' + val + '</div>';
          $('.dc-title').after(val);
      } else
          $('.'+selector).html(val);
        break;
      /* update div */
      case '#div+':
        $('#'+what).append(val);
        break;
      case '#+div':
        $('#'+what).prepend(val);
        break;
      case '#div':
        $('#'+what).html(val);
        break;
      case '.div+':
        $('.'+what).append(val);
        break;
      case '.+div':
        $('.'+what).prepend(val);
        break;
      case '.div':
        $('.'+what).html(val);
        break;
      /* goto url */
      case 'url':
        window.location.href = val;
        break;
      case 'alert':
        alert(val);
        break;
      case 'window':
        w = window.open(val, what);
        w.focus();        
        break;
      case 'reload':
        location.reload(); 
        break;
      }
    }
  });
};

/*******************************************************************
 * Will reload window
 *******************************************************************/
function dc_reload_window() {
  location.reload(); 
}

/*******************************************************************
 * I would like to resize window to display whole tab. This will
 * be a job for someone with better javascrip knowledge.
 *******************************************************************/
function dc_resize_to_tab() {
  dom = $('iframe');
  if (dom.contentWindow.document.body.offsetHeight > 10) {
    alert(dom.style.height);
    dom.style.height = (dom.contentWindow.document.body.offsetHeight + 30) + 'px'; 
// scroll to top
//    $('#' + iframe_name).dc_scroll_view();
  }
};

/*******************************************************************
 * Will scroll to position on the screen. This is replacement for 
 * location.hash, which doesn't work in Chrome.
 * 
 * Thanks goes to: http://web-design-weekly.com/snippets/scroll-to-position-with-jquery/
 *******************************************************************/
$.fn.dc_scroll_view = function () { 
  return this.each(function () {
    $('html, body').animate({
      scrollTop: $(this).offset().top - 20
    }, 500);
  });
};

/*******************************************************************
 * 
 *******************************************************************/
$(document).ready( function() {
 /*******************************************************************
  * Register ad clicks
  *******************************************************************/
  $('a.link_to_track').click(function() {
    $.post('/dc_common/ad_click', { id: this.id });
    return true;
  });
  
 /*******************************************************************
  * Popup or close CMS edit menu on icon click
  *******************************************************************/
  $('.drgcms_popmenu').on('click',function(e) { 
    $(e.target).parents('dl:first').find('ul').toggleClass('div-hidden'); 
  });

  /*******************************************************************
  * Popup CMS edit menu option clicked
  *******************************************************************/
  $('.drgcms_popmenu_item').on('click',function(e) {
    url = e.target.getAttribute("data-url");
    $('#iframe_cms').attr('src', url);
//    $('#iframe_cms').width(1000).height(1000);
// scroll to top of page and hide menu    
    window.scrollTo(0,0);
    $(e.target).parents('dl:first').find('ul').toggleClass('div-hidden');
  });

 /*******************************************************************
  * Sort action clicked on cmsedit
  *******************************************************************/
  $('.drgcms_sort').change( function(e) {
    table = e.target.getAttribute("data-table");
    sort = e.target.value; 
    e.target.value = null;
    window.location.href = "/cmsedit?sort=" + sort + "&table=" + table;
  });
  
 /*******************************************************************
  * Tab clicked on form. Hide old and show selected div.
  *******************************************************************/
  $('.dc-form-li').on('click', function(e) { 
/* find li with dc-form-li-selected class and remove it. This will deselect tab */ 
    var old_id = null;
    $(e.target).parents('ul').find('li').each( function() {
/*      console.debug( $(this) );  */
      if ($(this).hasClass('dc-form-li-selected')) {
/* ignore if tab is already selected */        
        if ($(this) !== $(e.target)) {
          $(this).toggleClass('dc-form-li-selected');
          $(e.target).toggleClass('dc-form-li-selected');
          old_id = this.getAttribute("data-div");
        }
        return false;
      }
        
    }); /* show selected data div */    
    if (old_id !== null) {
      $('#data_' + old_id).toggleClass('div-hidden');
      $('#data_' + e.target.getAttribute("data-div")).toggleClass('div-hidden');
    }
//    dc_resize_to_tab();
  });  

/*******************************************************************
 * Resize iframe_cms to the size of its contents. Make at least 500 px hight
 * unless on initial display.
 *******************************************************************/
  $('#iframe_cms').load( function() {
//    alert('bla 1');
    new_height = this.contentWindow.document.body.offsetHeight + 50;
    if (new_height < 500 & new_height > 60) new_height = 500;
    this.style.height = new_height + 'px'; 
//    remove_background_from_iframe(this.contentWindow.document);
    $('#iframe_cms').dc_scroll_view();
  });

/*******************************************************************
 * Same goes for editiframe. Resize it + 30px
 * unless on initial display with no data 
 *******************************************************************/
  $('#iframe_edit').load( function() {
//    console.log(this.contentWindow.document.body.offsetHeight);
    if (this.contentWindow.document.body.offsetHeight > 10) {
      this.style.height = (this.contentWindow.document.body.offsetHeight + 30) + 'px'; 
// scroll to it
      $('#iframe_edit').dc_scroll_view();
    }
//    remove_background_from_iframe(this.contentWindow.document);
  });
  
/*******************************************************************
 * Process Ajax call on cmsedit form actions
 *******************************************************************/
  $('.dc-link-ajax').on('click', function(e) {
    var target = e.target;
//    if (e.target.src !== undefined) {
//      target = e.target.parent(); // picture
//    };
//    dumpAttributes(target);
    req = target.getAttribute("data-request");
/* Get some values from elements on the page: */
    if (req == "script") {
      eval (target.getAttribute("data-script"));
      return false;
    }
    else if (req == "post") { 
      data = $('form').serialize(); 
//      alert(data);
    }
    else { 
      data = {}; 
      req = 'get'; // by default
    }
    
    $('#dc-spinner').toggleClass('div-hidden');   
    $.ajax({
      url: target.getAttribute("data-url"),
      type: req,
      dataType: "json",
      data: data,
//      success: function(files,data,xhr) { 
//        document.getElementById('if_priponkas').contentDocument.location.reload(true); 
//      }
      success: function(data) {
        process_json_result(data);
        $('#dc-spinner').toggleClass('div-hidden');
      }
      
    });  
  });  

 /*******************************************************************
 * Animate button on click
 ******************************************************************
  $('.xdc-action-menu li').mousedown( function() {
    $(this).toggleClass('dc-animate-button');
  });
  
 ******************************************************************
 * Animate button on click
 ******************************************************************
  $('.xdc-action-menu li').mouseup( function() {
    $(this).toggleClass('dc-animate-button'); 
  });
 */
 /*******************************************************************
 * Animate button on click
 *******************************************************************/
  $('.dc-animate').mousedown( function() {
    $(this).toggleClass('dc-animate-button');
  });
  
 /*******************************************************************
 * Animate button on click
 *******************************************************************/
  $('.dc-animate').mouseup( function() {
    $(this).toggleClass('dc-animate-button'); 
  });
 
 /*******************************************************************
  * App menu option clicked
  *******************************************************************/
  $('.app-menu-item a').on('click', function(e) { 
/* parent of a is li */
    $(e.target).parents('li').each( function() {
/* for all li's in ul, deselect */
      $(this).parents('ul').find('li').each( function() {
        if ($(this).hasClass('app-menu-item-selected')) {
          $(this).toggleClass('app-menu-item-selected');
        }
      });
/* select clicked li */
      $(this).toggleClass('app-menu-item-selected');
    });
  });

/*******************************************************************
 * Display spinner on link with spinner, submit link
 *******************************************************************/
  $('.dc-link-spinner').on('click', function(e) {
    $('#dc-spinner').toggleClass('div-hidden');
  });  
  
  $('.dc-link-submit').on('click', function(e) {
    $('#dc-spinner').toggleClass('div-hidden');
  });  

/*******************************************************************
  * Add button clicked while in edit. Create window dialog for adding new record
  * into required table. This is helper scenario, when user is selecting
  * data from with text_autocomplete and data doesn't exist in belongs_to table.
  *******************************************************************/
  $('.in-edit-add').on('click', function(e) { 
    url = '/cmsedit/new?table=' + this.getAttribute("data-table");
/* I know. It doesn't work as expected. But it will do for now. */
    w = window.open(url, '', 'chrome=yes,width=800,height=600,resizable,scrollbars=yes,status=1,centerscreen=yes,modal=yes');
    w.focus();    
  });  
  
/**********************************************************************
 * When filter_field (field name) is selected on filter subform this routine finds 
 * and displays apropriate span with input field.
 **********************************************************************/
  $('#_filter_field').on('change', function() {
    if (this.value.length > 0) { 
      name = 'filter_' + this.value;
      $(this).parents('form').find('span').each( function() {
/*
element = $(this).find(':first').attr('id');
 sometimes it is the second element         
        if (element == nil) { element = $(this).find(':first').next().attr('id');}
 */   
        if ($(this).attr('id') == name) {
          if ( $(this).hasClass('div-hidden') ) { $(this).toggleClass('div-hidden'); }
        } else {
          if ( !$(this).hasClass('div-hidden') ) { $(this).toggleClass('div-hidden'); }
        }
      });         
    } 
  });

/*******************************************************************
 * It is not possible to attach any data to submit button except the text
 * that is written on a button and it is therefore very hard to distinguish
 * which button was pressed when more than one button is present on a form.
 * 
 * The purpose of this trigger is to append data hidden in html5 data attributes
 * to the form. We can now attach  any kind of data to submit button and data 
 * will be passed as data[] parameters to controller. 
 *******************************************************************/
  $('.dc-submit').on('click', function() {
    $.each(this.attributes, function() {
      if (this.name.substring(0,5) == 'data-') { 
        $('<input>').attr({
          type: 'hidden',
          name: 'data[' + this.name.substring(5) + ']',
          value: this.value
        }).appendTo('form');
      }
    });
  });
 
 /* DOCUMENT INFO                                                   */ 
 /*******************************************************************
  * Popup or hide document information 
  *******************************************************************/
  $('#dc-document-info').on('click',function(e) { 
    popup = $('#dc-document-info-popup');
    popup.toggleClass('div-hidden'); 
    if (!popup.hasClass('div-hidden')) {
      var o = {
        left: e.pageX - popup.width() - 10,
        top: e.pageY - popup.height() - 20
      };
      popup.offset(o);    
    };
  });
 /*******************************************************************
  * Just hide document information on click.
  *******************************************************************/
  $('#dc-document-info-popup').on('click',function(e) {
    $('#dc-document-info-popup').toggleClass('div-hidden'); 
  });    

/*******************************************************************
 * Experimental. Force reload of parent page if this div appears. 
 *******************************************************************/
  $('#div-reload-parent').load( function() {
//    alert('div-reload-parent 1');
    parent.location.href = parent.location.href;
  });

/*******************************************************************
 * Force reload of parent page if this div appears. 
 * 
 * Just an Idea. Not needed yet.
 *******************************************************************/
  $('#div-reload').load( function() {
    alert('div-reload 1');
//    location.href = location.href;
  });
  
  $('#div-reload-parent').on('DOMNodeInserted DOMNodeRemoved', function() {
    alert('div-reload-parent 2');
  });  
  $('#div-reload').on('DOMNodeInserted DOMNodeRemoved', function() {
    alert('div-reload 2');
  });
  
 /*******************************************************************
  * Fire action (by default show document) when doubleclicked on result row
  *******************************************************************/
  $('.dc-result tr').on('dblclick', function(e) {
    url = String( this.getAttribute("data-dblclick") );
// prevent when data-dblclick not set
    if (url.length > 5) { 
      e.preventDefault();
      location.href = url;
    } 
  });

 /*******************************************************************
  * Fire action clicked on result row. 
  * TODO: Find out how to prevent event when clicked on action icon.
  *******************************************************************/
  $('.dc-result tr').on('click', function(e) {
    url = String( this.getAttribute("data-click") );
// prevent when data-click not set
    if (url.length > 5) { 
      e.preventDefault();
      location.href = url; 
    } 
  });

 $('#1menu-filter').on('click', function(e) {
    var target = e.target;
//    if (e.target.src !== undefined) {
//      target = e.target.parent(); // picture
//    };
//    dumpAttributes(target);
    req = target.getAttribute("data-request");
    $('.menu-filter').toggle(300);
    
  });
  
 /*******************************************************************
  * This will fire cmsedit index action and pass value enterred into 
  * filter field and thus refresh browsed result set.
  *******************************************************************/
  $('#_record__filter_field').keydown( function(e) {
    if (e.which == '13' || e.which == '9') {
      url = $(this).parents('span').attr("data-url");
      url = url + "&filter_value=" + this.value;
      location.href = url;
      return false;      
    }
  });

  /*******************************************************************
  * Same as above, but when clicked on filter icon. enter and tab don't 
  * work on all field types.
  *******************************************************************/
  $('.record_filter_field_icon').on('click', function(e) {
    field = $('#_record__filter_field');
    url = $(this).parents('span').attr("data-url");
    url = url + "&filter_value=" + field.val();
    location.href = url;
  });

 /*******************************************************************
  * Click on show filter form
  *******************************************************************/
  $('#open_drgcms_filter').on('click', function(e) {
    $('#drgcms_filter').bPopup({
      speed: 650,
      transition: 'slideDown'
    });      
  });
  
 /*******************************************************************
  * 
  *******************************************************************/
  $('.drgcms_popup_submit').on('click', function(e) {
    //e.preventDefault();  
    url = $(this).attr( 'data-url' );
    field = $('select#_filter_field1').val();
    oper  = $('select#_filter_oper').val();
    location.href = url + '&filter_field=' + field + '&filter_oper=' + oper
// Still opening in new window
//    iframe = parent.document.getElementsByTagName("iframe")[0].getAttribute("id");
//    loc = url + '&filter_field=' + field + '&filter_oper=' + oper
//    $('#'+iframe).attr('src', loc);
//    parent.document.getElementById(iframe).src = loc   
   });
   
 /*******************************************************************
  * Toggle one cmsedit menu level
  *******************************************************************/
   $('.cmsedit-top-level-menu').on('click', function(e) {
     $(e.target).find('ul').toggle('fast');
   });
  
});

/*******************************************************************
 * Catch ctrl+s key pressed and fire save form event. I press ctrl+s
 * almost every minute. That was a lesson learned years ago when I lost
 * few hours of work on computer lockup ;-(
 *******************************************************************/
$(document).keydown( function(e) {
  if ((e.which == '115' || e.which == '83' ) && (e.ctrlKey || e.metaKey))
  {
    e.preventDefault();
    document.forms[0].submit();
    return false;
  }
  return true;
});