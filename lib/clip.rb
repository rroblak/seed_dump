# by digitalross: http://stackoverflow.com/questions/1604305/all-but-last-element-of-ruby-array
class Array
  def clip n=1
    take size - n
  end
end
