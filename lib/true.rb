# http://veerasundaravel.wordpress.com/2010/10/26/string-to-boolean-conversion-in-ruby/
class Object 
  def true? # to boolean
    return false if self.nil?
    return true if self == true || self =~ (/(true|t|yes|y|1)$/i)
    return false if self == false || self.nil? || self =~ (/(false|f|no|n|0)$/i)
    raise ArgumentError.new('invalid value for Boolean: "#{self}"')
  end
end
