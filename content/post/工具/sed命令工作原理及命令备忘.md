---
title: sed命令工作原理及命令备忘
tags:
  - linux
  - sed
categories:
  - 工具
date: 2016-04-12 23:10:00+08:00
---
sed是一个非交互式的流编辑器（stream editor）。所谓非交互式，是指使用sed只能在命令行下输入编辑命令来编辑文本，然后在屏幕上查看输出；而所谓流编辑器，是指sed每次只从文件（或输入）读入一行，然后对该行进行指定的处理，并将结果输出到屏幕（除非取消了屏幕输出又没有显式地使用打印命令），接着读入下一行。整个文件像流水一样被逐行处理然后逐行输出。

工作中经常会使用sed命令对文件进行各种操作，之前一直对它的工作原理不是很了解，只不过在网上抄一些命令完成操作，有时遇到了问题，就问一问身边的“脚本小王子”，基本上都可以搞定。今天下班了决定对sed命令深入学习一下。

# 工作原理

## 核心逻辑

sed一次处理一行内容。处理时，把当前处理的行存储在临时缓冲区中，称为“模式空间”（pattern space），接着用sed命令处理缓冲区(pattern space)中的内容，处理完成后，把缓冲区(pattern space)的内容送往屏幕。接着清空缓冲区(pattern space)，处理下一行，这样不断重复，直到文件末尾。

sed里有两个空间：pattern space与hold space。

pattern space（模式空间）相当于车间sed把流内容在这里处理；

hold space（保留空间）相当于仓库，加工的半成品在这里临时储存（当然加工完的成品也在这里存储）。

sed处理每一行的逻辑：

	1. 先读入一行，去掉尾部换行符，存入pattern space，执行编辑命令。

	2. 处理完毕，除非加了-n参数，把现在的pattern space打印出来，在后边打印曾去掉的换行符。

    3. 把pattern space内容给hold space，把pattern space置空。

    4. 接着读下一行，处理下一行。

## 命令组织形式

sed最重要的命令组织形式可以概括为*** [address[,address]][!]{cmd}  ***

### address

address可以是一个数字，也可以是一个模式，你可以通过逗号要分隔两个address 表示两个address的区间

man手册上对address的理解比较全面

```
Addresses
       Sed commands can be given with no addresses, in which case the command will be executed for all input lines; with one address, in which case the command will only be executed for input  lines  which  match
       that  address;  or  with  two addresses, in which case the command will be executed for all input lines which match the inclusive range of lines starting from the first address and continuing to the second
       address.  Three things to note about address ranges: the syntax is addr1,addr2 (i.e., the addresses are separated by a comma); the line which addr1 matched will always be accepted, even if addr2 selects an
       earlier line; and if addr2 is a regexp, it will not be tested against the line that addr1 matched.

       After the address (or address-range), and before the command, a !  may be inserted, which specifies that the command shall only be executed if the address (or address-range) does not match.

       The following address types are supported:

       number Match only the specified line number (which increments cumulatively across files, unless the -s option is specified on the command line).

       first~step
              Match  every step'th line starting with line first.  For example, ``sed -n 1~2p'' will print all the odd-numbered lines in the input stream, and the address 2~5 will match every fifth line, starting
              with the second.  first can be zero; in this case, sed operates as if it were equal to step.  (This is an extension.)

       $      Match the last line.

       /regexp/
              Match lines matching the regular expression regexp.

       \cregexpc
              Match lines matching the regular expression regexp.  The c may be any character.

       GNU sed also supports some special 2-address forms:

       0,addr2
              Start out in "matched first address" state, until addr2 is found.  This is similar to 1,addr2, except that if addr2 matches the very first line of input the 0,addr2 form will be at the  end  of  its
              range, whereas the 1,addr2 form will still be at the beginning of its range.  This works only when addr2 is a regular expression.

       addr1,+N
              Will match addr1 and the N lines following addr1.

       addr1,~N
              Will match addr1 and the lines following addr1 until the next line whose input line number is a multiple of N.
```

### !

表示匹配成功后是否执行命令

### cmd

要执行的命令。

下面摘录一下sed man文档中的常用命令（其中删除了较复杂的与label有关的命令）

##### 不可接受address的命令


```
       }      The closing bracket of a { } block.
```

##### 可接受零个或一个address的命令

```
       =      Print the current line number.

       a \

       text   Append text, which has each embedded newline preceded by a backslash.

       i \

       text   Insert text, which has each embedded newline preceded by a backslash.

       r filename
              Append text read from filename.

       R filename
              Append a line read from filename.  Each invocation of the command reads a line from the file.  This is a GNU extension.

```

##### 可接受address范围的命令

```
       {      Begin a block of commands (end with a }).

       c \

       text   Replace the selected lines with text, which has each embedded newline preceded by a backslash.

       d      Delete pattern space.  Start next cycle.

       D      If pattern space contains no newline, start a normal new cycle as if the d command was issued.  Otherwise, delete text in the pattern space up to the first newline, and restart cycle with the resul-
              tant pattern space, without reading a new line of input.

       h H    Copy/append pattern space to hold space.

       g G    Copy/append hold space to pattern space.

       n N    Read/append the next line of input into the pattern space.

       p      Print the current pattern space.

       P      Print up to the first embedded newline of the current pattern space.

       s/regexp/replacement/
              Attempt to match regexp against the pattern space.  If successful, replace that portion matched with replacement.  The replacement may contain the special character & to refer to that portion of the
              pattern space which matched, and the special escapes \1 through \9 to refer to the corresponding matching sub-expressions in the regexp.

       w filename
              Write the current pattern space to filename.

       W filename
              Write the first line of the current pattern space to filename.  This is a GNU extension.

       x      Exchange the contents of the hold and pattern spaces.

       y/source/dest/
              Transliterate the characters in the pattern space which appear in source to the corresponding character in dest.
```

# 常用命令解析

#### `sed -n '1p' test.txt`

打印第一行，这条命令其实应该理解为`sed -n '1 p' test.txt`, 其中`1`是一个address，这条命令实际是说按照address的说明，仅第一行被作为要操作的address范围，那么在这个范围里每一行就执行p命令，同时`-n`说明不要把处理的模式空间内容打印出来，于是最后就打印了第一行。

#### `sed -i 's/abcd/efgh/g' test.txt`

将文件中所有的abcd替换成efgh，这条命令没有address范围，那么address范围默认就是整个文件范围，这里对整个文件范围里每一行执行`s/abcd/efgh/g`命令，即将每一行里的abcd替换成efgh, 同时因为有/g选项，一行里如果出现多个abcd, 就每一个都会替换。-i参数说明将直接修改文件，而不仅仅将结果打印到标准输出里(注意MAC OSX下要达成相同效果要写`-i ''`)。

#### `sed '{/This/{/fish/d}}' test.txt`

删除文件中即有`This`也有`fish`的行，这条命令没有address范围，那么address范围默认就是整个文件范围，这里对整个文件范围里每一行执行`{/This/{/fish/d}}`命令，这是个嵌套命令，意思是先匹配`/This/`，匹配成功的行再尝试匹配`/fish/`，如果又匹配成功，则删除该行。

#### `sed '{/This/d; /fish/d}' test.txt`

删除文件中有`This`或`fish`的行，这条命令与上面那条很像，但逻辑很不一样。这条命令没有address范围，那么address范围默认就是整个文件范围，这里对整个文件范围里每一行执行`{/This/d; /fish/d}`命令，这也是个嵌套命令，意思是针对当前行，先匹配`/This/`，如果匹配成功，则删除该行，否则再尝试匹配`/fish/`，如果匹配成功，则删除该行。

#### `sed -i '/abcd/,/efgh/ s/xxx/yyyy/g' test.txt`

这条命令就很好理解了，它有address范围，在文件里先匹配`/abcd/`，以匹配的行为范围的起点，再在文件里匹配`/efgh/`，以匹配的行为范围的终点，在这个范围里执行`s/xxx/yyyy/g`命令，这个就不用再解释了。


# 小结

还有一些关于hold space的高级用法，我平时没怎么用到，不过只要头脑里有pattern space与hold space的概念，按sed核心的执行逻辑推演一下，还是可以看懂那些高级用法的，至于要熟练运用的话就得靠多练了。附上[sed常用命令及中文解释](http://sed.sourceforge.net/sed1line_zh-CN.html)

# PS

MAC OSX里记得需要使用`brew install gnu-sed`安装GNU版的sed，然后使用gsed， 自带的BSD版本sed功能实在弱了点。
