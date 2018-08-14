# Adapted from https://rubyplus.com/articles/3401-Customize-Field-Error-in-Rails-5
ActionView::Base.field_error_proc = Proc.new do |html_tag, instance|
  html = ''

  form_fields = [
      'textarea',
      'input',
      'select'
  ]

  elements = Nokogiri::HTML::DocumentFragment.parse(html_tag).css "label, " + form_fields.join(', ')

  elements.each do |e|
    if e.node_name.eql? 'label'
      html = %(#{e}).html_safe
    elsif form_fields.include? e.node_name
      e['class'] += ' is-invalid'
      e['data-toggle'] = 'tooltip'
      Rails.logger.info instance.inspect
      if instance.error_message.kind_of?(Array)
        e['title'] = instance.error_message.uniq.join(', ')
      else
        e['title'] = instance.error_message
      end
      html = %(#{e}).html_safe
    end
  end
  html
end