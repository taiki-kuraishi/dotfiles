# Linux (Home Manager) 固有の設定。home-common.nix から OS 依存の分岐を移設した。
{ lib, pkgs, ... }:
{
  # gcc / fuse-overlayfs は Linux のみ。
  # gcc.cc.lib は GNU OpenMP ランタイム (libgomp.so.1, Debian の libgomp1 相当) を
  # home-manager-path の lib/ に置くため。LD_LIBRARY_PATH は設定しない。
  home.packages = lib.mkAfter (
    with pkgs;
    [
      gcc
      fuse-overlayfs
      gcc.cc.lib
    ]
  );
}
