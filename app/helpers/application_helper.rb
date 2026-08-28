module ApplicationHelper
  
  def table_info_row(items, options = {})
    if items.respond_to? :total_pages
      render :partial => 'shared/pagination_row', :locals => { :items => items, :colspan => options[:colspan] }
    else
      render :partial => 'shared/no_pagination_row', :locals => { :items => items, :colspan => options[:colspan], :item_type => options[:item_type] }
    end
  end
  
  # Renders a <button> rather than <input type="submit">.
  #
  # This used to be a copy of Rails 3's button_to with the input swapped for a
  # button, reaching into private ActionView internals. Rails 5 added block
  # form to button_to, which produces the same markup.
  def real_button_to(name, options = {}, html_options = {})
    button_to(options, html_options) { name }
  end
end
