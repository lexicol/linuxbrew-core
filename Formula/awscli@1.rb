class AwscliAT1 < Formula
  include Language::Python::Virtualenv

  desc "Official Amazon AWS command-line interface"
  homepage "https://aws.amazon.com/cli/"
  # awscli should only be updated every 10 releases on multiples of 10
  url "https://github.com/aws/aws-cli/archive/1.19.10.tar.gz"
  sha256 "c6fa8b16635d91271589668d0730c7e6d4cbd0a3c24ef0b99b0ce3d8121fe215"
  license "Apache-2.0"

  livecheck do
    url :stable
    regex(/^v?(1(?:\.\d+)+)$/i)
  end

  bottle do
    sha256 cellar: :any_skip_relocation, arm64_big_sur: "a362d5d5456d0be8c061c7ac5c8e4e1b785fee803bb7794911ad1a4cc2df9359"
    sha256 cellar: :any_skip_relocation, big_sur:       "fb3fc54903b2c6d75b31d31a64a70a90a79e60aeb8a81aeceaf1df2742f4691e"
    sha256 cellar: :any_skip_relocation, catalina:      "7c8b44ed3fe685a5cedcc0382027b2f0be48d83be2b09088d099613a7d46833d"
    sha256 cellar: :any_skip_relocation, mojave:        "7970614752ccb771440fc9daa48c70633badd81847c00a4a00cb3622f7c1a2dd"
    sha256 cellar: :any_skip_relocation, x86_64_linux:  "5d870400c2941047406eced2a9601305f1aa3115ecc82aee477c451e7b9b5044"
  end

  keg_only :versioned_formula

  # Some AWS APIs require TLS1.2, which system Python doesn't have before High
  # Sierra
  depends_on "python@3.9"

  uses_from_macos "groff"

  def install
    venv = virtualenv_create(libexec, "python3")
    system libexec/"bin/pip", "install", "-v", "--no-binary", ":all:",
                              "--ignore-installed", buildpath
    system libexec/"bin/pip", "uninstall", "-y", "awscli"
    venv.pip_install_and_link buildpath
    pkgshare.install "awscli/examples"

    rm Dir["#{bin}/{aws.cmd,aws_bash_completer,aws_zsh_completer.sh}"]
    bash_completion.install "bin/aws_bash_completer"
    zsh_completion.install "bin/aws_zsh_completer.sh"
    (zsh_completion/"_aws").write <<~EOS
      #compdef aws
      _aws () {
        local e
        e=$(dirname ${funcsourcetrace[1]%:*})/aws_zsh_completer.sh
        if [[ -f $e ]]; then source $e; fi
      }
    EOS
  end

  def caveats
    <<~EOS
      The "examples" directory has been installed to:
        #{HOMEBREW_PREFIX}/share/awscli/examples
    EOS
  end

  test do
    assert_match "topics", shell_output("#{bin}/aws help")
  end
end
