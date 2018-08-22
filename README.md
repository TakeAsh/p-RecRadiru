# p-RecRadiru
Record NHK Net Radio らじる★らじる / Radiko

## RecRadiru

### Usage
```
usage: ./RecRadiru.pl <area> <channel> <duration> [<title>] [<outdir>]
area: tokyo | osaka | nagoya | sendai
channel: r1 | r2 | fm
duration: minuites
```

## RecRadiko

### Install
```
# yum install -y epel-release libmp4v2
# rpm --import http://li.nux.ro/download/nux/RPM-GPG-KEY-nux.ro
# rpm -Uvh http://li.nux.ro/download/nux/dextop/el7/x86_64/nux-dextop-release-0-5.el7.nux.noarch.rpm
# yum install -y ffmpeg rtmpdump
# yum groupinstall -y "Development Tools"
# yum install -y libjpeg-devel giflib-devel freetype-devel
# cd /tmp
# wget http://www.swftools.org/swftools-2013-04-09-1007.tar.gz
# tar -zvxf swftools-2013-04-09-1007.tar.gz
# cd swftools-2013-04-09-1007
# ./configure --libdir=/usr/lib64 --bindir=/usr/bin
# make && make install
```

### Usage
```
usage : ./RecRadiko.sh channel_name duration(minuites) [outputdir] [prefix]
```

## Links
- [嗤うプログラマー | Linux でらじる★らじるも録音しちゃう](http://tech.matchy.net/archives/241)
  - [簡易らじるらじる(NHK)録音スクリプト (2015/09 以降版)](https://gist.github.com/matchy2/f03205246e1a12b3b027)
- [riocampos’s gists](https://gist.github.com/riocampos)
  - [らじるらじるをrtmpdumpで録音する（仙台・名古屋・大阪も）](https://gist.github.com/riocampos/5656450)

