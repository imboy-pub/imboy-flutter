

## m1 silicon macos 安装 cocoapods

https://wiki.ducafecat.tech/blog/flutter-tips/3-m1-macos-install-cocoapods.html#_4-%E5%AE%89%E8%A3%85-cocoapods

```
zsh 
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

arch -arm64 brew upgrade

arch -arm64 brew reinstall ruby

rm -rf ~/.cocoapods
sudo gem install cocoapods
``` 