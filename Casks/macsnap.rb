cask "macsnap" do
  version "1.3.2"
  sha256 "a5540209c2a3fe078960b94e81bf8bd09e10abd90f2e684274b1df92ba8320c4"

  url "https://github.com/1fc0nfig/macsnap/releases/download/v#{version}/MacSnap-#{version}.dmg"
  name "MacSnap"
  desc "Lightweight screenshot utility that saves to clipboard and filesystem"
  homepage "https://github.com/1fc0nfig/macsnap"

  depends_on macos: ">= :monterey"

  app "MacSnap.app"
  binary "#{appdir}/MacSnap.app/Contents/MacOS/macsnap-cli", target: "macsnap-cli"

  zap trash: [
    "~/.config/macsnap",
  ]
end
