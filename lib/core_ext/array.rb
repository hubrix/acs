class Array
  def chunk_it(pieces=3)
    len = self.length;
    mid = (len/pieces)
    chunks = []
    start = 0
    1.upto(pieces) do |i|
      last = start+mid
      last = last-1 unless len%pieces >= i
      chunks << self[start..last] || []
      start = last+1
    end
    chunks
  end

  def chunker(pieces = 3)
    # this gets the correct number, but seems like it should be easier
    height = ((self.size - (self.size % pieces)) / pieces)+ (self.size % pieces == 0 ? 0 : 1)
    chunks = []
    0.upto(height - 1) do |i|
      chunks << [ self[i], self[i + height], self[i + (height * 2)] ]
    end
    chunks
  end
end
