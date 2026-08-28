class String
  def titleize
    # Acronyms that must not be sentence-cased in a job or department title.
    # Anything specific to one employer's brands or business units has been
    # taken out; what is left is generic to any org chart.
    #
    # The roman numerals are seniority levels ("Analyst II"). Only the
    # multi-letter ones need an entry -- I, V and X are single letters, which
    # titleize already leaves capitalised. The word boundaries keep II from
    # matching inside III, so their order here does not matter.
    upcased_words = ['II', 'III', 'IV', 'VI', 'VII', 'VIII', 'IX',
                     'IT', 'US', 'UK', 'JV', 'SVP', 'VP', 'CEO', 'CFO', 'CIO', 'CTO',
                     'HR', 'QA', 'DB', 'IA', 'CS']
    result = ActiveSupport::Inflector.titleize(self).gsub(/\s{2,}/, ' ').gsub(/(.{1,}\..{2,}\b|.*\d{2}$)/) { |w| w.downcase }.strip.gsub(/(^\W|\s$)/, '').gsub(/(^'|'$)/,'')
    upcased_words.each do |word|
      result.gsub!(/\b#{word}\b/i,word)
    end
    result
  end
  
  def downcase_underscore
    self.downcase.gsub(/ /,'_')
  end
end