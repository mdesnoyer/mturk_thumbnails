# Helper methods defined here can be accessed in any controller or view in the application

MturkThumbnails.helpers do
  # def asset_path(kind, source)
  #   return source if source =~ /^http/
  #   is_absolute  = source =~ %r{^/}
  #   asset_folder = asset_folder_name(kind)
  #   source = source.to_s.gsub(/\s/, '%20')
  #   ignore_extension = (asset_folder.to_s == kind.to_s) || (kind == :images)
  #   source << ".#{kind}" unless ignore_extension or source =~ /\.#{kind}/
  #   result_path = is_absolute ? source : uri_root_path(asset_folder, source)
  #   timestamp = asset_timestamp(result_path, is_absolute)
  #   "#{result_path}#{timestamp}"
  # end

  # def asset_folder_name(kind)
  #   case kind
  #   when :css then 'assets'
  #   when :js  then 'assets'
  #   when :images  then 'assets'
  #   else kind.to_s
  #   end
  # end

  def link_to(*args, &block)
    options = args.extract_options!
    anchor  = "##{CGI.escape options.delete(:anchor).to_s}" if options[:anchor]

    query = options.delete(:query)

    if block_given?
      url = args[0] ? args[0] + anchor.to_s : anchor || '#'
      if query
        uri = URI(url)
        uri.query = query.respond_to?(:to_param) ? query.to_param : query.to_s
        url = uri.to_s
      end
      options.reverse_merge!(:href => url)
      link_content = capture_html(&block)
      return '' unless parse_conditions(url, options)
      result_link = content_tag(:a, link_content, options)
      block_is_template?(block) ? concat_content(result_link) : result_link
    else
      name, url = args[0], (args[1] ? args[1] + anchor.to_s : anchor || '#')
      if query
        uri = URI(url)
        uri.query = query.respond_to?(:to_param) ? query.to_param : query.to_s
        url = uri.to_s
      end
      return name unless parse_conditions(url, options)
      options.reverse_merge!(:href => url)
      content_tag(:a, name, options)
    end
  end
end
