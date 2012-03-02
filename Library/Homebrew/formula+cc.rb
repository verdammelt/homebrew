# Code that handles gcc/llvm/clang issues in this file

class Formula

  private

  def handle_llvm_failure llvm
    if ENV.compiler == :llvm
      # llvm-gcc-2336.9.00 comes with Xcode 4.3
      if llvm.build.to_i >= 2336
        if MacOS.xcode_version < "4.2"
          opoo "Formula will not build with LLVM, using GCC"
          ENV.gcc
        else
          opoo "Formula will not build with LLVM, trying Clang"
          ENV.clang
        end
        return
      end
      opoo "Building with LLVM, but this formula is reported to not work with LLVM:"
      puts
      puts llvm.reason
      puts
      puts <<-EOS.undent
        We are continuing anyway so if the build succeeds, please open a ticket with
        the following information: #{MacOS.llvm_build_version}-#{MACOS_VERSION}. So
        that we can update the formula accordingly. Thanks!
        EOS
      puts
      if MacOS.xcode_version < "4.2"
        puts "If it doesn't work you can: brew install --use-gcc"
      else
        puts "If it doesn't work you can try: brew install --use-clang"
      end
      puts
    end
  end

  def fails_with_llvm?
    llvm = self.class.fails_with_llvm_reason
    if llvm
      if llvm.build and MacOS.llvm_build_version.to_i > llvm.build.to_i
        false
      else
        llvm
      end
    end
  end

end


# Used to annotate formulae that won't build correctly with LLVM.
class FailsWithLLVM
  attr_reader :msg, :data, :build

  def initialize msg=nil, data=nil
    if msg.nil? or msg.kind_of? Hash
      @msg = "(No specific reason was given)"
      data = msg
    else
      @msg = msg
    end
    @data = data
    @build = data.delete :build rescue nil
  end

  def reason
    s = @msg
    s += "Tested with LLVM build #{@build}" unless @build == nil
    s += "\n"
    return s
  end
end
