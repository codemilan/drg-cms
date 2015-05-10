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

########################################################################
# Mongoid::Document model for dc_designs collection.
# 
# Designs are essential parts of DRG CMS. Every DcPage document must have its design document defined.
# If DcPage documents are anchors for url addresses, DcDesign documents define how 
# will page data be rendered in browser. 
# 
# DcDesign documents define what would normally be written into Rails view file. The code
# is saved in the body field of DcDesign document. If you prefere Rails way, enter view 
# file name into rails_view field and put your code into file into views directory 
# (ex. designs/home_page for ../views/designs/home_page.html.erb file). 
# 
# If you choose to save code to Rails view file you must add one top and bottom line to every source file.
# Top line will provide CMS edit menu, bottom line will provide additional CSS and javascript code
# scooped when renderers are called.
# 
# Example (as written in body of dc_design):
#    <div id="site">
#      <div id="site-top-bg">
#        <div id="site-top"><div id="logo"><%= dc_render(:dc_piece, name: 'site-top') %></div>
#          <div id="login"><%= dc_render(:common, method: 'login') %></div>
#       </div>
#        <%= dc_render(:dc_menu, name: 'test-menu') %>
#      </div>
#
#      <div id="page"><%= dc_render(:dc_page) %></div>
#    </div>
#    <div id="site-bottom"><%= dc_render(:dc_piece, name: 'site-bottom') %></div>
#    
# Example (as written in Rails view file):
# 
#    <!-- Pay attention on lines added at the top and bottom of file -->
#    <%= render partial: 'cmsedit/edit_stuff' if session[:edit_mode] > 0 %>
#    
#    <div id="site">
#      <div id="site-top-bg">
#        <div id="site-top"><div id="logo"><%= dc_render(:dc_piece, name: 'site-top') %></div>
#          <div id="login"><%= dc_render(:common, method: 'login') %></div>
#       </div>
#        <%= dc_render(:dc_menu, name: 'test-menu') %>
#      </div>
#
#      <div id="page"><%= dc_render(:dc_page) %></div>
#    </div>
#    <div id="site-bottom"><%= dc_render(:dc_piece, name: 'site-bottom') %></div>
#    
#    <style type="text/css"><%= @css.html_safe %></style><%= javascript_tag @js %>
########################################################################
class DcDesign
  include Mongoid::Document
  include Mongoid::Timestamps
  
  field   :name,        type: String
  field   :description, type: String,  default: ''
  field   :body,        type: String,  default: ''
  field   :css,         type: String,  default: ''
  field   :rails_view,  type: String,  default: ''
  field   :author,      type: String
  field   :active,      type: Boolean, default: true 
  field   :created_by,  type: BSON::ObjectId
  field   :updated_by,  type: BSON::ObjectId
  
  embeds_many :dc_parts
#  embeds_many :dc_parts, as: :dc_parts

  index( { name: 1 }, { unique: true } )
  
########################################################################
# Return choices for select for design_id
########################################################################
def self.choices4_design
  all.sort(name: 1).inject([]) { |r,design| r << [ design.description, design._id] if design.active; r }
end
  
end
