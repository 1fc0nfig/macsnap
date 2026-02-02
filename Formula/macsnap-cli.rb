class MacsnapCli < Formula
  desc "Command-line screenshot utility for macOS"
  homepage "https://github.com/1fc0nfig/macsnap"
  url "https://github.com/1fc0nfig/macsnap/releases/download/v1.1.0/macsnap-cli-v1.1.0.zip"
  sha256 "50f3631d1b2ce10b850d44b69f69d98a283b8278d3493840a75e43c0b7e47214"
  version "1.1.0"
  license "MIT"

  depends_on :macos => :monterey

  def install
    bin.install "macsnap-cli"
  end

  test do
    system "#{bin}/macsnap-cli", "--help"
  end
end
