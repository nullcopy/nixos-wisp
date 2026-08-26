{
  config,
  lib,
  pkgs,
  ...
}:

{
  imports = [
    ./ollama.nix
  ];

  ## ----- identity --------------------------------------------------------------
  networking.hostName = "wisp";

  ## ----- nixos-core toggles ------------------------------------------------
  core.desktop.enable = true; # niri + greetd + audio + Wayland plumbing
  core.tailscale.enable = true; # tailnet policy in /etc/tailscale/connect.env
  core.nymvpn.enable = true;

  # FIDO2 LUKS unlock (EFI: /dev/nvme0n1p1, LUKS: /dev/nvme0n1p2). The
  # mapper name predates the install script's "cryptroot" default, and the
  # generated hardware config doesn't declare the device, so both are set
  # explicitly here. Manage enrolled tokens/passphrases with `sudo fde-keys`.
  core.fde = {
    fido2.enable = true;
    name = "nixos-enc";
    device = "/dev/nvme0n1p2";
  };

  ## ----- boot ----------------------------------------------------------------
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.kernelModules = [ "uvcvideo" ]; # USB webcam

  ## ----- system --------------------------------------------------------------
  # HP publishes G1a BIOS updates through LVFS. Check/apply with:
  #   fwupdmgr refresh && fwupdmgr get-updates && fwupdmgr update
  services.fwupd.enable = true;

  # CoolerControl is a hwmon dashboard/controller that can help if the
  # kernel/firmware exposes fan control
  programs.coolercontrol.enable = true;

  # `sensors` for better temperature reading
  environment.systemPackages = [ pkgs.lm_sensors ];

  # Keystone ForgeBox (pid.codes VID). Without this, /dev/bus/usb nodes are
  # root-only and forgebox-cli can't open the device; uaccess has logind
  # grant an ACL to the physically logged-in user. Re-plug after a rebuild.
  #
  # Must ship as a rules file sorting before systemd's 73-seat-late.rules
  # (which is what acts on the uaccess tag), so extraRules (=> 99-local.rules)
  # can't be used here.
  services.udev.packages = [
    (pkgs.writeTextFile {
      name = "forgebox-udev-rules";
      destination = "/lib/udev/rules.d/70-forgebox.rules";
      text = ''
        SUBSYSTEM=="usb", ATTR{idVendor}=="1209", ATTR{idProduct}=="3001", MODE="0660", TAG+="uaccess"
      '';
    })
  ];

  ## ----- users ---------------------------------------------------------------
  # Accounts only — nullcopy's home environment comes from their dotfiles
  # repo via standalone home-manager.
  users.users.nullcopy = {
    isNormalUser = true;
    shell = pkgs.zsh;
    extraGroups = [
      "wheel"
      "networkmanager"
      "audio"
      "video"
    ];
  };

  ## ----- state version -------------------------------------------------------
  # The first NixOS version installed on this machine. Never bump it on an
  # existing install — see `man configuration.nix`.
  system.stateVersion = "25.11";
}
