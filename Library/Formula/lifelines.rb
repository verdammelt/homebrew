require 'formula'

class Lifelines < Formula
  homepage 'http://lifelines.sourceforge.net/'
<<<<<<< HEAD
  url 'http://downloads.sourceforge.net/project/lifelines/lifelines/3.0.62/lifelines-3.0.62.tar.gz'
  sha1 'cbb215167082b9f029e03c86c143d30148e8d3c1'
=======
  url 'http://sourceforge.net/projects/lifelines/files/lifelines/3.0.62/lifelines-3.0.62.tar.gz'
  md5 'ff617e64205763c239b0805d8bbe19fe'
>>>>>>> Adding formula for LifeLines - a curses based geneology tool

  def install
    system "./configure", "--disable-debug", "--disable-dependency-tracking",
                          "--prefix=#{prefix}"
<<<<<<< HEAD
    system "make install"
=======
    system "make install" 
>>>>>>> Adding formula for LifeLines - a curses based geneology tool
  end
end
