class MacsnapCli < Formula
  desc "Command-line screenshot utility for macOS"
  homepage "https://github.com/1fc0nfig/macsnap"
  url "https://github.com/1fc0nfig/macsnap/releases/download/v1.3.2/macsnap-cli-v1.3.2.zip"
  sha256 "e71b54372bd2cef60d67e5adf3f140c7292a73b1e62da027f74c5398eac655bc"
  version "1.3.2"
  license "MIT"

  depends_on :macos => :monterey

  def install
    bin.install "macsnap-cli"
  end

  test do
    system "#{bin}/macsnap-cli", "--help"
  end
end
