# All *simple* getters and attributes

class Formula
  attr_reader :name, :path, :url, :version, :homepage, :specs, :downloader
  attr_reader :standard, :unstable
  attr_reader :bottle_url, :bottle_sha1, :head

  # The build folder, usually in /tmp.
  # Will only be non-nil during the stage method.
  attr_reader :buildpath

  # if the dir is there, but it's empty we consider it not installed
  def installed?
    return installed_prefix.children.length > 0
  rescue
    return false
  end

  def bottle_up_to_date?
    !bottle_url.nil? && Pathname.new(bottle_url).version == version
  end

  def explicitly_requested?
    # `ARGV.formulae` will throw an exception if it comes up with an empty list.
    # FIXME: `ARGV.formulae` shouldn't be throwing exceptions, see issue #8823
   return false if ARGV.named.empty?
   ARGV.formulae.include? self
  end

  def linked_keg
    HOMEBREW_REPOSITORY/'Library/LinkedKegs'/@name
  end

  def installed_prefix
    head_prefix = HOMEBREW_CELLAR+@name+'HEAD'
    if @version == 'HEAD' || head_prefix.directory?
      head_prefix
    else
      prefix
    end
  end

  def path
    if @path.nil?
      Formula.path(name)
    else
      @path
    end
  end

  def prefix
    HOMEBREW_CELLAR+@name+@version
  end

  def rack
    prefix.parent
  end

  def bin;     prefix+'bin'            end
  def doc;     prefix+'share/doc'+name end
  def include; prefix+'include'        end
  def info;    prefix+'share/info'     end
  def lib;     prefix+'lib'            end
  def libexec; prefix+'libexec'        end
  def man;     prefix+'share/man'      end
  def man1;    man+'man1'              end
  def man2;    man+'man2'              end
  def man3;    man+'man3'              end
  def man4;    man+'man4'              end
  def man5;    man+'man5'              end
  def man6;    man+'man6'              end
  def man7;    man+'man7'              end
  def man8;    man+'man8'              end
  def sbin;    prefix+'sbin'           end
  def share;   prefix+'share'          end

  # configuration needs to be preserved past upgrades
  def etc; HOMEBREW_PREFIX+'etc' end
  # generally we don't want var stuff inside the keg
  def var; HOMEBREW_PREFIX+'var' end

  # plist name, i.e. the name of the launchd service
  def plist_name; 'homebrew.mxcl.'+name end
  def plist_path; prefix+(plist_name+'.plist') end

  # Use the @spec_to_use to detect the download strategy.
  # Can be overriden to force a custom download strategy
  def download_strategy
    @spec_to_use.download_strategy
  end

  def cached_download
    @downloader.cached_location
  end

  # rarely, you don't want your library symlinked into the main prefix
  # see gettext.rb for an example
  def keg_only?
    self.class.keg_only_reason || false
  end

  # sometimes the clean process breaks things
  # skip cleaning paths in a formula with a class method like this:
  #   skip_clean [bin+"foo", lib+"bar"]
  # redefining skip_clean? now deprecated
  def skip_clean? path
    return true if self.class.skip_clean_all?
    to_check = path.relative_path_from(prefix).to_s
    self.class.skip_clean_paths.include? to_check
  end

  def mirrors
    self.class.mirrors or []
  end

  def deps
    self.class.deps or []
  end

  def external_deps
    self.class.external_deps or {}
  end

  # deps are in an installable order
  # which means if a depends on b then b will be ordered before a in this list
  def recursive_deps
    Formula.expand_deps(self).flatten.uniq
  end


  private

  CHECKSUM_TYPES = [:md5, :sha1, :sha256].freeze

  # Detect which type of checksum is being used, or nil if none
  def checksum_type
    CHECKSUM_TYPES.detect { |type| instance_variable_defined?("@#{type}") }
  end

  def self.skip_clean_all?
    @skip_clean_all
  end

  def self.skip_clean_paths
    @skip_clean_paths or []
  end

end
