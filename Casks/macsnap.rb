cask "macsnap" do
  version "1.0.0"
  sha256 "d9fd0f7cb637cabc89aa136b8c9b348f566c9d061b1eb3650d5adeb76363c6d5"

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
