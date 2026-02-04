cask "macsnap" do
  version "1.3.0"
  sha256 "1d5b154da5337fa3322cc0df8f015b681f6421818e63a44775f0e592f594256c"

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
