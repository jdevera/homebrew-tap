cask "bluetooth-blocklist" do
  version "0.4.1"
  sha256 "ed5bc449a3b5c0680dbe18e46ff2dc908aa79a8344d9845e67d4013465c1967b"

  url "https://github.com/jdevera/bluetooth-blocklist/releases/download/v#{version}/Bluetooth-Blocklist-#{version}-arm64.pkg"
  name "Bluetooth Blocklist"
  desc "Manage per-address incoming Bluetooth Classic blocks"
  homepage "https://github.com/jdevera/bluetooth-blocklist"

  depends_on arch: :arm64
  depends_on macos: :sonoma

  pkg "Bluetooth-Blocklist-#{version}-arm64.pkg"
  binary "/Applications/Bluetooth Blocklist.app/Contents/Helpers/bluetooth-blocklist"

  uninstall script: { executable: "/usr/bin/security",
                      args:       ["authorizationdb", "remove", "local.bluetooth-blocklist.modify"],
                      sudo:       true },
            launchctl: ["local.bluetooth-blocklist.agent", "local.bluetooth-blocklist.service"],
            pkgutil:   "local.bluetooth-blocklist.pkg",
            quit:      "local.bluetooth-blocklist.app",
            delete:    "#{Dir.home}/Library/LaunchAgents/local.bluetooth-blocklist.agent.plist"

  caveats <<~EOS
    This community build is not Apple-notarized. macOS may require first-launch approval.
    Use Check access in the app. If requested, grant Full Disk Access to Bluetooth Blocklist Service.
    Enable the helper in the app after installing or upgrading.
    Remove rules and apply changes before uninstalling if you want devices unblocked.
    Uninstalling the app does not remove saved Bluetooth rules.
  EOS
end
