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

##########################################################################
# Controller holds methods which are of use for all application controllers.
##########################################################################
class DcApplicationController < ActionController::Base
  protect_from_forgery
  
########################################################################
# Writes anything passed as parameter to logger file.
# 
# Very usefull for debuging strange errors.
########################################################################
def dc_dump(*args)
  args.each do |arg|
    logger.debug arg.to_s
  end
end
  
####################################################################
# Return true if CMS is in edit mode
####################################################################
def dc_edit_mode?
  session[:edit_mode] > 1
end

####################################################################
# Checks if user has required role.
# 
# [Parameters:]
# [role] 
# Role can be passed as DcPolicyRole object or as string. If string
# is passed, dc_policy_roles files is searched for appropriate role.
# 
# [Return:]
# Boolean. True if user has required role added to his profile.
# 
# [Example:]
#    if dc_user_has_role('admin') ...
#    if dc_user_has_role('Site editors') ...
####################################################################
def dc_user_has_role(role)
  if role.class == String
    rol = role
    role = DcPolicyRole.find_by(name: rol)
    role = DcPolicyRole.find_by(system_name: rol) if role.nil?
  end
  return false if role.nil?
# role is found in user_roles
  session[:user_roles].include?(role._id)
end

####################################################################
# Determine site from url and return site document. 
# 
# [Return:]
# Site document. If site is not found and not in production environment 'test' 
# site document is returned. If site has alias set then alias site document is
# returned.
####################################################################
def dc_get_site()
  return @site if @site 
  uri  = URI.parse(request.url)
  @site = DcSite.find_by(name: uri.host)
# Site can be aliased
  if @site and !@site.alias_for.blank?
    @site = DcSite.find_by(name: @site.alias_for)
  end
# Development environment. Check if site with name test exists and use 
# alias_for as pointer to real site.
  if @site.nil? and ENV["RAILS_ENV"] != 'production'
    @site = DcSite.find_by(name: 'test')
    @site = DcSite.find_by(name: @site.alias_for) if @site
  end 
  @site = nil if @site and !@site.active # site is disabled
  @site
end

####################################################################
# Determine and return site record from url. It would be nice but it is not working.
####################################################################
def self.dc_get_site_() #:nodoc:
  #self.dc_get_site()
end

########################################################################
# Searches forms path for file_name and returns full file name or nil if not found.
# 
# [Parameters:]
# [form_file] Form file name. File name can be passed as gem_name.filename. This can
# be useful when you are extending form but want to retain same name as original form
# For example. You are extending dc_user form from drg_cms gem and want to
# retain same dc_user name. This can be done by setting drg_cms.dc_user to extend option. 
# 
# [Return:]
# String. Full form file name or nil if not found.
########################################################################
def dc_find_form_file(form_file)
  form_path=nil
  if form_file.match(/\.|\//)
    form_path,form_file=form_file.split(/\.|\//)
  end
  DrgCms.paths(:forms).reverse.each do |path|
    f = "#{path}/#{form_file}.yml"
    return f if File.exist?(f) and (form_path.nil? or path.to_s.match(/\/#{form_path}\//i))
  end
  p "Form file #{form_file} not found!"
  nil
end

#######################################################################
# Will render public/404.html file with some debug code includded.
# 
# [Parameters:]
# [Object where_the_error_is] Additional data can be displayed with error.
########################################################################
def dc_render_404(where_the_error_is=nil)
  render(file: "#{Rails.root}/public/404", :status => 404, :layout => false, :formats => [:html], 
         locals: {error_is: where_the_error_is})
end

########################################################################
# Will write document to dc_visits collection unless visit comes from robot. 
# It also sets session[is_robot] variable to true if robot.
########################################################################
def dc_log_visit()
  if request.env["HTTP_USER_AGENT"] and request.env["HTTP_USER_AGENT"].match(/\(.*https?:\/\/.*\)/)
    logger.info "ROBOT: #{Time.now.strftime('%Y.%m.%d %H:%M:%S')} id=#{@page.id} ip=#{request.remote_ip}."
    session[:is_robot] = true
  else
    DcVisit.create(site_id: @site.id, 
                   user_id: session[:user_id], 
                   page_id: @page.id, 
                   ip: request.remote_ip,
                   session_id: request.session_options[:id],
                   time: Time.now )
  end
end

protected

#############################################################################
# Add permissions. Subroutine of dc_user_can
############################################################################
def add_permissions_for(table_name=nil) # :nodoc:
  perm = table_name.nil? ? DcPermission.find_by(is_default: true) : DcPermission.find_by(table_name: table_name, active: true)
  (perm.dc_policy_rules.each {|p1| @permissions[p1.dc_policy_role_id] = p1.permission }) if perm
end

############################################################################
# Checks if user can perform (read, create, edit, delete) document in specified
# table (collection).
# 
# [Parameters:]
# [Integer permission] Required permission level
# [String table] Name of table(collection) for which permission is required. Defaults to params[table].
# 
# [Returns:]
# Boolean true if user's role permits operation on a table(collection) with required permission.
# 
# [Example:]
#     dc_user_can(DcPermission::CAN_VIEW, params[:table])
############################################################################
def dc_user_can(permission, table=params[:table])
  if @permissions.nil?
    @permissions = {}
    add_permissions_for # default permission
    table_name = ''
# permission can be set for table or object embedded in table. Read all possible values  
    table.strip.downcase.split(';').each do |t|
      table_name << (table_name.size > 0 ? ';' : '') + t # table;embedded;another;...
      add_permissions_for table_name
    end
  end
# Sometimes anonymous user is allowed to use cmsedit. Search for system default role.
#TODO This might not be the best idea. Check in the future.
  if session[:user_roles].nil?
    guest = DcUserRole.find_by(:system_name => 'guest')
    session[:user_roles] = guest ? [guest.id] : []
  end
# Return true if any of the permissions user has is higher or equal to requested permission 
  session[:user_roles].each {|r| return true if @permissions[r] and @permissions[r] >= permission }
  false
end  

####################################################################
# Detects if called from mobile agent according to http://detectmobilebrowsers.com/
####################################################################
def dc_set_is_mobile
  is_mobile = /(android|bb\d+|meego).+mobile|avantgo|bada\/|blackberry|blazer|compal|elaine|fennec|hiptop|iemobile|ip(hone|od)|iris|kindle|lge |maemo|midp|mmp|netfront|opera m(ob|in)i|palm( os)?|phone|p(ixi|re)\/|plucker|pocket|psp|series(4|6)0|symbian|treo|up\.(browser|link)|vodafone|wap|windows (ce|phone)|xda|xiino/i.match(request.user_agent) || /1207|6310|6590|3gso|4thp|50[1-6]i|770s|802s|a wa|abac|ac(er|oo|s\-)|ai(ko|rn)|al(av|ca|co)|amoi|an(ex|ny|yw)|aptu|ar(ch|go)|as(te|us)|attw|au(di|\-m|r |s )|avan|be(ck|ll|nq)|bi(lb|rd)|bl(ac|az)|br(e|v)w|bumb|bw\-(n|u)|c55\/|capi|ccwa|cdm\-|cell|chtm|cldc|cmd\-|co(mp|nd)|craw|da(it|ll|ng)|dbte|dc\-s|devi|dica|dmob|do(c|p)o|ds(12|\-d)|el(49|ai)|em(l2|ul)|er(ic|k0)|esl8|ez([4-7]0|os|wa|ze)|fetc|fly(\-|_)|g1 u|g560|gene|gf\-5|g\-mo|go(\.w|od)|gr(ad|un)|haie|hcit|hd\-(m|p|t)|hei\-|hi(pt|ta)|hp( i|ip)|hs\-c|ht(c(\-| |_|a|g|p|s|t)|tp)|hu(aw|tc)|i\-(20|go|ma)|i230|iac( |\-|\/)|ibro|idea|ig01|ikom|im1k|inno|ipaq|iris|ja(t|v)a|jbro|jemu|jigs|kddi|keji|kgt( |\/)|klon|kpt |kwc\-|kyo(c|k)|le(no|xi)|lg( g|\/(k|l|u)|50|54|\-[a-w])|libw|lynx|m1\-w|m3ga|m50\/|ma(te|ui|xo)|mc(01|21|ca)|m\-cr|me(rc|ri)|mi(o8|oa|ts)|mmef|mo(01|02|bi|de|do|t(\-| |o|v)|zz)|mt(50|p1|v )|mwbp|mywa|n10[0-2]|n20[2-3]|n30(0|2)|n50(0|2|5)|n7(0(0|1)|10)|ne((c|m)\-|on|tf|wf|wg|wt)|nok(6|i)|nzph|o2im|op(ti|wv)|oran|owg1|p800|pan(a|d|t)|pdxg|pg(13|\-([1-8]|c))|phil|pire|pl(ay|uc)|pn\-2|po(ck|rt|se)|prox|psio|pt\-g|qa\-a|qc(07|12|21|32|60|\-[2-7]|i\-)|qtek|r380|r600|raks|rim9|ro(ve|zo)|s55\/|sa(ge|ma|mm|ms|ny|va)|sc(01|h\-|oo|p\-)|sdk\/|se(c(\-|0|1)|47|mc|nd|ri)|sgh\-|shar|sie(\-|m)|sk\-0|sl(45|id)|sm(al|ar|b3|it|t5)|so(ft|ny)|sp(01|h\-|v\-|v )|sy(01|mb)|t2(18|50)|t6(00|10|18)|ta(gt|lk)|tcl\-|tdg\-|tel(i|m)|tim\-|t\-mo|to(pl|sh)|ts(70|m\-|m3|m5)|tx\-9|up(\.b|g1|si)|utst|v400|v750|veri|vi(rg|te)|vk(40|5[0-3]|\-v)|vm40|voda|vulc|vx(52|53|60|61|70|80|81|83|85|98)|w3c(\-| )|webc|whit|wi(g |nc|nw)|wmlb|wonu|x700|yas\-|your|zeto|zte\-/i.match(request.user_agent[0..3])
  session[:is_mobile] = is_mobile ? 1 : 0
end


##########################################################################
# Merge values from parameters fields (from site, page ...) into internal @options hash.
# [Parameters:]
# [String parameters] String in yaml syntax.
##########################################################################
def dc_set_options(parameters)
  @options ||= {}
  return if parameters.to_s.size < 3
# parameters are set az YAML. This should be default in future.
  parms = YAML.load(parameters) rescue nil
  if parms.nil? # error when loadnig yaml, try the old way parsing manually
    parms = {}
    parameters.split("\n").each do |line|
      line.chomp.split(',').each do |parm|
        key, value = parm.split(':')
        parms[key.strip] = value.to_s.strip.gsub(/\'|\"/,'')
      end
    end
  end
  @options.merge!(parms)
end

##########################################################################
# This is default page process action. It will search for site, page and
# design documents, collect parameters from different objects, add CMS edit code if allowed
# and at the end render design.body or design.rails_view or site.rails_view.
# 
# [Example:] as defined in routes.rb
#    get '*path' => 'dc_application_controller#dc_process_default_request'
#    # or
#    get '*path' => 'my_controller#page'
#    # then in my_controller.rb
#    def page
#      dc_process_default_request
#    end
#    
##########################################################################
def dc_process_default_request() 
  session[:edit_mode] ||= 0
# Initialize parts
  @parts    = nil
  @js, @css = '', ''
# find domain name in sites
  @site = dc_get_site
# site is not defined. render 404 error
  return dc_render_404('Site!') if @site.nil?
  dc_set_options(@site.settings)
# HOMEPAGE. When no parameters is set
  params[:path] = @site.homepage_link if params[:id].nil? and params[:path].nil?
# Search for page 
  pageclass = @site.page_table.classify.constantize
  if params[:id]
    #Page.where(id: params[:id]).or(subject_link: params[:id]).first    
    @page = pageclass.find_by(:dc_site_id.in => [@site._id, nil], subject_link: params[:id], active: true)
    @page = pageclass.find(params[:id]) if @page.nil? # I think that there will be more subject_link searchers than id
  elsif params[:path]
# path may point direct to page's subject_link
    @page = pageclass.find_by(:dc_site_id.in => [@site._id, nil], subject_link: params[:path], active: true)
    if @page.nil?
# no. Find if defined in links
      link = DcLink.find_by(:dc_site_id.in => [@site._id, nil], name: params[:path])
      if link
        #pageclass.find_by(alt_link: params[:path])   
        dc_set_options link.params
        @page = pageclass.find(link.page_id)   
      end
    end
  end
# if @page is not found render 404 error
  return dc_render_404('Page!') unless @page
  dc_set_options @page.params
  dc_set_is_mobile unless session[:is_mobile] # do it only once per session
# find design if defined. Otherwise design MUST be declared in site
  if @page.dc_design_id
    @design = DcDesign.find(@page.dc_design_id)
    return dc_render_404('Design!') unless @design
  end
# Add edit menu
  if session[:edit_mode] > 0
    session[:site_id]         = @site.id
    session[:site_page_table] = @site.page_table
    session[:page_id]         = @page.id
  else 
# Log only visits from non-editors
    dc_log_visit()
  end
  @page_title = @page.title.blank? ? "#{@site.page_title}-#{@page.subject}" : @page.title
  layout      = @site.site_layout.to_s.size > 2 ? @site.site_layout : 'content'
# render view. inline if defined in design
  view_filename = ''
  view_filename = @design.rails_view.to_s if @design
  view_filename = @site.rails_view.to_s   if view_filename.size < 5
  if view_filename.size < 5
    @design.body = "<%= render partial: 'cmsedit/edit_stuff' %>\n" + @design.body if session[:edit_mode] > 0 
    @design.body << '<style type="text/css"><%= @css.html_safe %></style><%= javascript_tag @js %>'
    render(inline: @design.body, layout: layout)
  else
    render view_filename, layout: layout
  end
end

########################################################################
# Decamelizes string. Does oposite from camelize method. It probably doesn't work 
# very good with non ascii chars. Since this method is used for converting from model
# to collection names it is very unwise to use non ascii chars for table (collection) names.
# 
# [Parameters:]
# [String string] String to be converted # 'DcSimpleMenu' => 'dc_simple_menu'.
########################################################################
def decamelize_type(string)
  return nil unless string
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
# Return's error messages for the document formated for display on edit form.
# 
# [Parameters:]
# [document] Document which will be examined for errors.
# 
# [Return:]
# String. HTML code for displaying error on edit form.
####################################################################
def dc_error_messages_for(document)
  return '' unless document.errors.any?
  msg = ''
  document.errors.each do |attribute, errors_array|
    label = t("helpers.label.#{decamelize_type(document.class)}.#{attribute}")
    msg << "<li>#{label} : #{errors_array}</li>"
  end

html = <<eot
<div class="dc-form-error"> 
  <h2>#{t('drgcms.errors_no')} #{document.errors.size}</h2>  
  <ul>#{msg}</ul>  
</div>
eot
  html.html_safe
end

####################################################################
# Checks if any errors exist on document and writes debug log. It can also 
# crash if requested. This is mostly usefull in development for debuging 
# model errors or when saving to multiple collections and where each save must be 
# checked if succesfull.
# 
# [Parameters:]
# [Object document] Document var
# [Boolean crash] Should crash when errors detected. Default = false.
# 
# [Return:]
# String. Documents error message empty string if everything is OK.
# 
# [Example:]
#    model.save
#    if (msg = dc_check_model(model) ).size > 0
#      p msg
#      error process ......
#    end
#      
####################################################################
def dc_check_model(document, crash=false)
  return nil unless document.errors.any?
  msg = ''
  document.errors.each do |attribute, errors_array|
    msg << "#{attribute}: #{errors_array}\n"
  end
  logger.debug(msg) if msg.size > 0
  crash_it if crash
  msg
end

######################################################################
# Call rake task from controller.
# 
# [Parameters:]
# [String task] Rake task name
# [Hash options] Options that will be send to task as environment variables
# 
# [Example:]
#    dc_call_rake('clear:all', some_parm: some_id)
######################################################################
def dc_call_rake(task, options = {})
  options[:rails_env] ||= Rails.env
  args = options.map { |o, v| "#{o.to_s.upcase}='#{v}'" }
  system "rake #{task} #{args.join(' ')} --trace 2>&1 >> #{Rails.root}/log/rake.log &"
end

######################################################################
# Small helper for rendering ajax return code from controller. When ajax call is
# made from DRG CMS form return may be quite complicated. All ajax return combinations 
# can be found in drg_cms.js file. 
# 
# [Parameters:]
# [Hash opts] Different options
# 
# [Return:]
# String. Formatted to be used on ajax return.
# 
# [Example:]
#    html_code = '<span>Some text</span>'
#    dc_render_ajax(div: 'mydiv', prepand: html_code) # Will prepand code to mydiv div
#    dc_render_ajax(class: 'myclass', append: html_code) # Will append code to all objects with myclass class
#    dc_render_ajax(operation: 'window', value: "/pdf_file.pdf") # will open pdf file in new window.
# 
######################################################################
def dc_render_ajax(opts)
  result = {}
  if opts[:operation].to_s == 'div' or opts[:operation].to_s == 'class'
    selector = opts[:operation].to_s == 'div' ? '#' : '.' # for div . for class
    key = case
      when opts[:prepend] then "#{selector}+div"
      when opts[:append]  then "#{selector}div+"
    else "#{selector}div"
    end
    key << '_' + opts[ opts[:operation].to_sym ] 
  else
    key = opts[:operation] + '_'
  end
  result[key] = opts[:value] || opts[:url] || ''
  render inline: result.to_json, formats: 'js'
end

######################################################################
# Small helper for rendering ajax return code from controller. When ajax call is
# made from DRG CMS form return may be quite complicated. All ajax return combinations 
# can be found in drg_cms.js file. 
# 
# [Parameters:]
# [Hash opts] Different options
# 
# [Return:]
# String. Formatted to be used on ajax return.
# 
# [Example:]
#    html_code = '<span>Some text</span>'
#    dc_render_ajax(div: 'mydiv', prepand: html_code) # Will prepand code to mydiv div
#    dc_render_ajax(class: 'myclass', append: html_code) # Will append code to all objects with myclass class
#    dc_render_ajax(operation: 'window', value: "/pdf_file.pdf") # will open pdf file in new window.
# 
######################################################################
def dc_render_ajax(opts)
  result = {}
  if opts[:div] or opts[:class]
    selector = opts[:div] ? '#' : '.' # for div . for class
    key = case
      when opts[:prepend] then "#{selector}+div"
      when opts[:append]  then "#{selector}div+"
    else "#{selector}div"
    end
    key << "_#{opts[:div]}#{opts[:class]}"
  else
    p 'Error: dc_render_ajax. Operation is not set!' if opts[:operation].nil?
    key = "#{opts[:operation]}_"
  end
  result[key] = opts[:value] || opts[:url] || ''
  render inline: result.to_json, formats: 'js'
end

########################################################################
# Find document by parameters. This is how cmsedit finds document based
# on url parameters.
# 
# [Parameters:]
# [String table] Table (collection) name. Could be dc_page;dc_part;... when searching for embedded document.
# [String id] Id of the document
# [String table] Ids of parent documents when document is embedded. Ids are separated by ; char. 
# 
# [Return:]
# Document. Required document or nil if not found.
# 
# [Example:] 
#    dc_find_document(params[:table], params[:id], params[:ids])
########################################################################
def dc_find_document(table, id, ids)
  tables = table.split(';')
  if tables.size == 1
    doc = tables.first.classify.constantize.find(id)
  else
    ids = ids.split(';')
    doc = tables.first.classify.constantize.find(ids.first)                           # top most record
    1.upto(tables.size - 2) { |i| doc = doc.send(tables[i].pluralize).find(ids[i]) }  # find embedded childrens by ids
    doc = doc.send(tables.last.pluralize).find(id)   # our record
  end
  doc
end

########################################################################
# Reload patches in development. Since patching files are not automatically loaded in
# development environment thiws litle method automatically reloads all patch files
# found in DrgCms.paths(:patches) path array.
########################################################################
def dc_reload_patches
  DrgCms.paths(:patches).each do |patches| 
    Dir["#{patches}/**/*.rb"].each { |path| require_dependency path }
  end
end



end
