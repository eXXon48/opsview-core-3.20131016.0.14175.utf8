opsview-core-3.20131016.0.14175.utf8
====================================
- Build
```
# git clone \
https://github.com/ruo91/opsview-core-3.20131016.0.14175.utf8.git
# cd opsview-core-3.20131016.0.14175.utf8
# mkdir ../tools
# echo "#!/usr/bin/perl
$os = "ubuntu16";
print $os, $/;
" > ../tools/build_os
# chmod a+x ../tools/build_os
# make && make install
```
Thanks :)
