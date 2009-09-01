INSTALLER_VERSION = "1.2.3"

=begin

Contact Info:
  Tim Hunter, rmagick@rubyforge.org, http://rmagick.rubyforge.org 
  
Usage: 
  See the README.rtf file that accompanies this script.
  
Credits: 
  Thanks to the following people for providing prior art and/or advice. In no
  way are they responsible for any errors in this program.
  Dan Benjamin, "Building RMagick on OS X", http://hivelogic.com/narrative/articles/rmagick_os_x
  Ezra Zygmuntowic
  Ara T. Howard 
  
  Copyright (c) 2009 Timothy P. Hunter

  Permission is hereby  granted, free of charge, to any  person obtaining a copy
  of this software and associated  documentation files (the "Software"), to deal
  in the Software  without restriction, including without  limitation the rights
  to  use, copy,  modify, merge,  publish, distribute,  sublicense, and/or  sell
  copies  of  the Software,  and  to  permit persons  to  whom  the Software  is
  furnished to do so, subject to the following conditions:

  The above copyright notice and this permission notice shall be included in all
  copies or substantial portions of the Software.

  THE SOFTWARE  IS PROVIDED "AS  IS", WITHOUT WARRANTY  OF ANY KIND,  EXPRESS OR
  IMPLIED,  INCLUDING BUT  NOT  LIMITED TO  THE  WARRANTIES OF  MERCHANTABILITY,
  FITNESS FOR  A PARTICULAR PURPOSE AND  NONINFRINGEMENT. IN NO EVENT  SHALL THE
  AUTHORS  OR COPYRIGHT  HOLDERS  BE  LIABLE FOR  ANY  CLAIM,  DAMAGES OR  OTHER
  LIABILITY, WHETHER IN AN ACTION OF  CONTRACT, TORT OR OTHERWISE, ARISING FROM,
  OUT OF OR IN CONNECTION WITH THE SOFTWARE  OR THE USE OR OTHER DEALINGS IN THE
  SOFTWARE.
=end

require 'rbconfig'
require 'ostruct'
require 'net/ftp'
require 'fileutils'
require 'open-uri'
require 'optparse'

include FileUtils


SERVER        = "ftp.imagemagick.org"
SERVER_URL    = "ftp://" + SERVER
PUB_DIR       = "/pub/ImageMagick"
DOWNLOAD_DIR  = SERVER + PUB_DIR
DOWNLOAD_URL  = SERVER_URL + PUB_DIR
DELEGATES_DIR = PUB_DIR + "/delegates"
DELEGATES_URL = DOWNLOAD_URL + "/delegates"
RAA_PROJECT_URL = "http://raa.ruby-lang.org/project/rmagick2"

class Options
  def self.parse(args)
    options = OpenStruct.new
    options.prefix = "/usr/local"
    options.install_dir = "rm_install_tmp"
    options.cleanup = true
    options.tiff = false
    options.im_check = true

    opts = OptionParser.new do |opts|
      opts.banner = "Usage: rm_install.rb [options]"
      opts.separator ""
      opts.separator "Options:"
            
      opts.on("--prefix PREFIX", "By default, all files will be installed",
                                 "in this directory. [--prefix /usr/local]") do |prefix|
        unless FileTest.exist? prefix
          abort "No such directory #{prefix}"
        end
        options.prefix = prefix
      end
      
      opts.on("--install-dir DIRECTORY", "Download files and run builds in this directory.",
                                         "If the directory doesn't exist it will be created.",
                                         "[--install-dir ./rm_install_tmp]") do |dir|
        options.install_dir = dir
      end                                            
                                        
      opts.on("--[no-]cleanup", "Delete the installation directory upon completion.",
                                "You may want to keep the installation directory in",
                                "case you want to uninstall something. [--cleanup]") do |v|
        options.cleanup = v
      end
      
      opts.on("--[no-]im-check", "Check for a previously installed version of ImageMagick.",
                                 "[--im-check]") do |v|
        options.im_check = v
      end
                                   
      opts.on("--[no-]tiff", "Install libtiff. [--no-tiff]") do |v|
        options.tiff = v
      end
    
      opts.on_tail("-?", "--help", "Show this message") do
        puts opts
        exit
      end
    end
  
    opts.parse!(args)
    options
    
  end
end

module Log
  def open_log(name)
    $stdout.sync = true
    @log = File.open(name, "w")
    @log.sync = true
    @log.print "RMagick Installer Log - ", Time.now, " - Working directory: ", Dir.pwd
  end
  
  def now
    Time.now.strftime("%H:%M:%S: ")
  end
  
  def log(msg)
    @log.print now, msg, "\n"
  end
  
  def say(msg)
    puts msg
    log msg
  end
  
  def log_exec(prefix, suffix="Done")
    $stdout.write prefix + "..."
    @log.write now
    @log.write prefix + "..."
    yield
    @log.write suffix + "\n"
    $stdout.write suffix + "\n"
  end
  
  def in_box(title)
    log "\n"
    log(("=" * 10) + title + ("=" * (60-title.length)))
    yield
    log(("=" * 10) + ("END " + title) + ("=" * (60-(4+title.length))))
    log "\n"
  end
  
  def log_exception(exc)
    log "#{exc.to_s} (#{exc.class})"
    exc.backtrace.each { |line| log line }
  end
  
  def log_append(name)
    @log.puts "#{'=' * 20} BEGIN #{name} #{'=' * 20}"
    File.open(name) do |f|
      while line = f.gets do 
        @log.puts line 
      end
    end
    @log.puts "#{'=' * 20} END #{name} #{'=' * 20}"
  end

	# Dump the environment to the log
	def log_env
	  in_box("ENV") { ENV.each { |var, value|	log "#{var}=#{value}" } }
  end
  
end

class Installer
  DELEGATE_REGEXPS = {
    'libwmf' => /(((libwmf)-(\d+\.\d+\.\d+\.\d+))\.tar\.gz)/,
    'ghostscript' => /(((ghostscript)-\d+\.\d+)\.tar\.gz)/,
    'ghostscript-fonts-std' => /(((ghostscript-fonts-std)-\d+\.\d+)\.tar\.gz)/,
    'libpng' => /(((libpng)-\d+\.\d+\.\d+)\.tar\.gz)/,
    'jpegsrc' => /(((jpegsrc)\.v7)\.tar\.gz)/,
    'freetype' => /(((freetype)-\d+\.\d+\.\d+)\.tar\.gz)/,
     'tiff' => /(((tiff)-\d+\.\d+\.\d+)\.tar\.gz)/
   }
   
   MORE = "Read the README.rtf file for advice about how to correct this problem."

  include Log
  attr_reader :rmagick_uri, :rmagick_tarball, :rmagick_version, :delegate, :prefix
  
	def initialize(args, logfile="install.log")
    @failures = 0
    @summary = ""
    @make_status = 0

    saved_args = args.dup
		options = Options.parse(args)
		
		@prefix = options.prefix
		@install_dir = options.install_dir
		@tiff = options.tiff
		@make_cmd = ENV['MAKE'] || "make"

		open_log logfile
				
	  log "rm_install.rb version #{INSTALLER_VERSION}"
    log `uname -a`
		log "Ruby Version #{RUBY_VERSION}"
		log "Installation prefix #@prefix"
		log "RMagick Download URL: #{ get_RMagick_download_URI }"

    log "Command line: #{$0} #{saved_args.join(' ')}"
    log_env
    check_path @prefix
    check_install_dir
    check_previous_imagemagick options.im_check
    
    in_box("Ruby") do
      begin
        log find_executable("ruby")
        log `ruby --version`
      rescue
        log "ruby not found in #{ENV['PATH']}"
      end
    end
    
    check_prerequisites
    
		log_exec("Getting delegate filenames") { get_delegates(options.tiff) } 

		Kernel::at_exit do
		  if options.cleanup
  	    log_exec("Removing #@install_dir directory") { Dir.chdir @olddir; rm_rf @install_dir } 
	    end
  		@log.close
		end

		unless FileTest::exist? @install_dir
		  log_exec("Creating #@install_dir directory") { mkdir @install_dir }
	  end

		@olddir = Dir.pwd
		Dir.chdir @install_dir

	end
	
	def want_tiff?
	  @tiff
  end

  # Ensure $PREFIX/bin is in the path
  def check_path(prefix)
    bindir = prefix + "/bin"
    dirs = ENV['PATH'].split(':')
    unless dirs.include?(bindir) || dirs.include?(bindir+'/') then
      terminate <<-BINDIR_MSG
      The #{bindir} directory is not one of the directories listed in the
      environmental variable PATH (the list of directories that are searched 
      for programs). Some libraries installed by this script add new programs 
      in #{bindir}. Please add #{bindir} to PATH.
      
      The current value of PATH is #{ENV['PATH']}.
      
      For more information about the PATH environmental variable, see
      http://www.linfo.org/path_env_var.html.
      
      BINDIR_MSG
    end
  end
  
  # Ensure the installation directory doesn't have any blanks in it.
  # Ensure that it isn't in /usr!
  def check_install_dir
    cwd = Dir.pwd
    if cwd[' '] || @install_dir[' '] then
      terminate <<-BLANKS_MSG
      The installation directory '#{cwd + '/' + @install_dir}'
      contains blanks. Some of the install scripts for the dependent libraries 
      can't handle directory names with embedded blanks. Please choose another
      directory.
      
      Have you read the README.rtf file?
      
      BLANKS_MSG
    end
    
    if /^\/usr/.match(cwd) then
      terminate <<-USR_MSG
      Don't make the temporary installation directory a subdirectory of /usr.
      Make it a subdirectory of #{ENV['HOME']} instead.
      
      Have you read the README.rtf file?
      
      USR_MSG
    end
  end

  # Check for a previously installed version of ImageMagick
  def check_previous_imagemagick(im_check)
    im_version = `Magick-config --version` rescue nil
    if im_version.nil? || im_version.empty? then
      say "The message above is normal."
      return
    end
    if !im_check
      say "ImageMagick #{im_version.chomp} is already installed on this system."
      return
    end
    
    terminate <<-VERS_MSG
    ImageMagick #{im_version.chomp} is already installed on this system.
    Having two different versions of ImageMagick usually causes problems, 
    either during installation or when you try to run RMagick. You should
    uninstall the other version before installing a different version with
    this script.

    If you installed the existing version of ImageMagick using this script and
    the version number has not changed, then you can ignore this message.

    To bypass this check use the --no-im-check option.
    
    VERS_MSG
  end
  
	# User must have already installed Ruby header files, X11, and Xcode Tools
	def check_prerequisites	  
                                                                      
    in_box("GCC") do
      begin
        # Allow user to override compiler name. Use same compiler as Ruby,
        # or gcc by default. Handle the case where CC includes options.
        gcc = (ENV['CC'] || Config::CONFIG['CC'] || 'gcc').split.first
        log find_executable(gcc)
        vers = `#{gcc} --version`.split("\n")
        vers.each {|line| log line}
      rescue RuntimeError
        terminate <<-NO_GCC
        Can't find #{gcc} in #{ENV['PATH']}. Did you install the Xcode Tools? 
        #{MORE}

        NO_GCC
      end
    end
    
    # Ruby 1.9.1 puts the header directory in 'rubyhdrdir'/ruby
    if ::Config::CONFIG['rubyhdrdir'] 
      topdir = ::Config::CONFIG['rubyhdrdir'] + "/ruby"
    else
	    topdir = ::Config::CONFIG['topdir'] 
	  end
	  
	  if topdir.nil? || topdir.empty?
	    terminate <<-NO_TOPDIR_NAME 
	    Can't figure out the Ruby header file directory. Did you install
	    Ruby from source? Are you using the version you installed?
  	  This is Ruby #{RUBY_VERSION}
  	  If you're using the version of Ruby that comes with OS X, 
  	  the header files are usually installed with the Xcode Tools.
	    NO_TOPDIR_NAME
	  end
	  
	  if !File.directory?(topdir)
	    terminate <<-NO_TOPDIR
	  Can't find the Ruby header file directory: #{topdir}.
	  Did you install Ruby from source? Are you using the version you installed?
	  This is Ruby #{RUBY_VERSION}
	  #{MORE}
	    
	  NO_TOPDIR
    end
    
	  if !FileTest.exist?(topdir+"/ruby.h")
	    terminate <<-NO_RUBY_H
	  The Ruby header files are supposed to be installed at #{topdir} but aren't there.
	  If you're using the version of Ruby that comes with OS X, 
	  the header files are usually installed with the Xcode Tools.
	  #{MORE}
	    
	  NO_RUBY_H
    end
    
	  unless FileTest.exist? "/usr/X11R6/include/X11/X.h"
	    terminate <<-NO_X11_SDK
	  Can't find /usr/X11R6/include/X11/X.h. Did you install the X11 SDK when you
	  installed the Xcode Tools?
	  #{MORE}
	    
	  NO_X11_SDK
    end
    
    unless FileTest.exist? "/Applications/Utilities/X11.app/Contents/Info.plist"
      terminate <<-NO_X11
    Can't find X11.app in /Applications/Utilities. Did you install X11 from 
    your OS X installation disk? 
    #{MORE}
    
    NO_X11
    end
  end
  
  # Return true if we need to install pkg-config
  def need_pkg_config?
    pkg_config = ENV['PKG_CONFIG'] || 'pkg-config'
    rc = system("#{pkg_config} --atleast-pkgconfig-version 0.9.0")
    return true unless rc # return true if system couldn't run pkg-config
    return $?.to_i == 1   # return true if pkg-config is out-of-date
  end

  def find_executable(name)
    name = File.basename(name)
    ENV['PATH'].split(':').each do |dir|
      path = File.join(dir, name)
      return path if File.exist? path
    end
    raise RuntimeError
  end
	
	def list_delegates
	  in_box("DELEGATES") do
		  @delegate.each do |name, info|
		    say "Delegate library #{info.version} available for installation"
	    end
    end
  end
  
  def confirm_delegates(names)
    names.each do |name|
      unless @delegate.has_key? name
        abort "#{name} not found on ImageMagick's FTP server."
      end
    end
  end  
  
	# Get a list of the current delegate filenames from ImageMagick's server
	def get_delegates(install_tiff)
	  names = %w[libwmf freetype ghostscript ghostscript-fonts-std libpng jpegsrc]
		names << "tiff" if install_tiff
		
	  delegate_entries = Regexp.union(*DELEGATE_REGEXPS.values_at(*names))
    @delegate = {}
    Net::FTP.open(SERVER) do |ftp|
      ftp.login("anonymous", "rmagickinstaller@gmail.com")
      ftp.chdir DELEGATES_DIR
      ftp.passive = true
      ftp.list("*") do |file|
        m = delegate_entries.match file
        if m
          m = m.to_a.compact
          d = OpenStruct.new
          d.tarball = m[1]
          d.version = m[2]
          @delegate[m[3]] = d
        end
      end
    end
    
    confirm_delegates names
    
    # jpegsrc doesn't fit the pattern
    @delegate["jpegsrc"].version = "jpeg-7"
        
    list_delegates
    nil
  end
 
  # Get the URL for the current version of RMagick from raa.ruby-lang.org
  def get_RMagick_download_URI
      page = nil
      begin
        open(RAA_PROJECT_URL) do |f|
          page = f.read
        end
      rescue Timeout::Error
        abort <<-END_RAA_TIMEOUT
        Can't read RMagick's RAA project page (#{RAA_PROJECT_URL})
        because a timeout occurred. This is probably because 
        raa.ruby-lang.org is temporarily down for maintenance. 
        Try again later.
        END_RAA_TIMEOUT
      rescue Exception
        abort <<-END_RAA
        Can't read RMagick's RAA project page (#{RAA_PROJECT_URL})
        to determine which version of RMagick to download.
        END_RAA
      end

      title_re = Regexp.new("<h1>RAA - ([^<]+)</h1>", Regexp::MULTILINE)
      title = title_re.match page
      if title.nil? || title[1] != "rmagick2"
        abort "Unexpected content at RMagick's RAA project page (#{RAA_PROJECT_URL})"
      end

      # Match the "Download" text - not the href in the anchor tag, but the text surrounded by the anchor tag itself.
      url_re = Regexp.new("<a href=\"[^\"]+\">(http://rubyforge.org/frs/download.php/\\d+/((RMagick-\\d\\.\\d+\\.\\d+)\\.tar\\.gz))</a>")
      vers = url_re.match page
      if vers.nil? || vers[1].nil? || vers[1].empty?
        abort "Can't find RMagick's download URL on RMagick's RAA project page (#{RAA_PROJECT_URL})."
      end
      @rmagick_version = vers[3]
      @rmagick_tarball = vers[2]
      @rmagick_uri = vers[1]
  end
  
  def run(&block)
    begin
      instance_eval(&block)
    rescue Exception => exp
      log_exception exp
  	end
	end
  	
	def execute(cmd)
	  IO.popen("#{cmd} 2>&1") do |f|
	    while line = f.gets do
	      log line.chomp
	    end
    end
    $?.exitstatus || 0
  end
	  
	def exec_cmd(cmd)
    say cmd
    status = execute(cmd)
    say "Return code #{status}"
    status
  end         
  
  def untar(tarball)
    exec_cmd "tar xvzf #{tarball}"
  end

  def chdir(newwd)
    oldwd = Dir.pwd
    say "Changing to #{newwd}"
    Dir.chdir(newwd) { yield }
    say "Returning to #{oldwd}"
  end

  def http_download(uri)
    log_exec("Downloading #{uri}") do
      begin
        open(uri) do |fin|
          open(File.basename(uri), "w") do |fout|
            while (buf = fin.read(8192))
              fout.write buf
            end
          end
        end
      rescue Timeout::Error
        abort <<-END_HTTP_DL_TIMEOUT
        A timeout occurred while downloading #{uri}.
        Probably this is a temporary problem with the host. 
        Try again later.
        END_HTTP_DL_TIMEOUT
      end
    end
  end
  
  # Default download dir is /pub/ImageMagick/delegates
  def download(options)
    if options.has_key?(:file)
      file = options[:file]
    else
      file = @delegate[options[:delegate]].tarball
    end
    dir = options.has_key?(:dir) ? options[:dir] : DELEGATES_DIR
    log_exec("Downloading #{file}") do
      Net::FTP.open(SERVER) do |ftp|
        ftp.login("anonymous", "rmagickinstaller@gmail.com")
        ftp.passive = true
        ftp.chdir dir
        ftp.getbinaryfile file
      end
    end
  end

  def setup(stage, sudo=nil)
    if @make_status.zero?
      @make_status = exec_cmd "#{sudo} ruby setup.rb #{stage}"
    else
      say "Skipping #{stage} due to previous failures" 
    end
  end
  
  def configure(*options)
    logfile = options.size > 0 && options[0].has_key?(:log) ? options[0][:log] : "config.log"
    config_opts = options.size > 0 && options[0].has_key?(:options) ? options[0][:options] : ""
    @make_status = exec_cmd "./configure #{config_opts } --prefix=#@prefix"
    log_append logfile
  end
  
  def make
    if @make_status.zero?
      @make_status = exec_cmd @make_cmd
    else
      say "Skipping make due to previous failures"
    end
  end
  
  def install
    if @make_status.zero?
      @make_status = exec_cmd "sudo #@make_cmd install"
    else
      say "Skipping installation due to previous failures"
    end    
  end

  def install_fonts(dir)
    @make_status = exec_cmd "sudo tar xvzf #{delegate["ghostscript-fonts-std"].tarball} -C #{dir}"
  end
  
  def summarize name
    @failures += 1 unless @make_status.zero?
    @summary << name << (@make_status.zero? ? " was " : " was not ") << "installed successfully\n"
    @make_status = 0
  end
  
  def skipped(name)
    @summary << "#{name} was already installed.\n"
  end
  
  def report
    puts "\n\n\nSummary: There were #@failures failures\n\n"
    puts @summary
  end
  
  def terminate(msg)
    say msg
    say "Terminating due to error."
    abort
  end
  
end


puts "Starting the RMagick installer\n\n"

Installer.new(ARGV).run do  
  
  fonts_dir = prefix + "/share/ghostscript/"

  if need_pkg_config?
    in_box("pkg-config") do
      http_download "http://pkgconfig.freedesktop.org/releases/pkg-config-0.21.tar.gz"
      untar "pkg-config-0.21.tar.gz"
      chdir("pkg-config-0.21") do
        configure
        make
        install
      end
    end
  end 

  ENV['PKG_CONFIG'] ||= prefix + "/bin/pkg-config"
  ENV['PKG_CONFIG_PATH'] ||= "/usr/lib/pkgconfig:/usr/local/lib/pkgconfig:/usr/X11/lib/pkgconfig:" + prefix + "/lib/pkgconfig"
  
  # fontconfig is usually installed in /usr/X11/lib. Don't install unless necessary.
  in_box("fontconfig") do
    pkgconfig = ENV['PKG_CONFIG'] || "pkg-config"
    system("#{pkgconfig} --exists 'fontconfig >= 2.1.0'")
    if $?.exitstatus != 0 then
        http_download "http://fontconfig.org/release/fontconfig-2.5.93.tar.gz" 
        untar "fontconfig-2.5.93.tar.gz"
        chdir("fontconfig-2.5.93") do
          configure
          make 
          install
        end
    else
      vers = `#{pkgconfig} --modversion fontconfig`.chomp
      say "fontconfig #{vers} already installed. Skipping."
      skipped "fontconfig #{vers}"
    end
  end

  # PNG - WMF tests for PNG so and install it first
  in_box("PNG") do
    libpng_config = ENV['LIBPNG_CONFIG'] || 'libpng12-config'
    vers = `#{libpng_config} --version`.chomp
    if vers.empty? then
      download :delegate => 'libpng'
      exec_cmd "tar xvzf #{delegate['libpng'].tarball}"
      chdir(delegate["libpng"].version) do
        configure
        make
        install
        summarize "libpng"
      end
    else
      say "libpng #{vers} already installed. Skipping."
      skipped "libpng #{vers}"
      # Some new installations of OS X 10.5.5 don't have this required symlink. Create it if necessary.
      if ! File.exist?("/usr/X11/lib/libpng.3.0.0.dylib")
        chdir("/usr/X11/lib") { exec_cmd "sudo ln -s libpng.3.dylib libpng.3.0.0.dylib" }
	    end
    end
  end
  
  # JPEG - prereq for Ghostscript
  in_box("JPEG") do
    exec_cmd "sudo mkdir -p #{prefix}/lib #{prefix}/include #{prefix}/man/man1"
    download :delegate => 'jpegsrc'
    untar "#{delegate['jpegsrc'].tarball}"
    chdir(delegate["jpegsrc"].version) do
      ENV['MACOSX_DEPLOYMENT_TARGET'] = '10.4'
      glibtool = `which glibtool`.chomp
      log_exec("Symlinking #{glibtool}") do
        ln_s(glibtool, "libtool")  rescue log "glibtool already symlinked as libtool"
      end
      configure :options => "--enable-shared"
      make
      install
      summarize "libjpeg"
    end
  end

  # Ghostscript
  in_box("Ghostscript") do
    download :delegate => 'ghostscript'
    untar "#{delegate['ghostscript'].tarball}"
    chdir(delegate["ghostscript"].version) do
      configure
      make
      install
      summarize "ghostscript"
    end
  end

  # Ghostscript fonts
  in_box("Ghostscript fonts") do
    download :delegate => 'ghostscript-fonts-std'
    log_exec("Creating #{fonts_dir}") do
      "sudo mkdir -p #{fonts_dir}"
    end             
    install_fonts fonts_dir
    summarize "ghostscript-fonts-std"
  end
  
  # FreeType is usually already installed in /usr/X11/lib. Don't install unless it's missing.
  in_box("FreeType") do 
    freetype_config = ENV['FREETYPE_CONFIG'] || 'freetype-config'
    vers = `#{freetype_config} --version`.chomp
    if vers.empty? then
      download :delegate => 'freetype'
      untar "#{delegate['freetype'].tarball}"
      chdir(delegate["freetype"].version) do
        configure :log => "builds/unix/config.log"
        make
        install
        summarize "FreeType"
      end
    else
      say "FreeType #{vers} already installed. Skipping."
      skipped "FreeType #{vers}"
    end
  end
  
  # WMF
  in_box("WMF") do
    download :delegate => 'libwmf'
    untar "#{delegate['libwmf'].tarball}"
    chdir(delegate["libwmf"].version) do
      configure :options => "--without-expat --with-xml --with-png=/usr/X11"
      make
      install
      summarize "libwmf"
    end
  end
  
  # TIFF is optional
  if want_tiff?
    in_box("TIFF") do
      download :delegate => 'tiff'
      untar "#{delegate['tiff'].tarball}"
      chdir(delegate["tiff"].version) do
        configure
        make
        install
        summarize "libtiff"
      end
    end
  end
  
  # ImageMagick
  in_box("ImageMagick") do
    download :file => "ImageMagick.tar.gz", :dir => PUB_DIR
    untar "ImageMagick.tar.gz"
    im_dir = Dir['ImageMagick-*'][0]
    chdir(im_dir) do
      configure :options => "--disable-static --with-modules\
      --without-perl --without-magick-plus-plus --with-fontconfig\
      --with-quantum-depth=8 --with-gs-font-dir=#{fonts_dir}fonts"
      make
      install   
      summarize "ImageMagick"                      
    end
  end             

  # RMagick
  in_box("RMagick") do
    http_download rmagick_uri
    untar rmagick_tarball
    chdir(rmagick_version) do
      setup "config"
      chdir("ext/RMagick") { log_append "mkmf.log" }   
      setup "setup"
      setup "install", :sudo
      summarize "RMagick"
    end
  end
  
  report
  
end

exit
  
