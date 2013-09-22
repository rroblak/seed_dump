class Sample < ActiveRecord::Base

  alias_method :orig_attributes, :attributes
  def attributes
    orig_attributes.merge({ ['col1', 'col2', 'col3'] => 'ABC' })
  end

end
