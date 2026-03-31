class MacsnapCli < Formula
  desc "Command-line screenshot utility for macOS"
  homepage "https://github.com/1fc0nfig/macsnap"
  url "https://github.com/1fc0nfig/macsnap/releases/download/v1.3.3/macsnap-cli-v1.3.3.zip"
  sha256 "9f92ac043db3c7f43e6d875ae5b9158b4326ce54d53a8d2c13e34ea09c78b140"
  version "1.3.3"
  license "MIT"

  depends_on :macos => :monterey

  def install
    bin.install "macsnap-cli"
  end

  test do
    system "#{bin}/macsnap-cli", "--help"
  end
end
