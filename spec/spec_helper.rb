require 'pry'
require 'abbr'

module PlusOne
  extend Abbr::Mixin

  abbr_init :n

  def to_i
    n + 1
  end
end # XPlusOne

class MissingNPlusOne
  include PlusOne

  abbr_init :not_n
end # NPlusOne

class XPlusOne
  include PlusOne

  abbr_init :x

  def n
    x
  end
end # XPlusOne

class YPlusOne
  include PlusOne

  abbr_init :y

  def n
    y
  end
end # YPlusOne

class XPlusOneTracksMemo < XPlusOne
  abbr_init :x, memo_output: []

  let(:memo!) do
    to_i.tap do |int|
      memo_output << int
    end
  end
end # XPlusOneTracksMemo