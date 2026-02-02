cask "macsnap" do
  version "1.1.0"
  sha256 "625f063b1a1834808490530bd6d6c13a403b5bfbb10ca615080a534b00692d93"

  url "https://github.com/1fc0nfig/macsnap/releases/download/v#{version}/MacSnap-v#{version}.zip"
  name "MacSnap"
  desc "Lightweight screenshot utility that saves to clipboard and filesystem"
  homepage "https://github.com/1fc0nfig/macsnap"

  depends_on macos: ">= :monterey"

  app "MacSnap.app"

  zap trash: [
    "~/.config/macsnap",
  ]
end
