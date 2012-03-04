class Formula

  class << self

    def class_s name
      # remove invalid characters and then camelcase it
      name.capitalize.gsub(/[-_.\s]([a-zA-Z0-9])/){ $1.upcase }.gsub('+', 'x')
    end

    # an array of all Formula names
    def names
      Dir["#{HOMEBREW_REPOSITORY}/Library/Formula/*.rb"].map{ |f| File.basename f, '.rb' }.sort
    end

    # an array of all Formula, instantiated
    def all
      map{ |f| f }
    end

    def map
      rv = []
      each{ |f| rv << yield(f) }
      rv
    end

    def each
      names.each do |n|
        begin
          yield Formula.factory(n)
        rescue
          # Don't let one broken formula break commands. But do complain.
          onoe "Formula #{n} will not import."
        end
      end
    end

    def aliases
      Dir["#{HOMEBREW_REPOSITORY}/Library/Aliases/*"].map{ |f| File.basename f }.sort
    end

    def canonical_name name
      name = name.to_s if name.kind_of? Pathname

      formula_with_that_name = HOMEBREW_REPOSITORY+"Library/Formula/#{name}.rb"
      possible_alias = HOMEBREW_REPOSITORY+"Library/Aliases/#{name}"
      possible_cached_formula = HOMEBREW_CACHE_FORMULA+"#{name}.rb"

      if name.include? "/"
        if name =~ %r{(.+)/(.+)/(.+)}
          tapd = HOMEBREW_REPOSITORY/"Library/Taps/#$1-#$2"
          tapd.find_formula do |relative_pathname|
            return "#{tapd}/#{relative_pathname}" if relative_pathname.stem.to_s == $3
          end if tapd.directory?
        end
        # Otherwise don't resolve paths or URLs
        name
      elsif formula_with_that_name.file? and formula_with_that_name.readable?
        name
      elsif possible_alias.file?
        possible_alias.realpath.basename('.rb').to_s
      elsif possible_cached_formula.file?
        possible_cached_formula.to_s
      else
        name
      end
    end

    def path name
      HOMEBREW_REPOSITORY+"Library/Formula/#{name.downcase}.rb"
    end

    def expand_deps f
      f.deps.map do |dep|
        dep = Formula.factory dep
        expand_deps(dep) << dep
      end
    end

  end

end