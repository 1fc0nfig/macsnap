cask "macsnap" do
  version "1.3.3"
  sha256 "03b24565948d28948162f5a6f8082a850890c7b2a27bdb4e52f62ff7e147b056"

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
