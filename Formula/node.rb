class Node < Formula
  desc "Platform built on V8 to build network applications"
  homepage "https://nodejs.org/"
  url "https://nodejs.org/dist/v8.2.1/node-v8.2.1.tar.xz"
  sha256 "02c46d8914540eea73d0ad33bf9f371a28aa0dc8c5d740948491fef044ad8c8b"
  head "https://github.com/nodejs/node.git"

  bottle do
    sha256 "a5dcb0592a3147b3b896fe7c6dd681e544183cbf09eb128dbd75ebc71cf94aee" => :sierra
    sha256 "b9abfa3b30002be1b02b7ab8adbea45c1de47afb58843b8aa5bb85fee327d2cc" => :el_capitan
    sha256 "e28c6c82fb88a394714bf5c9324ea76fe11f4e115c596fa443c6181dd43ac3fc" => :yosemite
  end

  option "with-debug", "Build with debugger hooks"
  option "with-openssl", "Build against Homebrew's OpenSSL instead of the bundled OpenSSL"
  option "without-npm", "npm will not be installed"
  option "without-completion", "npm bash completion will not be installed"
  option "without-icu4c", "Build with small-icu (English only) instead of system-icu (all locales)"

  deprecated_option "enable-debug" => "with-debug"

  depends_on :python => :build if MacOS.version <= :snow_leopard
  depends_on "pkg-config" => :build
  depends_on "icu4c" => :recommended
  depends_on "openssl" => :optional

  # Per upstream - "Need g++ 4.8 or clang++ 3.4".
  fails_with :clang if MacOS.version <= :snow_leopard
  fails_with :gcc_4_0
  fails_with :gcc
  ("4.3".."4.7").each do |n|
    fails_with :gcc => n
  end

  # We track major/minor from upstream Node releases.
  # We will accept *important* npm patch releases when necessary.
  resource "npm" do
    url "https://registry.npmjs.org/npm/-/npm-5.3.0.tgz"
    sha256 "dd96ece7cbd6186a51ca0a5ab7e1de0113333429603ec2ccb6259e0bef2e03eb"
  end

  def install
    # Never install the bundled "npm", always prefer our
    # installation from tarball for better packaging control.
    args = %W[--prefix=#{prefix} --without-npm]
    args << "--debug" if build.with? "debug"
    args << "--with-intl=system-icu" if build.with? "icu4c"
    args << "--shared-openssl" if build.with? "openssl"
    args << "--tag=head" if build.head?

    system "./configure", *args
    system "make", "install"

    if build.with? "npm"
      # Allow npm to find Node before installation has completed.
      ENV.prepend_path "PATH", bin

      bootstrap = buildpath/"npm_bootstrap"
      bootstrap.install resource("npm")
      system "node", bootstrap/"bin/npm-cli.js", "install", "-ddd", "--global",
             "--prefix=#{libexec}", resource("npm").cached_download

      # The `package.json` stores integrity information about the above passed
      # in `cached_download` npm resource, which breaks `npm -g outdated npm`.
      # This copies back over the vanilla `package.json` to fix this issue.
      cp bootstrap/"package.json", libexec/"lib/node_modules/npm"
      # These symlinks are never used & they've caused issues in the past.
      rm_rf libexec/"share"

      if build.with? "completion"
        bash_completion.install \
          bootstrap/"lib/utils/completion.sh" => "npm"
      end
    end
  end

  def post_install
    return if build.without? "npm"

    node_modules = HOMEBREW_PREFIX/"lib/node_modules"
    node_modules.mkpath
    # Kill npm but preserve all other modules across node updates/upgrades.
    rm_rf node_modules/"npm"

    cp_r libexec/"lib/node_modules/npm", node_modules
    # This symlink doesn't hop into homebrew_prefix/bin automatically so
    # we make our own. This is a small consequence of our
    # bottle-npm-and-retain-a-private-copy-in-libexec setup
    # All other installs **do** symlink to homebrew_prefix/bin correctly.
    # We ln rather than cp this because doing so mimics npm's normal install.
    ln_sf node_modules/"npm/bin/npm-cli.js", HOMEBREW_PREFIX/"bin/npm"
    ln_sf node_modules/"npm/bin/npx-cli.js", HOMEBREW_PREFIX/"bin/npx"

    # Let's do the manpage dance. It's just a jump to the left.
    # And then a step to the right, with your hand on rm_f.
    %w[man1 man5 man7].each do |man|
      # Dirs must exist first: https://github.com/Homebrew/legacy-homebrew/issues/35969
      mkdir_p HOMEBREW_PREFIX/"share/man/#{man}"
      rm_f Dir[HOMEBREW_PREFIX/"share/man/#{man}/{npm.,npm-,npmrc.,package.json.,npx.}*"]
      cp Dir[libexec/"lib/node_modules/npm/man/#{man}/{npm,package.json,npx}*"], HOMEBREW_PREFIX/"share/man/#{man}"
    end

    npm_root = node_modules/"npm"
    npmrc = npm_root/"npmrc"
    npmrc.atomic_write("prefix = #{HOMEBREW_PREFIX}\n")
  end

  def caveats
    if build.without? "npm"
      <<-EOS.undent
        Homebrew has NOT installed npm. If you later install it, you should supplement
        your NODE_PATH with the npm module folder:
          #{HOMEBREW_PREFIX}/lib/node_modules
      EOS
    end
  end

  test do
    path = testpath/"test.js"
    path.write "console.log('hello');"

    output = shell_output("#{bin}/node #{path}").strip
    assert_equal "hello", output
    output = shell_output("#{bin}/node -e 'console.log(new Intl.NumberFormat(\"en-EN\").format(1234.56))'").strip
    assert_equal "1,234.56", output
    if build.with? "icu4c"
      output = shell_output("#{bin}/node -e 'console.log(new Intl.NumberFormat(\"de-DE\").format(1234.56))'").strip
      assert_equal "1.234,56", output
    end

    if build.with? "npm"
      # make sure npm can find node
      ENV.prepend_path "PATH", opt_bin
      ENV.delete "NVM_NODEJS_ORG_MIRROR"
      assert_equal which("node"), opt_bin/"node"
      assert (HOMEBREW_PREFIX/"bin/npm").exist?, "npm must exist"
      assert (HOMEBREW_PREFIX/"bin/npm").executable?, "npm must be executable"
      npm_args = ["-ddd", "--cache=#{HOMEBREW_CACHE}/npm_cache", "--build-from-source"]
      system "#{HOMEBREW_PREFIX}/bin/npm", *npm_args, "install", "npm@latest"
      system "#{HOMEBREW_PREFIX}/bin/npm", *npm_args, "install", "bignum" unless head?
      assert (HOMEBREW_PREFIX/"bin/npx").exist?, "npx must exist"
      assert (HOMEBREW_PREFIX/"bin/npx").executable?, "npx must be executable"
      assert_match "< hello >", shell_output("#{HOMEBREW_PREFIX}/bin/npx --cache=#{HOMEBREW_CACHE}/npm_cache cowsay hello")
    end
  end
end
