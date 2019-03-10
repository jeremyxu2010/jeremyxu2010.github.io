---
title: CentOS6下rpm打包实战
tags:
  - centos
  - rpm
  - rpmbuild
categories:
  - linux
date: 2018-02-06 20:07:00+08:00
---
最近的工作需要将以前编译安装的软件包打包成rpm包，这里将打包过程记录一下以备忘。

# 准备rpm打包环境

我这里用的操作系统是CentOS6.7，redhat系的其它发行版应该也类似。

## 安装rpm-build

```bash
sudo yum install -y gcc make rpm-build redhat-rpm-config vim lrzsz
```

## 创建必须的文件夹和文件

```bash
mkdir -p ~/rpmbuild/{BUILD,RPMS,SOURCES,SPECS,SRPMS}
echo '%_topdir %(echo $HOME)/rpmbuild' > ~/.rpmmacros
```

# 制作spec文件

## 找spec模板文件

一般找一个类似的rpm源码包，将其安装，然后参照它写自己软件包的spec文件。

```bash
mkdir ~/rpms
wget -O ~/rpms/python-2.6.6-64.el6.src.rpm http://vault.centos.org/6.7/os/Source/SPackages/python-2.6.6-64.el6.src.rpm
rpm -ivh ~/rpms/python-2.6.6-64.el6.src.rpm
vim ~/rpmbuild/SPECS/python.spec # 参照这个文件来写自己软件包的spec文件
```

## 写自己软件包的spec文件

spec文件中各个选项的意义参照[这里](http://www.dahouduan.com/2015/06/15/linux-centos-make-rpm/)

```bash
cd ~/rpmbuild
cat ./SPECS/python27-tstack.spec

%debug_package %{nil}
%define install_dir /usr/local/python27

Name:		python27-tstack
Version:	2.7.10
Release:	1%{?dist}
Summary:	python27 modified by tstack
URL: 		http://www.python.org/
Group:		Development/Languages
License:	Python
Provides:   python-abi = 2.7
Provides:   python(abi) = 2.7
Source0:	Python-2.7.10.tgz
BuildRequires:  readline-devel, openssl-devel, gmp-devel, pcre-devel, mysql-devel, libffi-devel
Requires:	readline, openssl, gmp, pcre, mysql, libffi
Autoreq: 	0

%description
Python is an interpreted, interactive, object-oriented programming
language often compared to Tcl, Perl, Scheme or Java. Python includes
modules, classes, exceptions, very high level dynamic data types and
dynamic typing. Python supports interfaces to many system calls and
libraries, as well as to various windowing systems (X11, Motif, Tk,
Mac and MFC).

Programmers can write new built-in modules for Python in C or C++.
Python can be used as an extension language for applications that need
a programmable interface.

Note that documentation for Python is provided in the python-docs
package.

%prep
%setup -q -n Python-%{version}


%build
./configure --prefix=%{install_dir} --with-cxx-main=/usr/bin/g++
make %{?_smp_mflags}

%install
rm -rf %{buildroot}
make install DESTDIR=%{buildroot}

%clean 
rm -rf %{buildroot}

%files
%defattr (-,root,root)
%{install_dir}/bin/
%{install_dir}/include/
%{install_dir}/lib/
%{install_dir}/share/
%doc

%changelog
```

# 制作rpm包

## 上传必要的source文件

```bash
cp ${some_where}/Python-2.7.10.tgz ~/rpmbuild/SOURCES/
```

## 开始制作

```Bash
cd ~/rpmbuild
rpmbuild -bb --target x86_64 SPECS/python27-tstack.spec &> rpmbuild.log # 这时可以打开另一个终端观察下rpmbuild.log
```

一切顺序的话，最终会在`~/rpmbuild/RPMS/x86_64/`目录下找到编译好的rpm包。

# 技巧总结

* 不打debug的rpm包

  在spec文件中加入`%debug_package %{nil}`即可

* 禁止自动分析源码添加不应该加入的依赖
  在spec文件中加入`Autoreq: 0`即可

* sepc文件中一些宏的用法
  在spec文件中经常出现一些宏，比如`%setup`、`%patch`，这两个宏的选项较多，使用时要特别注意，参见[这里](http://ftp.rpm.org/max-rpm/s1-rpm-inside-macros.html)

* 安装卸载rpm包前后的动作
  可以通过`%pre`, `%post`, `%preun`, `%postun`指定rpm包在安装卸载前后的动作，比如在安装前用脚本做一些准备、在安装后用脚本做一些初始化动作、在卸载前用脚本做一些准备、在卸载后用脚本做一些清理动作

* rpmbuild命令的选项
  rpmbuild命令有不少选项，参见[这里](http://ftp.rpm.org/max-rpm/rpmbuild.8.html)，个人用得比较多的有：
  1. `-bp` 只解压源码及应用补丁
  2. `-bc` 只进行编译
  3. `-bi` 只进行安装到%{buildroot}
  4. `-bb` 只生成二进制rpm包
  5. `-bs` 只生成源码rpm包
  6. `-ba` 生成二进制rpm包和源码rpm包
  7. `--target` 指定生成rpm包的平台，默认会生成`i686`和`x86_64`的rpm包，但一般我只需要`x86_64`的rpm包

# 参考

1. http://vault.centos.org/6.7/os/Source/SPackages/
2. http://tkdchen.github.io/blog/2013/05/19/rpm-spec-for-python-gist.html
3. http://www.dahouduan.com/2015/06/15/linux-centos-make-rpm/
4. http://www.centoscn.com/CentOS/Intermediate/2014/0419/2826.html
5. http://wiki.centos.org/HowTos/SetupRpmBuildEnvironment
6. http://ftp.rpm.org/max-rpm/rpmbuild.8.html
7. http://ftp.rpm.org/max-rpm/s1-rpm-inside-macros.html
