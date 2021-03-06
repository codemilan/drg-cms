#coding: utf-8
#--
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
#++
require 'sort_alphabetical'

###########################################################################
# 
# DcApplicationHelper defines common helper methods for using with DRG CMS.
#
###########################################################################
module DcApplicationHelper
# page document
attr_reader :page
# design document
attr_reader :design
# site document
attr_reader :site
# tables url parameter
attr_reader :tables
# ids url parameter
attr_reader :ids
# form object
attr_reader :form
# options object
attr_reader :options
# part
attr_reader :part

# page title
attr_accessor :page_title
# all parts read from page, design, ...
attr_accessor :parts


############################################################################
# When @parent is present then helper methods are called from parent class otherwise 
# from self. 
############################################################################
def _origin #:nodoc:
  @parent ? @parent : self  
end

############################################################################
# Writes out deprication msg. It also adds site_name to message, so it is easier to
# find where the message is comming from.
############################################################################
def dc_deprecate(msg)
  p "#{dc_get_site.name}: #{msg}"
end

############################################################################
# This is main method used for render parts of design into final HTML document.
# 
# Parameters:
# [renderer] String or Symbol. Class name (in lowercase) that will be used to render final HTML code. 
# If class name is provided without '_renderer' suffix it will be added automatically.
# 
# When renderer has value :part, it is a shortcut for dc_render_design_part method which
# is used to draw parts of layout on design.
# 
# [opts] Hash. Additional options that are passed to method. Options are merged with
# options set on site, design, page and passed to renderer object.
# 
# Example:
#    <%= dc_render(:dc_page, method: 'view', category: 'news') %>
############################################################################
def dc_render(renderer, opts={})
  return dc_render_design_part(renderer[:part]) if renderer.class == Hash
# 
  opts[:edit_mode]  = session[:edit_mode] 
  opts[:editparams] = {}
  opts = @options.merge(opts) # merge options with parameters passed on site, page, design ...
  opts.symbolize_keys!        # this makes lots of things easier
# Create renderer object
  klass = renderer.to_s.downcase
  klass += '_renderer' unless klass.match('_renderer') #
  obj = Kernel.const_get(klass.classify, Class.new).new(self, opts) rescue nil
# 
  if obj
    html = obj.render_html
    @css  << obj.render_css.to_s
    html.nil? ? '' : html.html_safe # nil can happened  
  else
    "Class #{klass} not defined!"
  end
end

########################################################################
# Used for designs with lots of common code and one (or more) part which differs.
# It will simply replace anchor code with value of variable.
# 
# Example: As used in design. Backslashing < and % is important \<\%
#    <% part = "<div  class='some-class'>\<\%= dc_render(:my_renderer, method: 'render_method') \%\></div>" %>
#    <%= dc_replace_in_design(piece: 'piece_name', replace: '[main]', with: part) %>
# 
# Want to replace more than one part. Use array.
#    <%= dc_replace_in_design(replace: ['[part1]','[part2]'], with: [part1, part2]) %>
# 
# This helper is replacement for old 'script' method defined in dc_piece_renderer, 
# but it uses design defined in site document if piece parameter is not set.
########################################################################
def dc_replace_in_design(opts={})
  design = opts[:piece] ? DcPiece.find(name: opts[:piece]).script : dc_get_site.design
  layout = opts[:layout] || (dc_get_site.site_layout.size > 2 ? dc_get_site.site_layout : nil)
  if opts[:replace]
# replace more than one part of code
    if opts[:replace].class == Array
      0.upto(opts[:replace].size - 1) {|i| design.sub!(opts[:replace][i], opts[:with][i])}
    else
      design.sub!(opts[:replace], opts[:with])
    end
  end
  render(inline: design, layout: nil)
end

########################################################################
# Used for designs with lots of common code and one (or more) part which differs.
# It will simply replace anchor code with value of variable.
# 
# Example: As used in design. Backslashing < and % is important \<\%
#    <% part = "<div  class='some-class'>\<\%= dc_render(:my_renderer, method: 'render_method') \%\></div>" %>
#    <%= dc_replace_in_design(piece: 'piece_name', replace: '[main]', with: part) %>
# 
# Want to replace more than one part. Use array.
#    <%= dc_replace_in_design(replace: ['[part1]','[part2]'], with: [part1, part2]) %>
# 
# This helper is replacement for old 'script' method defined in dc_piece_renderer, 
# but it uses design defined in site document if piece parameter is not set.
########################################################################
def dc_render_from_site(opts={})
  design = opts[:piece] ? DcPiece.find(name: opts[:piece]).script : dc_get_site.design
  layout = opts[:layout] || (dc_get_site.site_layout.size > 2 ? dc_get_site.site_layout : nil)
  
  render(inline: design, layout: opts[:layout], with: opts[:with])
end



########################################################################
# Used for designs with lots of common code and one (or more) part which differs.
# Point is to define design once and replace some parts of design dinamically.
# Design may be defined in site and design doc defines only parts that vary
# from page to page.
# 
# Example: As used in design.
#    <%= dc_render_design_part(@main) %>
#    
#    main variable is defined in design body for example:
#    
#    @main = Proc.new {render partial: 'parts/home'}
# 
# This helper is replacement dc_render_from_site method which will soon be deprecated. 
########################################################################
def dc_render_design_part(part) 
  if part.nil?
    ''
  elsif part.class == Proc
    result = part.call
    result.class == Array ? result.first : result
  elsif part.class == String
    eval part
  else
    part.to_s
  end.html_safe
end

def dc_render_design(part) 
  dc_render_design_part(part) 
end

########################################################################
# Helper for rendering top CMS menu when in editing mode
########################################################################
def dc_page_top()
  if @design and !@design.rails_view.blank?
# Evaluate parameters in design body    
    eval(@design.body)
  end
  session[:edit_mode] > 0 ? render(partial: 'cmsedit/edit_stuff') : ''
end

########################################################################
# Helper for adding additional css and javascript code added by documents
# and renderers during page rendering.
########################################################################
def dc_page_bottom()
  %Q[<style type="text/css">#{@css}</style>#{javascript_tag @js}].html_safe
end
############################################################################
# Creates title div for DRG CMS dialogs. Title may also contain pagination section on right side if 
# result_set is provided as parameter.
# 
# Parameters:
# [text] String. Title caption.
# [result_set=nil] Document collection. If result_set is passed pagination links will be created.
#  
# Returns:
# String. HTML code for title.
############################################################################
def dc_table_title(text, result_set=nil)
  c = "<table width='100%' class='dc-title'><tr><td>#{text}</td>"
  if result_set and result_set.respond_to?(:current_page)
    c << "<td align='right' style='font-size: 0.8em;'> #{paginate(result_set, :params => {:action => 'index'})}</td>" 
  end
  c << '<tr></table>'
  c.html_safe
end

############################################################################
# Creates title for cmsedit edit action dialog. 
#  
# Returns:
# String. HTML code for title.
############################################################################
def dc_edit_title()
  title = @form['form']['title']
# defined as form:title:edit
  if title and title['edit'] and !@form['readonly']
    t( title['edit'], title['edit'] )
  elsif title and title['show'] and @form['readonly']
    t( title['show'], title['show'] )
  else
# concatenate title 
    c = (@form['readonly'] ? t('drgcms.show') : t('drgcms.edit')) + " : "
    c << (@form['title'] ? t( @form['title'], @form['title'] ) : t_tablename(@form['table'])) + ' : '
    title = (title and title['field']) ? title['field'] : @form['form']['edit_title']
    dc_deprecate('form:edit_title will be deprecated. Use form:title:field instead.') if @form['form']['edit_title']
#
    c << "#{@record[ title ]} : " if title and @record.respond_to?(title)
    c << @record._id if @record
  end
  c
end

############################################################################
# Creates title for cmsedit new action dialog. 
# 
# Returns:
# String. HTML code for title.
############################################################################
def dc_new_title()
  title = @form['form']['title']
# defined as form:title:new
  if title and title['new']
    t( title['new'], title['new'] )
  else
    if @form['table'] == 'dc_dummy'
      t( @form['title'], @form['title'] )
    else
      "#{t('drgcms.new')} : #{t_tablename(@form['table'])}"    
    end
  end
end

####################################################################
# Formats label and html input code for display on edit form.
#  
#  Parameters:
#  [input_html] String. HTML code for data input field.
#  [label] String. Input field label.
####################################################################
def dc_label_for(input_html, label)
  c =<<eot
<tr>
  <td class="dc-edit-label">#{label}</td>
  <td class="dc-edit-field">#{input_html}</td>
</tr>
eot
  c.html_safe
end

############################################################################
# Similar to rails submit_tag, but also takes care of link icon, translation, ...
############################################################################
def dc_submit_tag(caption, icon, parms, rest={})
  parms['class'] ||= 'dc-submit'
  if icon
    icon_image = if icon.match(/\./)
      image_tag(icon, class: 'dc-animate')
    elsif icon.match('<i')
      icon
    else
      fa_icon(icon)
    end
  end
  html = icon_image || ''
  html << submit_tag(t(caption, caption), parms)
end
############################################################################
# Similar to rails link_to, but also takes care of link icon, translation, ...
############################################################################
def dc_link_to(caption, icon, parms, rest={})
  if parms.class == Hash
    parms.stringify_keys!
    rest.stringify_keys!
    rest['class'] = rest['class'].to_s + ' dc-animate'
    rest['target'] ||=  parms.delete('target')
  end
#  
  if icon
    icon_image = if icon.match(/\./)
      _origin.image_tag(icon, class: 'dc-link-img dc-animate')
    elsif icon.match('<i')
      icon
    else
      _origin.fa_icon(icon)
    end
  end
#  
  if caption
    caption = t(caption, caption)
    icon_image << ' ' if icon_image
  end
  _origin.link_to("#{icon_image}#{caption}".html_safe, parms, rest)  
end

####################################################################
# Returns flash messages formatted for display on message div.
# 
# Returns:
# String. HTML code formatted for display.
####################################################################
def dc_flash_messages()
  err  = _origin.flash[:error]
  war  = _origin.flash[:warning]
  inf  = _origin.flash[:info]
  note = _origin.flash[:note]
  unless err.nil? and war.nil? and inf.nil? and note.nil?
    c = ''
    c << "<div class=\"dc-form-error\">#{err}</div>" if err
    c << "<div class=\"dc-form-warning\">#{war}</div>" if war
    c << "<div class=\"dc-form-info\">#{inf}</div>" if inf
    c << note if note
    _origin.flash[:error]   = nil
    _origin.flash[:warning] = nil
    _origin.flash[:info]    = nil
    _origin.flash[:note]    = nil

    c.html_safe
  end
end

########################################################################
# Decamelizes string. This probably doesn't work very good with non ascii chars.
# Therefore it is very unwise to use non ascii chars for table (collection) names.
# 
# Parameters: 
# [string] String. String to be converted into decamelized string.
# 
# Returns:
# String. Decamelized string.
########################################################################
def decamelize_type(string)
  return nil if string.nil?
  r = ''
  string.to_s.each_char do |c|
    r << case 
      when r.size == 0     then c.downcase
      when c.downcase != c then '_' + c.downcase
      else c      
    end
  end
  r
end

####################################################################
# Returns validation error messages for the document (record) formatted for 
# display on message div.
# 
# Parameters: 
# [doc] Document. Document record which will be checked for errors.
# 
# Returns:
# String. HTML code formatted for display.
####################################################################
def dc_error_messages_for(doc)
  return '' unless doc.errors.any?
  msgs = ''
  doc.errors.each do |attribute, errors_array|
    label = t("helpers.label.#{decamelize_type(doc.class)}.#{attribute}", attribute)
    msgs << "<li>#{label} : #{errors_array}</li>"
  end
  
c = <<eot
<div class="dc-form-error"> 
  <h2>#{t('drgcms.errors_no')} #{doc.errors.size}</h2>  
  <ul>#{msgs}</ul>  
</div>
eot
  c.html_safe
end

####################################################################
# Checks if CMS is in edit mode (CMS menu bar is visible).
#  
# Returns:
# Boolean. True if in edit mode
####################################################################
def dc_edit_mode?
  _origin.session[:edit_mode] > 1
end

####################################################################
# Will create HTML code required to create new document.
# 
# Parameters: 
# [opts] Hash. Optional parameters for url_for helper. These options must provide at least table and formname
# parameters. 
# 
# Example:
#    if @opts[:edit_mode] > 1
#      opts = {table: 'dc_page;dc_part', formname: 'dc_part', ids: @doc.id }
#      html << dc_link_for_create( opts.merge!({title: 'Add new part', 'dc_part.name' => 'initial name', 'dc_part.order' => 10}) ) 
#    end
# 
# Returns:
# String. HTML code which includes add image and javascript to invoke new document create action.
####################################################################
def dc_link_for_create(opts)
  opts.stringify_keys!  
  title = opts.delete('title') #
  title = t(title, title) if title
  target = opts.delete('target')  || 'iframe_cms'
  opts['form_name']  ||= opts['table']
  opts['action']       = 'new'
  opts['controller'] ||= 'cmsedit'
  js = "$('##{target}').attr('src', '#{_origin.url_for(opts)}'); return false;"
  dc_link_to(nil, _origin.fa_icon('plus-circle lg', class: 'dc-inline-link'), '#',
             { onclick: js, title: title, alt: 'Create'}).html_safe
end

####################################################################
# Will create HTML code required to edit document.
# 
# Parameters: 
# [opts] Hash. Optional parameters for url_for helper. These options must provide at least table and formname
# and id parameters. 
# 
# Example:
#    html << dc_link_for_edit( @options ) if @opts[:edit_mode] > 1
#    
# Returns:
# String. HTML code which includes edit image and javascript to invoke edit document action.
####################################################################
def dc_link_for_edit(opts)
  opts.stringify_keys!  
  title  = opts.delete('title') #
  target = opts.delete('target') || 'iframe_cms'
  opts['controller'] ||= 'cmsedit'
  opts['action']       = 'edit'
  opts['form_name']  ||= opts['table']
  js  = "$('##{target}').attr('src', '#{_origin.url_for(opts)}'); return false;"
  dc_link_to(nil, _origin.fa_icon('edit lg', class: 'dc-inline-link'), '#', 
             { onclick: js, title: title, alt: 'Edit'})
end

####################################################################
# Create edit link with edit picture. Subroutine of dc_page_edit_menu.
####################################################################
def dc_link_menu_tag(title) #:nodoc:
  html =<<EOT
  <dl>
  <dt><div class='drgcms_popmenu' href="#">
   #{_origin.fa_icon('edit lg', class: 'dc-inline-link', title: title)}</div></dt>
    <dd>
    <ul class=' div-hidden drgcms_popmenu_class'> 
EOT
  yield html
  html << "</ul></dd></dl>"
end

####################################################################
# Create one option in page edit link. Subroutine of dc_page_edit_menu.
####################################################################
def dc_link_for_edit1(opts, link_text) #:nodoc:
  icon = opts.delete('icon')
  url  = _origin.url_for(opts)
  "<li><div class='drgcms_popmenu_item' style='cursor: pointer;' data-url='#{url}'>
#{_origin.fa_icon(icon)} #{link_text}</div></li>\n"
end

########################################################################
# Create edit menu for editing existing or creating new dc_page documents. Edit menu
# consists of for options.
# * Edit content. Will edit only body part od document.
# * Edit advanced. Will create edit form for editing all document fields.
# * New page. Will create new document and pass some initial data to it. Initial data is saved to cookie.
# * New part. Will create new part of document.
# 
# Parameters:
# [opts] Hash. Optional parameters for url_for helper. These options must provide at least table and formname
# and id parameters. 
# 
# Example:
#    html << dc_page_edit_menu() if @opts[:edit_mode] > 1
# 
# Returns: 
# String. HTML code required for manipulation of currently processed document.
########################################################################
def dc_page_edit_menu(opts=@opts)
  return '' if opts[:edit_mode] < 2
# save some data to cookie. This can not go to session.
  page  = opts[:page] || @page
  table = _origin.site.page_table
  kukis = { "#{table}.dc_design_id" => page.dc_design_id,
            "#{table}.menu_id"      => page.menu_id,
            "#{table}.kats"         => page.kats,
            "#{table}.page_id"      => page.id,
            "#{table}.dc_site_id"   => _origin.site.id
  }
  _origin.cookies[:record] = Marshal.dump(kukis)
  title = "#{t('drgcms.edit')}: #{page.subject}"
  dc_link_menu_tag(title) do |html|
    opts[:editparams].merge!( controller: 'cmsedit', action: 'edit', 'icon' => 'edit' )
    opts[:editparams].merge!( :id => page.id, :table => _origin.site.page_table, formname: opts[:formname], edit_only: 'body' )
    html << dc_link_for_edit1( opts[:editparams], t('drgcms.edit_content') )
    
#    opts[:editparams][:edit_only] = nil
    opts[:editparams].merge!( edit_only: nil, 'icon' => 'pencil' )
    html << dc_link_for_edit1( opts[:editparams], t('drgcms.edit_advanced') )
    
#    opts[:editparams][:action] = 'new'
    opts[:editparams].merge!( action: 'new', 'icon' => 'plus' )
    html << dc_link_for_edit1( opts[:editparams], t('drgcms.edit_new_page') )

    opts[:editparams].merge!(ids: page.id, formname: 'dc_part', 'icon' => 'plus-square-o', 
                             table: "#{_origin.site.page_table};dc_part"  )
    html << dc_link_for_edit1( opts[:editparams], t('drgcms.edit_new_part') )
  end
end

########################################################################
# Return page class model defined in site document page_class field. 
# 
# Used in forms, when method must be called from page model and model is overwritten by 
# user's own model.
# 
# Example as used on form:
#    30:
#      name: link
#      type: text_with_select
#      eval: 'dc_page_class.all_pages_for_site(@parent.dc_get_site)'
########################################################################
def dc_page_class()
  dc_get_site.page_class.classify.constantize  
end

####################################################################
# Wrapper for i18 t method, with some spice added. If translation is not found English
# translation value will be returned. And if still not found default value will be returned if passed.
# 
# Parameters:
# [key] String. String to be translated into locale.
# [default] String. Value returned if translation is not found.
# 
# Example:
#    t('translate.this','Enter text for ....')
# 
# Returns: 
# String. Translated text. 
####################################################################
def t(key, default='')
  c = I18n.t(key)
  if c.class == Hash or c.match( 'translation missing' )
    c = I18n.t(key, locale: 'en') 
# Still not found. Return default if set
    if c.class == Hash or c.match( 'translation missing' )
      c = default.blank? ? key : default
    end
  end
  c
end

####################################################################
# Returns table (collection) name translation for usage in dialog title. Tablename 
# title is provided by helpers.label.table_name.tabletitle locale.
# 
# Parameters:
# [tablename] String. Table (collection) name to be translated.
# [default] String. Value returned if translation is not found.
# 
# Returns: 
# String. Translated text. 
####################################################################
def t_tablename(tablename, default=nil)
  t('helpers.label.' + tablename + '.tabletitle', default || tablename)
end

############################################################################
# Returns label for field translated to current locale for usage on data entry form.
# Translation is provided by lang.helpers.label.table_name.field_name locale. If
# translation is not found method will capitalize field_name and replace '_' with ' '.
############################################################################
def t_name(field_name, default='')
  c = t("helpers.label.#{@form['table']}.#{field_name}", default)
  c = field_name.capitalize.gsub('_',' ') if c.match( 'translation missing' )
  c
end

############################################################################
# When select field is used on form options for select can be provided by 
# helpers.label.table_name.choices4_name locale. This is how select
# field options are translated. Method returns selected choice translated
# to current locale. 
# 
# Parameters:
# [model] String. Table (collection) model name (lowercase).
# [field] String. Field name used.
# [value] String. Value of field which translation will be returned.
# 
# Example:
#    # usage in program. Choice values for state are 'Deactivated:0,Active:1,Waiting:2'
#    dc_name4_value('dc_user', 'state', @record.active )
#
#    # usage in form
#    columns:
#      2: 
#        name: state
#        eval: dc_name4_value dc_user, state
#        
# Returns: 
# String. Descriptive text (translated) for selected choice value.
############################################################################
def dc_name4_value(model, field, value)
  return '' if value.nil?
  c = t('helpers.label.' + model + '.choices4_' + field )
  a = c.chomp.split(',').inject([]) {|r,v| r << v.split(':') }
  a.each {|e| return e.first if e.last.to_s == value.to_s }
  ''
end

############################################################################
# Return choices for field in model if choices are defined in localization text.
# 
# Parameters:
# [model] String. Table (collection) model name (lowercase).
# [field] String. Field name used.
# 
# Example:
#    dc_choices4_field('dc_user', 'state' )
#        
# Returns: 
# Array. Choices for select input field
############################################################################
def dc_choices4_field(model, field)
  c = t('helpers.label.' + model + '.choices4_' + field )
  return ['error'] if c.match( 'translation missing' )
  c.chomp.split(',').inject([]) {|r,v| r << v.split(':') }
end

############################################################################
# Will return descriptive text for id key when field in one table (collection) has belongs_to 
# relation to other table.
# 
# Parameters:
# [model] String. Table (collection) model name (lowercase).
# [field] String. Field name holding the value of descriptive text.
# [field_name] String. ID field name. This is by default id, but can be any other 
# (preferred unique) field.
# [value] Value of id_field. Usually a BSON Key but can be any other data type.
# 
# Example:
#    # usage in program.
#    dc_name4_id('dc_user', 'name', nil, dc_page.created_by)
#
#    # usage in form
#    columns:
#      2: 
#        name: site_id
#        eval: dc_name4_id,site,name
#    # username is saved to document instead of user.id field
#      5: 
#        name: user
#        eval: dc_name4_id,dc_user,name,username
# 
# Returns: 
# String. Name (descriptive value) for specified key in table.
############################################################################
def dc_name4_id(model, field, field_name, id=nil)
  return '' if id.nil?
  field_name = 'id' if field_name.nil?
  model = model.strip.classify.constantize if model.class == String
  rec = Mongoid::QueryCache.cache { model.find_by(field_name.strip.to_sym => id) }
  rec.nil? ? '' : rec[field]
end

############################################################################
# Return html code for icon presenting boolean value. Icon is a picture of checked or unchecked box.
# 
# Parameters:
# [value] Boolean.  
# 
# Example:
#    # usage from program
#    dc_icon4_boolean(some_value)
#
#    # usage from form description
#    columns:
#      10: 
#        name: active
#        eval: dc_icon4_boolean
############################################################################
def dc_icon4_boolean(value)
  dc_dont?(value, true) ? fa_icon('square-o lg') : fa_icon('check-square-o lg') 
end

############################################################################
# Returns html code for displaying date/time formatted by strftime. Will return '' if value is nil.
# 
# Parameters:
# [value] Date/DateTime/Time.  
# [format] String. strftime format mask. Defaults to locale's default format.
############################################################################
def dc_format_date_time(value, format=nil)
  return '' if value.nil?
  format ||= value.class == Date ? t('date.formats.default') : t('time.formats.default')
  value.strftime(format)
end

####################################################################
#
####################################################################
def dc_date_time(value, format) #:nodoc:
  dc_deprecate 'dc_date_time will be deprecated! Use dc_format_date_time instead.'
  dc_format_date_time(value, format)
end

####################################################################
# Parse site name from url and return dc_site document. Site document will be cached in
# @site variable.
# 
# If not in production environment and site document is not found
# method will search for 'test' document and return dc_site document found in alias_for field.
# 
# Returns:
# DCSite. Site document.
####################################################################
def dc_get_site()
  return @site if @site # already cached
#
  req = _origin.request.url # different when called from renderer
  uri  = URI.parse(req)
  @site = DcSite.find_by(name: uri.host)
# Site can be aliased
  if @site and !@site.alias_for.blank?
    @site = DcSite.find_by(name: @site.alias_for)
  end
# Development environment. Check if site with name test exists and use 
# alias_for field as pointer to real site name.
  if @site.nil? and ENV["RAILS_ENV"] != 'production'
    @site = DcSite.find_by(name: 'test')
    @site = DcSite.find_by(name: @site.alias_for) if @site
  end 
  @site = nil if @site and !@site.active # site is disabled
  @site
end

############################################################################
# Return array of policies defined in a site document formated to be used
# as choices for select field. Method is used for selecting site policy where
# policy for displaying data is required.
# 
# Example (as used in forms):
#    name: policy_id
#    type: select
#    eval: dc_choices4_site_policies
#    html:
#      include_blank: true      
############################################################################
def dc_choices4_site_policies()
  site = dc_get_site()
  site.dc_policies.all.inject([]) { |r, policy| r << [ policy.name, policy.id] if policy.active }
end

############################################################################
# Returns list of all collections (tables) as array of choices for usage in select fields.
# List is collected from cms_menu.yml files and may not include all collections used in application.
# Currently list is only used for helping defining collection names on dc_permission form. 
# 
# Example (as used in forms):
#    form:
#      fields:
#        10:
#          name: table_name
#          type: text_with_select
#          eval: dc_choices4_all_collections      
############################################################################
def dc_choices4_all_collections
  choices = {}
  DrgCms.paths(:forms).reverse.each do |path|
    filename = "#{path}/cms_menu.yml"
    next unless File.exist?(filename)
#
    menu = YAML.load_file(filename) rescue nil      # load menu
    next if menu.nil? or !menu['menu']              # not menu or error
    menu['menu'].each do |section|
      next unless section.last['items']             # next if no items
      section.last['items'].each do |k, v|          # look for caption and 
        key = v['table']
        choices[key] ||= "#{key} - #{t(v['caption'], v['caption'])}" 
      end
    end
  end  
  choices.invert.to_a.sort # hash has to be inverted for values to be returned right
end

########################################################################
# Merges two forms when current form extends other form. Subroutine of dc_choices4_cmsmenu.
# With a little help of https://www.ruby-forum.com/topic/142809 
########################################################################
def forms_merge(hash1, hash2) #:nodoc:
  target = hash1.dup
  hash2.keys.each do |key|
    if hash2[key].is_a? Hash and hash1[key].is_a? Hash
      target[key] = forms_merge(hash1[key], hash2[key])
      next
    end
    target[key] = hash2[key] == '/' ? nil :  hash2[key]
  end
# delete keys with nil value  
  target.delete_if{ |k,v| v.nil? }
end

##########################################################################
# Returns choices for creating collection edit select field on CMS top menu.
##########################################################################
def dc_choices4_cmsmenu()
  menus = {}
  DrgCms.paths(:forms).reverse.each do |path|
    filename = "#{path}/cms_menu.yml"
    next unless File.exist?(filename)
    menu = YAML.load_file(filename) rescue nil      # load menu
    next if menu.nil? or !menu['menu']              # not menu or error
    menus = forms_merge(menu['menu'], menus)        # ignore top level part
 end
#
  html = '<ul>'
  menus.to_a.sort.each do |one_menu|    # sort menus, result is array of sorted hashes
    menu = one_menu[1]                  # value is the second (1) element of array
    next unless menu['caption']
    html << "<li class=\"cmsedit-top-level-menu\">#{fa_icon(menu['icon'])}#{t(menu['caption'])}<ul>"
    menu['items'].to_a.sort.each do |item|          # as above. sort items first 
      value = item[1]
      opts = { controller: value['controller'], 
               action: value['action'], 
               table: value['table'],
               formname: value['formname'] || value['table'],
               target: value['target'] || 'iframe_cms'               
             }
      html << "<li>#{dc_link_to(t(value['caption']), value['icon'] || '', opts)}</li>"      
    end   
    html << '</ul></li>'  
  end
  html
end

############################################################################
# Returns list of directories as array of choices for use in select field 
# on folder permission form. Directory root is determined from dc_site.files_directory field.
############################################################################
def dc_choices4_folders_list
  public = File.join(Rails.root,'public')
  home   = File.join(public,dc_get_site.files_directory)
  choices = Dir.glob(home + '/**/*/').select { |fn| File.directory?(fn) }
  choices << home # add home
  choices.collect! {|e| e.gsub(public,'')} # remove public part
  choices.sort
end

############################################################################
# Returns choices for select input field when choices are generated from
# all documents in collection.
# 
# Parameters:  
# [model] String. Collection (table) name in lowercase format.
# [name] String. Field name containing description text.
# [id] String. Field name containing id field. Default is '_id'
# [options] Hash. Various options. Currently site: (:only, :with_nil, :all) is used.
# Will return only documents belonging to current site, also with site not defined,
# or all documents.
# 
# Example (as used in forms):
#    50:
#      name: dc_poll_id
#      type: select
#      eval: dc_choices4('dc_poll','name','_id')
############################################################################
def dc_choices4(model, name, id='_id', options = {})
  model = model.classify.constantize
  qry   = model.only(id, name)
  if (param = options[:site])
    sites = [dc_get_site.id] unless param == :all
    sites << nil if param == :with_nil 
    qry   = qry.in(dc_site_id: sites) if sites
  end
  qry   = qry.and(active: true) if model.method_defined?(:active)
#  qry   = qry.sort(name => 1) 
#  choices = []
#  qry.each {|v| choices << [ v[name], v[id] ] }
  choices = qry.inject([]) {|result,e| result << [ e[name], e[id] ]}
  choices.sort_alphabetical_by(&:first) # use UTF-8 sort
end

############################################################################
# Returns list of choices for selection top level menu on dc_page form. Used for defining which 
# top level menu will be highlited when page is displayed.
# 
# Example (as used in forms):
#    20:
#      name: menu_id
#      type: select
#      eval: dc_choices4_menu      
############################################################################
def dc_choices4_menu
  m_clas = dc_get_site.menu_class
  m_clas = 'DcSimpleMenu' if m_clas.blank?
  klass  = m_clas.classify.constantize
  klass.choices4_menu(dc_get_site)
end

############################################################################
# Will add data to record cookie. Record cookie is used to preload some 
# data on next create action. Create action will look for cookies[:record] and 
# if found initialize fields on form with matching name to value found in cookie data.
# 
# Example:
#    kukis = {'dc_page.dc_design_id' => @page.dc_design_id,
#             'dc_page.dc_menu_id' => @page.menu_id)
#   dc_add2_record_cookie(kukis)
############################################################################
def dc_add2_record_cookie(hash)
  kukis = if @parent.cookies[:record] and @parent.cookies[:record].size > 0
    Marshal.load(@parent.cookies[:record])
  else
    {}
  end
  hash.each {|k,v| kukis[k] = v }
  @parent.cookies[:record] = Marshal.dump(kukis)
end

############################################################################
# Will check if user roles allow user to view data in document with defined access_policy.
# 
# Parameters:
# [ctrl] Controller object or object which holds methods to access session object. For example @parent
# variable when called from renderer.
# [policy_id] Document or documents policy_id field value required to view data. Method will automatically 
# check if parameter send has policy_id field defined and use value of that field.
# 
# Example:
#    can_view, message = dc_user_can_view(@parent, @page) 
#    # or
#    can_view, message = dc_user_can_view(@parent, @page.policy_id)
#    return message unless can_view
# 
# Returns:
# True if access_policy allows user to view data. 
# False and message from policy that is blocking view if access is not allowed.
############################################################################
def dc_user_can_view(ctrl, policy_id)
  policy_id = policy_id.policy_id if policy_id and policy_id.respond_to?(:policy_id)
# Eventualy object without policy_id will be checked. This is to prevent error
  policy_id = nil unless policy_id.class == BSON::ObjectId
#
  site = ctrl.site
  policies = site.dc_policies
# permission defined by default policy
  default_policy = Mongoid::QueryCache.cache { policies.find_by(is_default: true) }
  return false, 'Default accsess policy not found for the site!' unless default_policy
#  
  permissions = {}
  default_policy.dc_policy_rules.to_a.each { |v| permissions[v.dc_policy_role_id] = v.permission }
# update permissions with defined policy 
  part_policy = nil
  if policy_id
    part_policy = Mongoid::QueryCache.cache { policies.find(policy_id) }
    return false, 'Access policy not found for part!' unless part_policy
    part_policy.dc_policy_rules.to_a.each { |v| permissions[v.dc_policy_role_id] = v.permission }
  end
# apply guest role if user has no roles defined
  if ctrl.session[:user_roles].nil?
    role = Mongoid::QueryCache.cache { DcPolicyRole.find_by(system_name: 'guest', active: true) }
    return false, 'System guest role not defined!' unless role
    ctrl.session[:user_roles] = [role.id]
  end
# Check if user has any role that allows him to view part
#  p h, ctrl.session[:user_roles]
  can_view, msg = false,''
  ctrl.session[:user_roles].each do |role|
    next unless permissions[role]          # role not yet defined. Will die in next line.
    if permissions[role] > 0
      can_view = true
      break
    end
  end
  msg = if !can_view
    part_policy ? t(part_policy.message,part_policy.message) : t(default_policy.message,default_policy.message)
  end
  return can_view, msg
end

####################################################################
# Check if user has required role assigned to its user profile. If role is passed as
# string method will check roles for name and system name.
# 
# Parameters:
# [role] DcPolicyRole/String. Required role. If passed as string role will be searched in dc_policy_roles collection.
# [user] User id. Defaults to session[:user_id].
# [roles] Array of roles that will be searched. Default session[:user_roles].
# 
# Example:
#    if dc_user_has_role('decision_maker', session[:user_id), session[:user_roles]) 
#      do_something_important
#    end
#    
# Returns:
# Boolean. True if user has required role.    
####################################################################
def dc_user_has_role( role, user=nil, roles=nil )
  roles = _origin.session[:user_roles] if roles.nil?
  user  = _origin.session[:user_id] if user.nil?
  return false if user.nil? or roles.nil?
#  
  role = DcPolicyRole.get_role(role)
  return false if role.nil?
# role is included in roles array
  roles.include?(role._id)
end

####################################################################
# Returns true if parameter has value of 0, false, no, none or -. Returns default
# if parameter has nil value.
# 
# Parameters:
# [what] String/boolean/Integer. 
# [default] Default value when what has value of nil. False by default.
# 
# Example:
#    dc_dont?('none') # => true
#    dc_dont?('-')    # => true
#    dc_dont?(1)      # => false
####################################################################
def dc_dont?(what, default=false)
  return default if what.nil?
  %w(0 no - false none).include?(what.to_s.downcase.strip)
end

############################################################################
# Truncates string length maximal to the size required and takes care, that words are not broken in middle.
# Used for output text summary with texts that can be longer then allowed space.
# 
# Parameters:
# [string] String of any size.
# [size] Maximal size of the string to be returned. 
# 
# Example:
#    dc_limit_string(description, 100)
#    
# Returns:
# String, truncated to required size. If string is truncated '...' will be added to the end.
############################################################################
def dc_limit_string(string, size)
  return string if string.size < size
  string = string[0,size]
  string.chop! until (string[-1,1] == ' ' or string == '')
  string << '...'
end

############################################################################
# Returns key defined in DcBigTable as array of choices for use in select fields.
# DcBigTable can be used like a key/value store for all kind of predefined values 
# which can be linked to site and or locale.
# 
# Parameters:
# [key] String. Key name to be searched in dc_big_tables documents.
# 
# Example:
#    10:
#      name: category
#      type: select
#      eval: dc_big_table 'categories_for_page'  # as used on form
# 
# Returns:
# Array of choices ready for select field.
############################################################################
def dc_big_table(key)
  ret = []
  bt = DcBigTable.find_by(key: key, site: dc_get_site._id, active: true)
  bt = DcBigTable.find_by(key: key, site: nil, active: true) if bt.nil?
  return ret if bt.nil? 
# 
  locale = I18n.locale.to_s
  bt.dc_big_table_values.each do |v|   # iterate each value
    next unless v.active
    desc = ''
    v.dc_big_table_locales.each do |l| # iterate each locale
      if l.locale == locale
        desc = l.description
        break
      end
    end
    desc = v.description if desc.blank? # get description from value description
    desc = v.value if desc.blank?       # still blank. Use value as description
    ret << [desc, v.value] 
  end
  ret
end

########################################################################
# Will return html code required for load DRG form into iframe. If parameters 
# are passed to method iframe url will have initial value and thus enabling automatic form
# load on page display.
# 
# Parameters:
# [table] String: Collection (table) name used to load initial form.
# [opts] Hash: Optional parameters which define url for loading DRG form.
# These parameters are :action, :oper, :table, :formname, :id, :readonly
# 
# Example:
#    # just iframe code
#    <%= dc_iframe_edit(nil) %>
#    # load note form for note collection
#    <%= dc_iframe_edit('note') %>
#    # on register collection use reg_adresses formname to display data with id @register.id
#    <%= dc_iframe_edit('register', action: :show, formname: 'reg_adresses', readonly: 1, id: @register.id ) %>
# 
# Returns:
# Html code for edit iframe
########################################################################
def dc_iframe_edit(table, opts={})
  ret = if params.size > 2 and table  # controller, action, path is minimal
    params[:controller] = 'cmsedit'
    params[:action]     = (params[:oper] and (params[:oper] == 'edit')) ? 'edit' : 'index'
    params[:action]     = opts[:action] unless params[:oper]
    params[:table]      ||= table 
    params[:formname]   ||= opts[:formname] || table 
    params[:id]         ||= params[:idp] || opts[:id]
    params[:readonly]   ||= opts[:readonly]
    params[:path]       = nil
    params.permit! # rails 5 request
    "<iframe id='iframe_edit' name='iframe_edit' src='#{url_for params}'></iframe>"
  else
    "<iframe id='iframe_edit' name='iframe_edit'></iframe>"
  end
  ret.html_safe
end

end
