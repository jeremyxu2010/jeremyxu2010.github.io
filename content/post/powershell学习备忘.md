---
title: powershell学习备忘
tags:
  - powershell
  - windows
categories:
  - devops
date: 2018-02-03 23:07:00+08:00
---

# 背景

早就听说微软的powershell非常强大，凭借它可以全命令行操控windows服务器了。最近终于要在工作中用到它了，于是花了几个小时将powershell的基础教程看了下，这里将学习过程中的一些要点记录一下。

# 环境准备

欲善其事，先利其器，先准备一个开发环境。

个人的开发电脑是macOS 11.13.3，为了开发powershell脚本，在本机安装了一个windows 7 sp1的虚拟机。

## 升级powershell版本

win7自带的powershell版本较低，这里将windows 7 sp1里自带的powershell升级到5.1版本。 先安装[.NET 4.5](http://www.microsoft.com/en-us/download/details.aspx?id=30653)，然后再安装[Win7AndW2K8R2-KB3191566-x64.zip](https://www.microsoft.com/en-us/download/details.aspx?id=54616)。

## 设置允许运行本机powershell脚本

以管理员的身份运行PowerShell，在powershell窗口里输出以下命令：

```
Set-ExecutionPolicy RemoteSigned -Force
```

## 设置macOS系统远程连到windows系统的powershell

本地还是更喜欢iTerm2的终端，windows里带的powershell终端实在是用不惯，于是设置了下通过ssh连接到windows系统的powershell。

从[https://github.com/PowerShell/Win32-OpenSSH/releases/latest/](https://github.com/PowerShell/Win32-OpenSSH/releases/latest/)下载OpenSSH for windows的64位二进制包，安装到windows的`C:\Program Files\OpenSSH`目录。

以管理员的身份运行PowerShell，在powershell窗口里输出以下命令：

```
cd C:\Program Files\OpenSSH
powershell.exe -ExecutionPolicy Bypass -File install-sshd.ps1 # 安装sshd服务
netsh advfirewall firewall add rule name=sshd dir=in action=allow protocol=TCP  localport=22 # 允许外部访问ssh端口
net start sshd # 启动sshd服务
Set-Service sshd -StartupType Automatic # 设置sshd服务开机自启动
Set-Service ssh-agent -StartupType Automatic # 设置ssh-agent服务开机自启动
New-Item -type Directory HKLM:\SOFTWARE\OpenSSH
New-Item -itemType String HKLM:\SOFTWARE\OpenSSH\DefaultShell -value "C:\Windows\system32\WindowsPowerShell\v1.0\powershell.exe" # 设置ssh登录的默认shell为powershell
```

## 给windows安装一个命令行的编辑器vim

运程操控windows服务器免不了要修改某些配置文件，个人还是比较适应vim，这里在windows里安装好vim。

从[https://vim.sourceforge.io/download.php#pc](https://vim.sourceforge.io/download.php#pc)下载vim的windows安装包[gvim80.exe](ftp://ftp.vim.org/pub/vim/pc/gvim80-586.exe)，在windows里以默认选项安装一下，正常情况下会安装到`C:/Program Files (x86)/Vim`目录下。

在windows里以普通身份运行PowerShell，在powershell窗口里输出以下命令：

```
new-item -path $profile -itemtype file -force
@'
set-alias vim "C:/Program Files (x86)/Vim/vim80/vim.exe"

Function Edit-Profile
{
    vim $profile
}

# To edit Vim settings
Function Edit-Vimrc
{
    vim $HOME\_vimrc
}
'@ > @profile  # 创建并初始化powershell的配置文件

@'
syntax on
colorscheme desert
set backspace=indent,eol,start
'@ > $HOME\_vimrc # 初始化vim的配置文件
```

## 在iTerm2里创建该连接的profile

现在已经可以在iTerm2里通过命令`/usr/local/bin/sshpass -p 123456 ssh jeremy@10.211.55.5`连接到windows的powershell，其中`123456`是windows用户`jeremy`的密码，`10.211.55.5`是windows的密码。为了连接方便，在iTerm2里创建一个新的profile，登录的命令设置为`/usr/local/bin/sshpass -p 123456 ssh jeremy@10.211.55.5`，以后以这个profile创建会话就会直接连接到windows的powershell。

# powershell学习要点

## Powershell基础

### 基本数学计算

基本数学计算比较简单，不单独说了，参见[这里](http://www.pstips.net/powershell-as-a-calculator.html)

### 执行外部命令

可直接执行windows命令行命令，甚至可以直接执行cmd命令。如果一个外部命令必须用引号括起来，为了让powershell执行字符串里的命令，可在字符串前加`&`，这样即可让powershell执行该命令，参见[这里](http://www.pstips.net/powershell-executing-external-commands.html)

### 命令集cmdlets

cmdlets是Powershell的内部命令。

```
Get-Command -Name Get-Content | Get-Member # 察看一个cmdlet的所有属性、方法、ScriptProperty
Get-Command -CommandType Cmdlet 列出所有cmdlets
Get-Command -CommandType Cmdlet *Service* # 列出名称里包含Service的cmdlets
Get-Help Get-Content #获得某个cmdlet的使用帮助
```

详细参见[这里](http://www.pstips.net/powershell-cmdlets.html)

### 别名

cmdlet 的名称由一个动词和一个名词组成，其功能对用户来讲一目了然。但是对于一个经常使用powershell命令的人每天敲那么多命令也很麻烦，于是`别名`就应运而生了。

```
Get-Alias -name ls # 查看某一个别名的定义
Get-Alias # 查看所有别名
dir alias: | where {$_.Definition.Startswith("Remove")} # 查看所有以Remove打头的cmdlet的命令的别名呢
Set-Alias -Name Edit -Value notepad # 创建别名
del alias:Edit # 删除别名
Export-Alias alias.ps1 # 导出别名
Import-Alias -Force alias.ps1 # 导入别名
```

详细参见[这里](http://www.pstips.net/powershell-alias.html)

### 管道和重定向

powershell里支持管道，但要注意不像linux的管道，powershell里管道里输出、输入都是对象，如下：

```
ls | sort -Descending Name | Format-Table Name,Mode
```

powershell支持重定向，`>`为覆盖，`>>`追加，注意可直接将字符串重定向到文件，如下：

```
"Powershell Routing" > test.txt
"Powershell Routing" >> test.txt
```

### 变量

变量可以临时保存数据，因此可以把数据保存在变量中，以便进一步操作，powershell 不需要显示地去声明，可以自动创建变量，只须记住变量的前缀为$。

```
#定义变量
$a=10
$b=4
#计算变量
$result=$a*$b
$msg="保存文本"

#输出变量
$result
$msg

#交换变量的值
$value1=10
$value2=20
$value1,$value2=$value2,$value1

#查看所有变量
ls variable:

#查询以value打头的变量名
ls variable:value*

#验证变量是否存在
Test-Path variable:value1

#删除变量
del variable:value1

#变量写保护
New-Variable num -Value 100 -Force -Option readonly

#给变量添加描述
new-variable name -Value "me" -Description "This is my name"
ls Variable:name | fl *
```

详细参见[这里](http://www.pstips.net/powershell-define-variable.html)

### 内置变量

Powershell 内置变量是指那些一旦打开Powershell就会自动加载的变量。
这些变量一般存放的内容包括

1. **用户信息**：例如用户的根目录$HOME
2. **配置信息**：例如powershell控制台的大小，颜色，背景等。
3. **运行时信息**：例如一个函数由谁调用，一个脚本运行的目录等。

较常用的内置变量如下：

```
$?
包含最后一个操作的执行状态。如果最后一个操作成功，则包含 TRUE，失败则包含 FALSE。

$_
包含管道对象中的当前对象。在对管道中的每个对象或所选对象执行操作的命令中，可以使用此变量。

$Args
包含由未声明参数和/或传递给函数、脚本或脚本块的参数值组成的数组。
在创建函数时可以声明参数，方法是使用 param 关键字或在函数名称后添加以圆括号括起、逗号
分隔的参数列表。

$Error
包含错误对象的数组，这些对象表示最近的一些错误。最近的错误是该数组中的第一个错误对象
($Error[0])。

$False
包含 FALSE。可以使用此变量在命令和脚本中表示 FALSE，而不是使用字符串”false”。如果
该字符串转换为非空字符串或非零整数，则可将该字符串解释为 TRUE。

$ForEach
包含 ForEach-Object 循环的枚举数。可以对 $ForEach 变量的值使用枚举数的属性和方法。
此变量仅在运行 For 循环时存在，循环完成即会删除。

$Home
包含用户的主目录的完整路径。此变量等效于 %homedrive%%homepath% 环境变量。

$Host
包含一个对象，该对象表示 Windows PowerShell 的当前主机应用程序。可以使用此变量在命
令中表示当前主机，或者显示或更改主机的属性，如 $Host.version、$Host.CurrentCulture
或 $host.ui.rawui.setbackgroundcolor(“Red”)。

$Input
一个枚举数，它包含传递给函数的输入。$Input 变量区分大小写，只能用于函数和脚本块。（脚
本块本质上是未命名的函数。）在函数的 Process 块中，$Input 变量包含当前位于管道中的对
象。在 Process 块完成后，$Input 的值为 NULL。如果函数没有 Process 块，则 $Input
的值可用于 End 块，它包含函数的所有输入。

$LastExitCode
包含运行的最后一个基于 Windows 的程序的退出代码。

$Matches
$Matches 变量与 -match 和 -not match 运算符一起使用。
将标量输入提交给 -match 或 -notmatch 运算符时，如果检测到匹配，则会返回一个布尔值，
并使用由所有匹配字符串值组成的哈希表填充 $Matches 自动变量。有关 -match 运算符的详细
信息，请参阅 about_comparison_operators。

$MyInvocation
包含一个对象，该对象具有有关当前命令（如脚本、函数或脚本块）的信息。可以使用该对象中的
信息（如脚本的路径和文件名 ($myinvocation.mycommand.path) 或函数的名称
($myinvocation.mycommand.name)）来标识当前命令。对于查找正在运行的脚本的名称，这非常有用。

$NULL
包含 NULL 或空值。可以在命令和脚本中使用此变量表示 NULL，而不是使用字符串”NULL”。
如果该字符串转换为非空字符串或非零整数，则可将该字符串解释为 TRUE。

$PID
包含承载当前 Windows PowerShell 会话的进程的进程标识符 (PID)。

$Profile
包含当前用户和当前主机应用程序的 Windows PowerShell 配置文件的完整路径。可以在命令
中使用此变量表示配置文件。例如，可以在命令中使用此变量确定是否已创建某个配置文件：
test-path $profile
也可以在命令中使用此变量创建配置文件：
new-item -type file -path $pshome -force

$PsHome
包含 Windows PowerShell 的安装目录的完整路径（通常为
%windir%System32WindowsPowerShellv1.0）。可以在 Windows PowerShell 文件
的路径中使用此变量。例如，下面的命令在概念性帮助主题中搜索”variable”一词：
select-string -pattern variable -path $pshome*.txt

$PSScriptRoot
包含要从中执行脚本模块的目录。
通过此变量，脚本可以使用模块路径来访问其他资源。

$PsVersionTable
包含一个只读哈希表，该哈希表显示有关在当前会话中运行的 Windows PowerShell 版本的详
细信息。
该表包括下列项：
CLRVersion： 公共语言运行时 (CLR) 的版本
BuildVersion： 当前版本的内部版本号
PSVersion： Windows PowerShell 版本号
WSManStackVersion： WS-Management 堆栈的版本号
PSCompatibleVersions： 与当前版本兼容的 Windows PowerShell 版本
SerializationVersion ：序列化方法的版本
PSRemotingProtocolVersion：Windows PowerShell 远程管理协议的版本

$Pwd
包含一个路径对象，该对象表示当前目录的完整路径。

$ShellID
包含当前 shell 的标识符。

$True
包含 TRUE。可以在命令和脚本中使用此变量表示 TRUE。
```

详细参见[这里](http://www.pstips.net/powershell-automatic-variables.html)

### 环境变量

传统的控制台一般没有象Powershell这么高级的变量系统。它们都是依赖于机器本身的环境变量，进行操作 。环境变量对于powershell显得很重要，因为它涵盖了许多操作系统的细节信息。

```
$env:windir # windows目录
$env:ProgramFiles # 默认程序安装目录
$env:COMPUTERNAME # 主机名
$env:OS # 操作系统名称
ls env: # 查找环境变量
$env:TestVar1="This is my environment variable" # 创建新的环境变量
ls env:Test* # 模糊查找环境变量
$env:TestVar1="This is my new environment variable" # 更新环境变量
del env:TestVar1 # 删除环境变量
$env:Path+=";C:\PowerShell\myscript" # 更改Path环境变量
[environment]::SetEnvironmentvariable("Path", ";c:\powershell\myscript", "User") # 修改系统的环境变量
[environment]::GetEnvironmentvariable("Path", "User") # 从系统读取环境变量
```

详细参见[这里](http://www.pstips.net/powershell-environment-variables.html)

### 变量的作用域

Powershell所有的变量都有一个决定变量是否可用的作用域。Powershell支持四个作用域：全局、当前、私有和脚本。有了这些作用域就可以限制变量的可见性了，尤其是在函数和脚本中。

#### 设置单个变量的作用域

**$global**
全局变量，在所有的作用域中有效，如果你在脚本或者函数中设置了全局变量，即使脚本和函数都运行结束，这个变量也任然有效。

**$script**
脚本变量，只会在脚本内部有效，包括脚本中的函数，一旦脚本运行结束，这个变量就会被回收。

**$private**
私有变量，只会在当前作用域有效，不能贯穿到其他作用域。

**$local**
默认变量，可以省略修饰符，在当前作用域有效，其它作用域只对它有只读权限。

详细参见[这里](http://www.pstips.net/powershell-scope-of-variables.html)

### 指定类型定义变量

```
# 解析日期
[DateTime]$date="2012-12-20 12:45:00"
$date

# 解析XML
[ XML ]$xml=(Get-Content .LogoTestConfig.xml)
$xml.LogoTest

# 解析IP地址
[Net.IPAddress]$ip='10.3.129.71'
```

详细参见[这里](http://www.pstips.net/powershell-variable-strongly-typing.html)

### 命令返回数组

当我们把一个外部命令的执行结果保存到一个变量中时，Powershell会把文本按每一行作为元素存为数组。

```
#ipconfig的输出结果是一个数组
$ip=ipconfig
$ip -is [array]
```

真正的Powershell命令返回的数组元素可不止一个字符串，它是一个内容丰富的对象。

```
#ls的输出结果仍然是一个数组
$result=ls
$result -is [array]

#数组里的元素是一个对象
$result[0].gettype().fullname
$result[0] | fl *
```

### 数组

```
#使用逗号创建数组
$nums=2,0,1,2
#创建连续数字的数组
$nums=1..5
#创建空数组
$a=@()
#判断是否是一个数组
$a -is [array]
#得到数组里元素的个数
$a.Count
#访问数组
$books="元素1","元素2","元素3"
$books[0]
$books[($books.Count-1)]
#从数组中选择多个元素
$books[0,2]
#将数组逆序输出
$books[($books.Count)..0]
#给数组添加元素
$books+="元素4"
#删除第3个元素
$books=$books[0..1]+$books[3]
#复制数组
$booksNew=$books.Clone()
#创建强类型数组
[int[]] $nums=@()
```

### 哈希表

```
#创建哈希表
$stu=@{ Name = "小明";Age="12";sex="男" }
#访问哈希键值
$stu["Name"]
#得到哈希表里元素的个数
$stu.Count
#得到所有哈希键
$stu.Keys
#得到所有哈希值
$stu.Values
#插入新的键值
$stu.Name="令狐冲"
#更新哈希表值
$stu.Name="赵强"
#删除哈希表值
$stu.Remove("Name")
#在哈希表中存储数组
$stu=@{ Name = "小明";Age="12";sex="男";Books="三国演义","围城","哈姆雷特" }
```

#### 使用哈希表格式化输出

```
#控制输出哪些列
Dir | Format-Table FullName,Mode

#自定义输出列的格式
$column1 = @{expression="Name"; width=30;label="filename"; alignment="left"}
$column2 = @{expression="LastWriteTime"; width=40;label="last modification"; alignment="right"}
ls | Format-Table $column1, $column2
```

### 管道处理

常用的对管道结果进一步处理的命令有：

```
Compare-Object: 比较两组对象。
ConvertTo-Html: 将 Microsoft .NET Framework 对象转换为可在 Web 浏览器中显示的 HTML。
Export-Clixml: 创建对象的基于 XML 的表示形式并将其存储在文件中。
Export-Csv: 将 Microsoft .NET Framework 对象转换为一系列以逗号分隔的、长度可变的 (CSV) 字符串，并将这些字符串保存到一个 CSV 文件中。
ForEach-Object: 针对每一组输入对象执行操作。
Format-List: 将输出的格式设置为属性列表，其中每个属性均各占一行显示。
Format-Table: 将输出的格式设置为表。
Format-Wide: 将对象的格式设置为只能显示每个对象的一个属性的宽表。
Get-Unique: 从排序列表返回唯一项目。
Group-Object: 指定的属性包含相同值的组对象。
Import-Clixml: 导入 CLIXML 文件，并在 Windows PowerShell 中创建相应的对象。
Measure-Object: 计算对象的数字属性以及字符串对象（如文本文件）中的字符数、单词数和行数。
more: 对结果分屏显示。
Out-File: 将输出发送到文件。
Out-Null: 删除输出，不将其发送到控制台。
Out-Printer: 将输出发送到打印机。
Out-String: 将对象作为一列字符串发送到主机。
Select-Object: 选择一个对象或一组对象的指定属性。它还可以从对象的数组中选择唯一对象，也可以从对象数组的开头或末尾选择指定个数的对象。
Sort-Object: 按属性值对象进行排序。
Tee-Object: 将命令输出保存在文件或变量中，并将其显示在控制台中。
Where-Object: 创建控制哪些对象沿着命令管道传递的筛选器。
```

其中:

Format的管道处理用法参见[这里](http://www.pstips.net/powershell-converting-objects-into-text.html)

排序和分组的管道处理用法参见[这里](http://www.pstips.net/powershell-sort-and-group-pipeline-results.html)

`Select-Object`、`Where-Object`、`ForEach-Object`用法参见[这里](http://www.pstips.net/powershell-filtering-pipeline-results.html)

导出的管道处理用法参见[这里](http://www.pstips.net/powershell%E5%AF%BC%E5%87%BA%E7%AE%A1%E9%81%93%E7%BB%93%E6%9E%9C.html)

## 对象、控制流、函数

### 对象=属性+方法

Powershell中的对象和现实生活很相似。例如要在现实生活中描述一把小刀。我们可能会分两方面描述它。
**属性**：一把小刀拥有一些特殊的属性，比如它的颜色、制造商、大小、刀片数。这个对象是红色的，重55克，有3个刀片，ABC公司生产的。因此属性描述了一个对象是什么。
**方法**：可以使用这个对象做什么，比如切东西、当螺丝钉用、开啤酒盖。一个对象能干什么就属于这个对象的方法。

```
#创建对象
$pocketknife=New-Object object
#增加属性
Add-Member -InputObject $pocketknife -Name Color -Value "Red"
-MemberType NoteProperty
$pocketknife | Add-Member NoteProperty Blades 3
#增加方法
Add-Member -memberType ScriptMethod -In $pocketknife -name cut -Value { "I'm whittling now" }
$pocketknife | Add-Member ScriptMethod corkscrew { "Pop! Cheers!" }
```

### 对象的属性

```
#直接使用点访问对象的属性
$Host.Version
#查看Version的具体类型
$Host.Version.GetType().FullName
#查看对象所有属性
$Host | Get-Member -memberType property
```

### 对象的方法

```
#查看对象所有的方法
$Host | Get-Member -MemberType Method
#调用方法
$Host.GetType()
$Host.UI.WriteDebugLine("Hello 2012 !")
#列出重载方法
$method=$Host.UI | Get-Member WriteLine
$method.Definition.Replace("),",")`n")
```

### 静态方法

```
#查看某类型的静态方法
[System.DateTime] | Get-Member -static -memberType Method
#调用静态方法
[System.DateTime]::Parse("2012-10-13 23:42:55")
#根据IP反查域名
[system.Net.Dns]::GetHostByAddress('8.8.8.8').HostName
#查询某类型下的所有枚举
[System.Enum]::GetNames([System.ConsoleColor])
```

### 条件操作符

#### 比较运算符

**-eq** ：等于
**-ne** ：不等于
**-gt** ：大于
**-ge** ：大于等于
**-lt** ：小于
**-le** ：小于等于
**-contains** ：包含
**-notcontains** :不包含

#### 求反

求反运算符为-not 但是像高级语言一样`!`也支持求反

#### 布尔运算

**-and** ：和
**-or** ：或
**-xor** ：异或
**-not** ：逆

```
PS C:Powershell> (3,4,5 ) -contains 2
False
PS C:Powershell> (3,4,5 ) -contains 5
True
PS C:Powershell> (3,4,5 ) -notcontains 6
True
PS C:Powershell> 2 -eq 10
False
PS C:Powershell> "A" -eq "a"
True
PS C:Powershell> "A" -ieq "a"
True
PS C:Powershell> "A" -ceq "a"
False
PS C:Powershell> 1gb -lt 1gb+1
True
PS C:Powershell> 1gb -lt 1gb-1
False
PS C:Powershell> $a= 2 -eq 3
PS C:Powershell> $a
False
PS C:Powershell> -not $a
True
PS C:Powershell> !($a)
True
PS C:Powershell> $true -and $true
True
PS C:Powershell> $true -and $false
False
PS C:Powershell> $true -or $true
True
PS C:Powershell> $true -or $false
True
PS C:Powershell> $true -xor $false
True
PS C:Powershell> $true -xor $true
False
PS C:Powershell>  -not  $true
False
#过滤数组中的元素
PS C:Powershell> 1,2,3,4,3,2,1 -eq 3
3
3
PS C:Powershell> 1,2,3,4,3,2,1 -ne 3
1
2
4
2
1
#验证一个数组是否存在特定元素
PS C:Powershell> 1,9,4,5 -contains 9
True
PS C:Powershell> 1,9,4,5 -contains 10
False
PS C:Powershell> 1,9,4,5 -notcontains 10
True
```

### IF-ELSEIF-ELSE 条件

Where-Object 进行条件判断很方便，如果在判断后执行很多代码可以使用IF-ELSEIF-ELSE语句。语句模板：

```
If（条件满足）{
如果条件满足就执行代码
}
Else
{
如果条件不满足
}
```

### ForEach-Object 循环

```
#杀掉名字里包含rar的进程
Get-Process | Where-Object {$_.ProcessName -like '*rar*'} | ForEach-Object {$_.Kill()}
```

### Foreach 循环

```
$array=7..10
foreach ($n in $array)
{
    $n*$n
}
```

### Do While 循环

```
do { $n=Read-Host } while( $n -ne 0)
#单独使用While
$n=5
while($n -gt 0)
{
    $n
    $n=$n-1
}
#终止当前循环
$n=1
while($n -lt 6)
{
    if($n -eq 4)
    {
        $n=$n+1
        continue
 
    }
    else
    {
        $n
    }
    $n=$n+1
}
#跳出循环
$n=1
while($n -lt 6)
{
    if($n -eq 4)
    {
        break
    }
    $n
    $n++
}
```

### For 循环

```
$sum=0
for($i=1;$i -le 100;$i++)
{
    $sum+=$i
}
$sum
```

### 函数

```
#定义函数模板
Function FuncName （args[]）
{
      code;
}
#删除函数
del Function:myPing
#万能参数
function sayHello
{
    if($args.Count -eq 0)
    {
        "No argument!"
    }
    else
    {
        $args | foreach {"Hello,$($_)"}
    }
}

#设置参数名称
function StringContact($str1,$str2)
{
    return $str1+$str2
}
 

StringContact -str1 word -str2 press

#给参数定义默认值
function stringContact($str1="moss",$str2="fly")
{
    return $str1+$str2
}

stringContact

# 列出所有函数
dir function: | ft -AutoSize

#函数过滤器管道
Filter MarkEXE
{
    # 记录当前控制台的背景色
    $oldcolor = $host.ui.rawui.ForegroundColor
    # 当前的管道元素保存在 $_ 变量中
    # 如果后缀名为 ".exe",
    # 改变背景色为红色:
    If ($_.name.toLower().endsWith(".exe"))
    {
        $host.ui.Rawui.ForegroundColor = "red"
    }
    Else
    {
        # 否则使用之前的背景色
        $host.ui.Rawui.ForegroundColor = $oldcolor
    }
    # 输出当前元素
    $_
    # 最后恢复控制台颜色:
    $host.ui.Rawui.ForegroundColor = $oldcolor
}

Function MarkEXE
{
    begin
    {
        # 记录控制台的背景色
        $oldcolor = $host.ui.rawui.ForegroundColor
    }
    process
    {
        # 当前管道的元素 $_
        # 如果后缀名为 ".exe",
        # 改变背景色为红色:
        If ($_.name.toLower().endsWith(".exe"))
        {
            $host.ui.Rawui.ForegroundColor = "red"
        }
        Else
        {
            # 否则, 使用正常的背景色:
            $host.ui.Rawui.ForegroundColor = $oldcolor
         }
        # 输出当前的背景色
        $_
      }
    end
    {
        # 最后,恢复控制台的背景色:
        $host.ui.Rawui.ForegroundColor = $oldcolor
     }
}
```

## 其它技巧

### 阻止变量解析

```
PS E:> @'
>> Get-Date
>> $Env:CommonProgramFiles
>> #Script End
>> "files count"
>> (ls).Count
>> #Script Really End
>>
>> '@ > myscript.ps1
>>
```

### 给脚本传递参数

```
@'
For($i=0;$i -lt $args.Count; $i++)
{
    Write-Host "parameter $i : $($args[$i])"
}
'@ >  MyScript.ps1

PS E:> .\MyScript.ps1 www moss fly com
parameter 0 : www
parameter 1 : moss
parameter 2 : fly
parameter 3 : com
```

### 在脚本中使用参数名

```
@'
param($Directory,$FileName)
 
"Directory= $Directory"
"FileName=$FileName"
'@ >  MyScript.ps1

PS E:> .\MyScript.ps1 -Directory $env:windir -FileName config.xml
Directory= C:\windows
FileName=config.xml
```

### 管道脚本

```
@'
begin
{
    Write-Host "管道脚本环境初始化"
}
process
{
    $ele=$_
    if($_.Extension -ne "")
    {
        switch($_.Extension.tolower())
        {
            ".ps1" {"脚本文件："+ $ele.name}
            ".txt" {"文本文件："+ $ele.Name}
            ".gz"  {"压缩文件："+ $ele.Name}
        }
    }
}
end
{
    Write-Host "管道脚本环境恢复"
}
'@ > pipeline.ps1

ls | .\pipeline.ps1
```

### 识别和处理异常

```
# 错误不抛出，脚本也会继续执行
$ErrorActionPreference='SilentlyContinue'
Remove-Item "文件不存在" | Out-Null
If (!$?)
{
"发生异常，异常信息为$($error[0])";
break
}
"删除文件成功!"
```

### 操作字符串

详细参见[这里](http://www.pstips.net/string-operators.html)

### 操作正则表达式

详细参见[这里](http://www.pstips.net/regex-describing-patterns.html)

### 操作文件

详细参见[这里](http://www.pstips.net/the-file-system.html)

### 操作注册表

详细参见[这里](http://www.pstips.net/the-registry.html)

### 操作ini文件

详细参见[这里](https://github.com/lipkau/PsIni)

### 导入模块

详细参见[这里](https://guhuajun.wordpress.com/2009/06/14/windows-powershell-v2-%E4%BB%8B%E7%BB%8D-8-%E6%A8%A1%E5%9D%97/)

### 操作IIS

Win2008 *,角色-->添加角色--->功能工具下面的'IIS管理脚本和工具'
Win7 在卸载程序中，点击'打开或关闭Windows功能'--->'Internet信息服务'--->'Web管理工具'--->'IIS管理脚本和工具'

主要用到的方法有

```
#创建站点
$site = New-Item IIS:\Sites\$siteName -bindings $bindings -physicalPath $physicalPath -ErrorAction Stop
...
#创建应用程序池
$apool = New-Item IIS:\AppPools\$appPool
Set-ItemProperty IIS:\AppPools\$appPool managedRuntimeVersion $runtimeVersion
#1:Classic or 0:Integrated
Set-ItemProperty IIS:\AppPools\$appPool managedPipelineMode $pipelineMode
...
#关联程序池
Set-ItemProperty IIS:\Sites\$siteName -name applicationPool -value $apool
...    
#创建应用程序
$app = New-Item IIS:\Sites\$siteName\$appName  -physicalPath $appPhysPath -type Application
$site = Get-Item "IIS:\Sites\$siteName"
Set-ItemProperty IIS:\Sites\$siteName\$appName -name applicationPool -value $site.applicationPool
...
#获取站点
$site = Get-Item "IIS:\Sites\$siteName" -ErrorAction Stop
...
#获取应用程序
$app = Get-Item "IIS:\Sites\$siteName\$appName" -ErrorAction Stop
...
```

详细参见[这里](https://technet.microsoft.com/en-us/library/hh867899(v=wps.630).aspx)


# 参考

1. https://social.technet.microsoft.com/wiki/contents/articles/21016.how-to-install-windows-powershell-4-0.aspx
2. https://github.com/PowerShell/Win32-OpenSSH/wiki/Install-Win32-OpenSSH
3. http://www.wowotech.net/soft/vim_in_powershell.html
4. http://www.pstips.net/powershell-online-tutorials/
