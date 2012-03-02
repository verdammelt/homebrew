# Entry points called during download, build and install.

class Formula

  # yields self with current working directory set to the uncompressed tarball
  def brew
    validate_variable :name    # needed to install
    validate_variable :version # needed to install

    handle_llvm_failure(fails_with_llvm?) if fails_with_llvm?

    stage do
      begin
        patch
        # we allow formulas to do anything they want to the Ruby process
        # so load any deps before this point! And exit asap afterwards
        yield self
      rescue Interrupt, RuntimeError, SystemCallError => e
        unless ARGV.debug?
          logs = File.expand_path '~/Library/Logs/Homebrew/'
          if File.exist? 'config.log'
            mkdir_p logs
            mv 'config.log', logs
          end
          if File.exist? 'CMakeCache.txt'
            mkdir_p logs
            mv 'CMakeCache.txt', logs
          end
          raise
        end
        onoe e.inspect
        puts e.backtrace

        ohai "Rescuing build..."
        if (e.was_running_configure? rescue false) and File.exist? 'config.log'
          puts "It looks like an autotools configure failed."
          puts "Gist 'config.log' and any error output when reporting an issue."
          puts
        end

        puts "When you exit this shell Homebrew will attempt to finalise the installation."
        puts "If nothing is installed or the shell exits with a non-zero error code,"
        puts "Homebrew will abort. The installation prefix is:"
        puts prefix
        interactive_shell self
      end
    end
  end

  def fetch
    downloader = @downloader
    # Don't attempt mirrors if this install is not pointed at a "stable" URL.
    # This can happen when options like `--HEAD` are invoked.
    mirror_list =  @spec_to_use == @standard ? mirrors : []

    # Ensure the cache exists
    HOMEBREW_CACHE.mkpath

    begin
      fetched = downloader.fetch
    rescue CurlDownloadStrategyError => e
      raise e if mirror_list.empty?
      puts "Trying a mirror..."
      url, specs = mirror_list.shift.values_at :url, :specs
      downloader = download_strategy.new url, name, version, specs
      retry
    end

    return fetched, downloader
  end

  # For FormulaInstaller.
  def verify_download_integrity fn, *args
    require 'digest'
    if args.length != 2
      type = checksum_type || :md5
      supplied = instance_variable_get("@#{type}")
      # Convert symbol to readable string
      type = type.to_s.upcase
    else
      supplied, type = args
    end

    hasher = Digest.const_get(type)
    hash = fn.incremental_hash(hasher)

    if supplied and not supplied.empty?
      message = <<-EOF.undent
        #{type} mismatch
        Expected: #{supplied}
        Got: #{hash}
        Archive: #{fn}
        (To retry an incomplete download, remove the file above.)
      EOF
      raise message unless supplied.upcase == hash.upcase
    else
      opoo "Cannot verify package integrity"
      puts "The formula did not provide a download checksum"
      puts "For your reference the #{type} is: #{hash}"
    end
  end

  def stage
    fetched, downloader = fetch
    verify_download_integrity fetched if fetched.kind_of? Pathname
    mktemp do
      downloader.stage
      # Set path after the downloader changes the working folder.
      @buildpath = Pathname.pwd
      yield
      @buildpath = nil
    end
  end

  private

  def patch
    # Only call `patches` once.
    # If there is code in `patches`, which is not recommended, we only
    # want to run that code once.
    the_patches = patches
    return if the_patches.nil?

    if not the_patches.kind_of? Hash
      # We assume -p1
      patch_defns = { :p1 => the_patches }
    else
      patch_defns = the_patches
    end

    patch_list=[]
    n=0
    patch_defns.each do |arg, urls|
      # DATA.each does each line, which doesn't work so great
      urls = [urls] unless urls.kind_of? Array

      urls.each do |url|
        p = {:filename => '%03d-homebrew.diff' % n+=1, :compression => false}

        if defined? DATA and url == DATA
          pn = Pathname.new p[:filename]
          pn.write(DATA.read.to_s.gsub("HOMEBREW_PREFIX", HOMEBREW_PREFIX))
        elsif url =~ %r[^\w+\://]
          out_fn = p[:filename]
          case url
          when /\.gz$/
            p[:compression] = :gzip
            out_fn += '.gz'
          when /\.bz2$/
            p[:compression] = :bzip2
            out_fn += '.bz2'
          end
          p[:curl_args] = [url, '-o', out_fn]
        else
          # it's a file on the local filesystem
          p[:filename] = url
        end

        p[:args] = ["-#{arg}", '-i', p[:filename]]

        patch_list << p
      end
    end

    return if patch_list.empty?

    external_patches = patch_list.collect{|p| p[:curl_args]}.select{|p| p}.flatten
    unless external_patches.empty?
      ohai "Downloading patches"
      # downloading all at once is much more efficient, especially for FTP
      curl(*external_patches)
    end

    ohai "Patching"
    patch_list.each do |p|
      case p[:compression]
        when :gzip  then safe_system "/usr/bin/gunzip",  p[:filename]+'.gz'
        when :bzip2 then safe_system "/usr/bin/bunzip2", p[:filename]+'.bz2'
      end
      # -f means it doesn't prompt the user if there are errors, if just
      # exits with non-zero status
      safe_system '/usr/bin/patch', '-f', *(p[:args])
    end
  end

  protected

  # Pretty titles the command and buffers stdout/stderr
  # Throws if exit code is not zero
  def system cmd, *args
    # remove "boring" arguments so that the important ones are more likely to
    # be shown considering that we trim long ohai lines to the terminal width
    pretty_args = args.dup
    pretty_args.delete "--disable-dependency-tracking" if cmd == "./configure" and not ARGV.verbose?
    ohai "#{cmd} #{pretty_args*' '}".strip

    removed_ENV_variables = case if args.empty? then cmd.split(' ').first else cmd end
    when "xcodebuild"
      ENV.remove_cc_etc
    end

    if ARGV.verbose?
      safe_system cmd, *args
    else
      rd, wr = IO.pipe
      pid = fork do
        rd.close
        $stdout.reopen wr
        $stderr.reopen wr
        args.collect!{|arg| arg.to_s}
        exec(cmd, *args) rescue nil
        exit! 1 # never gets here unless exec threw or failed
      end
      wr.close
      out = ''
      out << rd.read until rd.eof?
      Process.wait
      unless $?.success?
        puts out
        raise
      end
    end

    removed_ENV_variables.each do |key, value|
      ENV[key] = value # ENV.kind_of? Hash  # => false
    end if removed_ENV_variables

  rescue
    raise BuildError.new(self, cmd, args, $?)
  end
end
