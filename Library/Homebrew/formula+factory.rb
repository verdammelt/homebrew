class Formula

  def self.factory name
    # If an instance of Formula is passed, just return it
    return name if name.kind_of? Formula

    # Otherwise, convert to String in case a Pathname comes in
    name = name.to_s

    # If a URL is passed, download to the cache and install
    if name =~ %r[(https?|ftp)://]
      url = name
      name = Pathname.new(name).basename
      target_file = HOMEBREW_CACHE_FORMULA+name
      name = name.basename(".rb").to_s

      HOMEBREW_CACHE_FORMULA.mkpath
      rm target_file, :force => true
      curl url, '-o', target_file

      require target_file
      install_type = :from_url
    else
      name = Formula.canonical_name(name)
      # If name was a path or mapped to a cached formula
      if name.include? "/"
        require name
        path = Pathname.new(name)
        name = path.stem
        install_type = :from_path
        target_file = path.to_s
      else
        # For names, map to the path and then require
        require Formula.path(name)
        install_type = :from_name
      end
    end

    begin
      klass_name = self.class_s(name)
      klass = Object.const_get klass_name
    rescue NameError
      # TODO really this text should be encoded into the exception
      # and only shown if the UI deems it correct to show it
      onoe "class \"#{klass_name}\" expected but not found in #{name}.rb"
      puts "Double-check the name of the class in that formula."
      raise LoadError
    end

    return klass.new(name, nil) if install_type == :from_name
    return klass.new(name, target_file)
  rescue LoadError => e
    raise FormulaUnavailableError.new(name)
  end

  protected

  # Homebrew determines the name
  def initialize name, path
    set_instance_variable 'homepage'
    set_instance_variable 'url'
    set_instance_variable 'bottle_url'
    set_instance_variable 'bottle_sha1'
    set_instance_variable 'head'
    set_instance_variable 'specs'

    set_instance_variable 'standard'
    set_instance_variable 'unstable'

    if @head and (not @url or ARGV.build_head?)
      @url = @head
      @version = 'HEAD'
      @spec_to_use = @unstable
    else
      if @standard.nil?
        @spec_to_use = SoftwareSpecification.new(@url, @specs)
      else
        @spec_to_use = @standard
      end
    end

    raise "No url provided for formula #{name}" if @url.nil?
    @name = name
    validate_variable :name

    @path = path.nil? ? nil : Pathname.new(path)

    set_instance_variable 'version'
    @version ||= @spec_to_use.detect_version
    validate_variable :version if @version

    CHECKSUM_TYPES.each { |type| set_instance_variable type }

    @downloader = download_strategy.new @spec_to_use.url, name, version, @spec_to_use.specs
  end

  private

  def set_instance_variable(type)
    unless instance_variable_defined? "@#{type}"
      class_value = self.class.send(type)
      instance_variable_set("@#{type}", class_value) if class_value
    end
  end

  def validate_variable name
    v = instance_variable_get("@#{name}")
    raise "Invalid @#{name}" if v.to_s.empty? or v =~ /\s/
  end

end
