require 'download_strategy'
require 'extend/fileutils'
require 'formula+boilerplate'
require 'formula+brew'
require 'formula+cc'
require 'formula+factory'
require 'formula+getters'
require 'formula+self'
require 'formula_support'
require 'hardware'


class Formula  

  # Will be useful to you
  include FileUtils

  # tell the user about any caveats regarding this package, return a string
  def caveats; nil end

  # any e.g. configure options for this package
  def options; [] end

  # patches are automatically applied after extracting the tarball
  # return an array of strings, or if you need a patch level other than -p1
  # return a Hash eg.
  #   {
  #     :p0 => ['http://foo.com/patch1', 'http://foo.com/patch2'],
  #     :p1 =>  'http://bar.com/patch2',
  #     :p2 => ['http://moo.com/patch5', 'http://moo.com/patch6']
  #   }
  # The final option is to return DATA, then put a diff after __END__. You
  # can still return a Hash with DATA as the value for a patch level key.
  def patches; end

  # Standard parameters for CMake builds.
  # Using Build Type "None" tells cmake to use our CFLAGS,etc. settings.
  # Setting it to Release would ignore our flags.
  # Note: there isn't a std_autotools variant because autotools is a lot
  # less consistent and the standard parameters are more memorable.
  def std_cmake_parameters
    "-DCMAKE_INSTALL_PREFIX='#{prefix}' -DCMAKE_BUILD_TYPE=None -Wno-dev"
  end


  # Formula's DSL

  class << self
    attr_reader :standard, :unstable

    def self.attr_rw(*attrs)
      attrs.each do |attr|
        class_eval %Q{
          def #{attr}(val=nil)
            val.nil? ? @#{attr} : @#{attr} = val
          end
        }
      end
    end

    attr_rw :version, :homepage, :mirrors, :specs, :deps, :external_deps
    attr_rw :keg_only_reason, :fails_with_llvm_reason, :skip_clean_all
    attr_rw :bottle_url, :bottle_sha1
    attr_rw *CHECKSUM_TYPES

    def head val=nil, specs=nil
      return @head if val.nil?
      @unstable = SoftwareSpecification.new(val, specs)
      @head = val
      @specs = specs
    end

    def url val=nil, specs=nil
      return @url if val.nil?
      @standard = SoftwareSpecification.new(val, specs)
      @url = val
      @specs = specs
    end

    def stable &block
      raise "url and md5 must be specified in a block" unless block_given?
      instance_eval &block unless ARGV.build_devel? or ARGV.build_head?
    end

    def devel &block
      raise "url and md5 must be specified in a block" unless block_given?

      if ARGV.build_devel?
        # clear out mirrors from the stable release
        @mirrors = nil

        instance_eval &block
      end
    end

    def bottle url=nil, &block
      if block_given?
        eval <<-EOCLASS
        module BottleData
          def self.url url; @url = url; end
          def self.sha1 sha1; @sha1 = sha1; end
          def self.return_data; [@url,@sha1]; end
        end
        EOCLASS
        BottleData.instance_eval &block
        @bottle_url, @bottle_sha1 = BottleData.return_data
      end
    end

    def mirror val, specs=nil
      @mirrors ||= []
      @mirrors << {:url => val, :specs => specs}
      # Added the uniq after some inspection with Pry---seems `mirror` gets
      # called three times. The first two times only one copy of the input is
      # left in `@mirrors`. On the final call, two copies are present. This
      # happens with `@deps` as well. Odd.
      @mirrors.uniq!
    end

    def depends_on name
      @deps ||= []
      @external_deps ||= {:python => [], :perl => [], :ruby => [], :jruby => [], :chicken => [], :rbx => [], :node => [], :lua => []}

      case name
      when String, Formula
        @deps << name
      when Hash
        key, value = name.shift
        case value
        when :python, :perl, :ruby, :jruby, :chicken, :rbx, :node, :lua
          @external_deps[value] << key
        when :optional, :recommended, :build
          @deps << key
        else
          raise "Unsupported dependency type #{value}"
        end
      when Symbol
        opoo "#{self.name} -- #{name}: Using symbols for deps is deprecated; use a string instead"
        @deps << name.to_s
      else
        raise "Unsupported type #{name.class}"
      end
    end

    def skip_clean paths
      if paths == :all
        @skip_clean_all = true
        return
      end
      @skip_clean_paths ||= []
      [paths].flatten.each do |p|
        @skip_clean_paths << p.to_s unless @skip_clean_paths.include? p.to_s
      end
    end

    def keg_only reason, explanation=nil
      @keg_only_reason = KegOnlyReason.new(reason, explanation.to_s.chomp)
    end

    def fails_with_llvm msg=nil, data=nil
      @fails_with_llvm_reason = FailsWithLLVM.new(msg, data)
    end
  end
end



# See youtube-dl.rb for an example
class ScriptFileFormula < Formula
  def install
    bin.install Dir['*']
  end
end

# See flac.rb for an example
class GithubGistFormula < ScriptFileFormula
  def initialize name='__UNKNOWN__', path=nil
    super name, path
    @version=File.basename(File.dirname(url))[0,6]
  end
end
