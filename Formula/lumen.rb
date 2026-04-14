class Lumen < Formula
  desc "macOS log reviewer with color rendering and large file support"
  homepage "https://github.com/emersonding/lumen-log-viewer"
  url "https://github.com/emersonding/lumen-log-viewer/releases/download/v2.0.0/lumen-2.0.0-arm64.tar.gz"
  sha256 "REPLACE_WITH_ACTUAL_SHA256"
  license "MIT"
  version "2.0.0"

  depends_on :macos
  depends_on macos: :sonoma
  depends_on arch: :arm64

  def install
    bin.install "lumen"
  end

  def caveats
    <<~EOS
      Run the GUI log viewer from the terminal:
        lumen

      Or open a log file directly:
        lumen /path/to/file.log
    EOS
  end

  test do
    assert_predicate bin/"lumen", :exist?
  end
end
