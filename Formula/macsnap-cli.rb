class MacsnapCli < Formula
  desc "Command-line screenshot utility for macOS"
  homepage "https://github.com/1fc0nfig/macsnap"
  url "https://github.com/1fc0nfig/macsnap/releases/download/v1.0.0/macsnap-cli-v1.0.0.zip"
  sha256 "9bd5271602058cc1d2e9a34f4c03b748f1d2f2abf04a5ae37cd0337d71211279"
  version "1.0.0"
  license "MIT"

  depends_on :macos => :monterey

  def install
    bin.install "macsnap-cli"
  end

  test do
    system "#{bin}/macsnap-cli", "--help"
  end
end
