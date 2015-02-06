require "formula"

class Abcm2ps < Formula
  homepage "http://moinejf.free.fr"
  url "http://moinejf.free.fr/abcm2ps-7.8.13.tar.gz"
  sha1 "09bbcde58e358c11a5a28de05d48be3a7eb94a4e"

  bottle do
    sha1 "1381e1f180e685182193a4392fc664cc16e5bc87" => :yosemite
    sha1 "ccb022e97dac73bae23be04cc8bdf99ce10e09d8" => :mavericks
    sha1 "d6b852cb4761a91f16ff9de9b189e0faf238de90" => :mountain_lion
  end

  devel do
    url "http://moinejf.free.fr/abcm2ps-8.5.2.tar.gz"
    sha1 "71362859696c379b371814698d5272964e1aa2bd"
  end

  depends_on "pkg-config" => :build
  depends_on "pango" => :optional

  def install
    system "./configure", "--prefix=#{prefix}"
    system "make", "install"
  end

  test do
    (testpath/"voices.abc").write <<-EOF.undent
      X:7
      T:Qui Tolis (Trio)
      C:Andre Raison
      M:3/4
      L:1/4
      Q:1/4=92
      %%staves {(Pos1 Pos2) Trompette}
      K:F
      %
      V:Pos1
      %%MIDI program 78
      "Positif"x3 |x3|c'>ba|Pga/g/f|:g2a |ba2 |g2c- |c2P=B  |c>de  |fga |
      V:Pos2
      %%MIDI program 78
              Mf>ed|cd/c/B|PA2d |ef/e/d |:e2f |ef2 |c>BA |GA/G/F |E>FG |ABc- |
      V:Trompette
      %%MIDI program 56
      "Trompette"z3|z3 |z3 |z3 |:Mc>BA|PGA/G/F|PE>EF|PEF/E/D|C>CPB,|A,G,F,-|
    EOF

    system "#{bin}/abcm2ps", (testpath/"voices")
  end
end
