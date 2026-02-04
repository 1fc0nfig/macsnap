class MacsnapCli < Formula
  desc "Command-line screenshot utility for macOS"
  homepage "https://github.com/1fc0nfig/macsnap"
  url "https://github.com/1fc0nfig/macsnap/releases/download/v1.3.0/macsnap-cli-v1.3.0.zip"
  sha256 "ae4ac1d4573d7aad11ee735f540cb3fb45d2fbbafc5c100a936e8cf6406df53d"
  version "1.3.0"
  license "MIT"

  depends_on :macos => :monterey

  def install
    bin.install "macsnap-cli"
  end

  test do
    system "#{bin}/macsnap-cli", "--help"
  end
end
