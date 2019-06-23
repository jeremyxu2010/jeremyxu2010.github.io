---
title: golang语言常见范式
date: 2016-10-02 18:47:00+08:00
tags:
  - golang
categories:
  - golang开发
---

最近花了一个星期的时间看完了《Go语言程序设计》这本书，这本书不愧是大师的作品，写得很好。看过之后对golang语言的理解更深刻了。下面将书中提到的一些关键语言范式记录下来以备忘。

## 常见范式

* 普通for循环

```
var s, sep string
for i := 0; i < len(os.Args); i++ {
    s += sep + os.Args[i]
    sep = " "
}
fmt.Println(s)
```

* for配合range

```
var s, sep string
for _, arg := range os.Args[:] {
    s += sep + arg
    sep = " "
}
fmt.Println(s)
```

* 逐行处理输入

```
input := bufio.NewScanner(os.Stdin)
for input.Scan() {
    fmt.Println(input.Text())
}
```

* 普通方法调用错误处理

```
f, err := os.Open(filename)
//延迟关闭文件
defer f.Close()
if err != nil {
    fmt.Fprintf(os.Stderr, "dup2: %v\n", err)
    return nil, err
}
// 正常地使用f
```

* 元组赋值

```
x, y = y, x
a[i], a[j] = a[j], a[i]
```

* 定义命名类型

```
type Celsius float64    // 摄氏温度
type Fahrenheit float64 // 华氏温度
```

* 定义常量

```
const (
    AbsoluteZeroC Celsius = -273.15 // 绝对零度
    FreezingC     Celsius = 0       // 结冰点温度
    BoilingC      Celsius = 100     // 沸水温度
)
```

* 定义命名类型的方法

```
func (c Celsius) String() string {
    return fmt.Sprintf("%g°C", c) 
}
```

* 定义包的初始化函数

```
func init() { 
  // 进行必要的初始化动作
}
```

* iota常量生成器

```
const (
    _ = 1 << (10 * iota)
    KiB // 1024
    MiB // 1048576
    GiB // 1073741824
    TiB // 1099511627776  (exceeds 1 << 32)
    PiB // 1125899906842624
    EiB // 1152921504606846976
    ZiB // 1180591620717411303424    (exceeds 1 << 64)
    YiB // 1208925819614629174706176
)
```

* 遍历数组

```
var a [3]int
for i, v := range a {
    fmt.Printf("%d %d\n", i, v)
}
```

* 定义长度根据初始值来确定的数组

```
q := [...]int{1, 2, 3}
fmt.Printf("%T\n", q) // "[3]int"
```

* 创建slice

```
var a []int // 值为nil的slice类型
a = make([]int)
```
或
```
a := make([]int)
```
或
```
a := []int{}
```
或
```
a := []int{1, 2}
```

* 数组转换为slice

```
q := [...]int{1, 2, 3}
a := q[:]
```

* slice的append操作

```
var runes []rune
for _, r := range "Hello, 世界" {
    runes = append(runes, r)
}
fmt.Printf("%q\n", runes) // "['H' 'e' 'l' 'l' 'o' ',' ' ' '世' '界']"
```

* 创建map

```
var m map[string]int //值为nil的map类型
m = make(map[string]int)
```
或
```
m := make(map[string]int)
```
或
```
m := map[string]int{}
```
或
```
m := map[string]int{
  "jerry": 1
  "tom": 2,
}
```

* 对map按序遍历

```
m := map[string]int{
  "jerry": 1
  "tom": 2,
}
var keys := make([]string, 0, len(m)
for key := range m {
    keys = append(keys, key)
}
sort.Strings(keys)
for _, key := range keys {
    fmt.Printf("%s\t%d\n", key, m[key])
}
```

* 用map模拟set

```
seen := make(map[string]struct{})
input := bufio.NewScanner(os.Stdin)
for input.Scan() {
    line := input.Text()
    if !seen[line] {
        seen[line] = struct{}{}
    }
}
var lines := make([]string, 0, len(seen)
for line := range seen {
    fmt.Println(line)
}
```

* 定义结构体

```
type Employee struct {
    ID        int
    Name      string
    Address   string
    DoB       time.Time
    Position  string
    Salary    int
    ManagerID int
}
```

* 创建结构变量

```
var dilbert Employee //结构体变量的成员均初始化为零值
```
或
```
dilbert := Employee{
    ID        1
    Name      "jerry"
    Address   "blablabla"
    DoB       time.Date(2016, time.April, 11, 0, 0, 0, 0, time.Local)
    Position  "PD"
    Salary    13500
    ManagerID 1
}
```

* 创建函数值

```
var f func(int)int //值为nil的函数值类型
func square(n int) int { return n * n }
f = square
```
或
```
func square(n int) int { return n * n }
f := square
```

* 使用匿名函数

```
strings.Map(func(r rune) rune { 
    return r + 1 
}, "HAL-9000")
```

* 递归使用匿名函数(闭包)

```
var order []string
seen := make(map[string]bool)
var visitAll func(items []string)
visitAll = func(items []string) {
    for _, item := range items {
        if !seen[item] {
            seen[item] = true
            visitAll(m[item])
            order = append(order, item)
        }
    }
}
var keys []string
for key := range m {
    keys = append(keys, key)
}
sort.Strings(keys)
visitAll(keys)
```

* 避免匿名函数使用循环变量快照

```
var rmdirs []func()
for _, d := range tempDirs() {
    dir := d // NOTE: necessary!
    os.MkdirAll(dir, 0755) // creates parent directories too
    rmdirs = append(rmdirs, func() {
        os.RemoveAll(dir)
    })
}
// ...do some work…
for _, rmdir := range rmdirs {
    rmdir() // clean up
}
```
或
```
var rmdirs []func()
for _, d := range tempDirs() {
    os.MkdirAll(d, 0755) // creates parent directories too
    rmdirs = append(rmdirs, func(d *os.File){
        return func(){
            os.RemoveAll(d)
        }
    }(d))
}
// ...do some work…
for _, rmdir := range rmdirs {
    rmdir() // clean up
}
```

* 函数使用可变参数

```
func sum(vals...int) int {
    total := 0
    for _, val := range vals {
        total += val
    }
    return total
}
```

* defer配合使用互斥锁

```
var mu sync.Mutex
var m = make(map[string]int)
func lookup(key string) int {
    mu.Lock()
    defer mu.Unlock()
    return m[key]
}
```

* defer跟踪进入函数与退出函数

```
func bigSlowOperation() {
    defer trace("bigSlowOperation")() // don't forget the
    extra parentheses
    // ...lots of work…
    time.Sleep(10 * time.Second) // simulate slow
    operation by sleeping
}
func trace(msg string) func() {
    start := time.Now()
    log.Printf("enter %s", msg)
    return func() { 
        log.Printf("exit %s (%s)", msg,time.Since(start)) 
    }
}
```

* 主动panic异常

```
func MustCompile(expr string) *Regexp {
    re, err := Compile(expr)
    if err != nil {
        panic(err)
    }
    return re
}
```

* 处理自定义panic异常

```
// soleTitle returns the text of the first non-empty title element
// in doc, and an error if there was not exactly one.
func soleTitle(doc *html.Node) (title string, err error) {
    type bailout struct{}
    defer func() {
        switch p := recover(); p {
        case nil:       // no panic
        case bailout{}: // "expected" panic
            err = fmt.Errorf("multiple title elements")
        default:
            panic(p) // unexpected panic; carry on panicking
        }
    }()
    // Bail out of recursion if we find more than one nonempty title.
    forEachNode(doc, func(n *html.Node) {
        if n.Type == html.ElementNode && n.Data == "title" &&
            n.FirstChild != nil {
            if title != "" {
                panic(bailout{}) // multiple titleelements
            }
            title = n.FirstChild.Data
        }
    }, nil)
    if title == "" {
        return "", fmt.Errorf("no title element")
    }
    return title, nil
}
```

* 定义结构体的方法

```
type Point struct{ X, Y float64 }
func (p Point) Distance(q Point) float64 {
    return math.Hypot(q.X-p.X, q.Y-p.Y)
}
func (p *Point) ScaleBy(factor float64) {
    p.X *= factor
    p.Y *= factor
}
```

* 使用方法值

```
p := Point{1, 2}
distanceFromP := p.Distance        // method value
var origin Point                   // {0, 0}
fmt.Println(distanceFromP(origin)) // "2.23606797749979", sqrt(5)
scaleP := p.ScaleBy // method value
scaleP(2)           // p becomes (2, 4)
```

* 使用方法表达式

```
type Point struct{ X, Y float64 }
func (p Point) Add(q Point) Point { return Point{p.X + q.X, p.Y + q.Y} }
var op func(p, q Point) Point
op = Point.Add
var p Point
var offset Point{3.0, 4.0}
q := op(p, offset)
```

* 定义接口类型

```
// Writer is the interface that wraps the basic Write method.
type Writer interface {
    // Write writes len(p) bytes from p to the underlying data stream.
    // It returns the number of bytes written from p (0 <= n <= len(p))
    // and any error encountered that caused the write to stop early.
    // Write must return a non-nil error if it returns n < len(p).
    // Write must not modify the slice data, even temporarily.
    //
    // Implementations must not retain p.
    Write(p []byte) (n int, err error)
}
```

* 具体类型转换为接口类型

```
var w io.Writer
w = os.Stdout           // OK: *os.File has Write method
w = new(bytes.Buffer)   // OK: *bytes.Buffer has Write method
w = time.Second         // compile error: time.Duration lacks Write method
```

* 接口类型转换为具体类型

```
var w io.Writer
w = os.Stdout
f := w.(*os.File)      // success: f == os.Stdout
c := w.(*bytes.Buffer) // panic: interface holds *os.File, not *bytes.Buffer
```
或
```
var w io.Writer
w = os.Stdout
if f, ok := w.(*os.File); ok {
    // ...use f...
}
```

* 通过类型断言询问行为

```
// writeString writes s to w.
// If w has a WriteString method, it is invoked instead of w.Write.
func writeString(w io.Writer, s string) (n int, err error) {
    type stringWriter interface {
        WriteString(string) (n int, err error)
    }
    if sw, ok := w.(stringWriter); ok {
        return sw.WriteString(s) // avoid a copy
    }
    return w.Write([]byte(s)) // allocate temporary copy
}
```

* 运用类型开关

```
func sqlQuote(x interface{}) string {
    switch x := x.(type) {
    case nil:
        return "NULL"
    case int, uint:
        return fmt.Sprintf("%d", x) // x has type interface{} here.
    case bool:
        if x {
            return "TRUE"
        }
        return "FALSE"
    case string:
        return sqlQuoteString(x) // (not shown)
    default:
        panic(fmt.Sprintf("unexpected type %T: %v", x, x))
    }
}
```

* 等待其它goroutine

```
done := make(chan struct{})
go func() {
    // do something
    done <- struct{}{} // signal the main goroutine
}()
// do something
<-done // wait for background goroutine to finish
```

* 串联Channels

```
naturals := make(chan int)
squares := make(chan int)

// Counter
go func() {
    for x := 0; x < 100; x++ {
        naturals <- x
    }
    close(naturals)
}()

// Squarer
go func() {
    for x := range naturals {
        squares <- x * x
    }
    close(squares)
}()
// Printer (in main goroutine)
for x := range squares {
    fmt.Println(x)
}
```

* 单方向Channel

```
func counter(out chan<- int) {
	for x := 0; x < 100; x++ {
		out <- x
	}
	close(out)
}

func squarer(out chan<- int, in <-chan int) {
	for v := range in {
		out <- v * v
	}
	close(out)
}

func printer(in <-chan int) {
	for v := range in {
		fmt.Println(v)
	}
}

func main() {
	naturals := make(chan int)
	squares := make(chan int)

	go counter(naturals)
	go squarer(squares, naturals)
	printer(squares)
}
```

* 使用带缓存的Channel

```
func mirroredQuery() string {
    responses := make(chan string, 3)
    go func() { responses <- request("asia.gopl.io") }()
    go func() { responses <- request("europe.gopl.io") }()
    go func() { responses <- request("americas.gopl.io") }()
    return <-responses // return the quickest response
}
```

* 等待多个goroutines结束

```
// makeThumbnails6 makes thumbnails for each file received from the channel.
// It returns the number of bytes occupied by the files it creates.
func makeThumbnails6(filenames <-chan string) int64 {
    sizes := make(chan int64)
    var wg sync.WaitGroup // number of working goroutines
    for f := range filenames {
        wg.Add(1)
        // worker
        go func(f string) {
            defer wg.Done()
            thumb, err := thumbnail.ImageFile(f)
            if err != nil {
                log.Println(err)
                return
            }
            info, _ := os.Stat(thumb) // OK to ignore error
            sizes <- info.Size()
        }(f)
    }

    // closer
    go func() {
        wg.Wait()
        close(sizes)
    }()

    var total int64
    for size := range sizes {
        total += size
    }
    return total
}
```

* 中断某个goroutine

```
abort := make(chan struct{})
go func() {
	os.Stdin.Read(make([]byte, 1)) // read a single byte
	abort <- struct{}{}
}()

//!+
fmt.Println("Commencing countdown.  Press return to abort.")
tick := time.Tick(1 * time.Second)
for countdown := 10; countdown > 0; countdown-- {
	fmt.Println(countdown)
	select {
	case <-tick:
		// Do nothing.
	case <-abort:
		fmt.Println("Launch aborted!")
		return
	}
}
```

* Channel实现信号量

```
// sema is a counting semaphore for limiting concurrency in dirents.
var sema = make(chan struct{}, 20)

// dirents returns the entries of directory dir.
func dirents(dir string) []os.FileInfo {
    sema <- struct{}{}        // acquire token
    defer func() { <-sema }() // release token
    entries, err := ioutil.ReadDir(dir)
    if err != nil {
        fmt.Fprintf(os.Stderr, "du1: %v\n", err)
        return nil
    }
    return entries
}
```

* 中断多个goroutines

```
var done = make(chan struct{})

func cancelled() bool {
    select {
    case <-done:
        return true
    default:
        return false
    }
}

// Cancel traversal when input is detected.
go func() {
    os.Stdin.Read(make([]byte, 1)) // read a single byte
    close(done) //close掉的Channel，其它goroutines如试图从该Channel接收，则可立即接收到
}()

var sema = make(chan struct{}, 20)

func dirents(dir string) []os.FileInfo {
    select {
    case sema <- struct{}{}: // acquire token
    case <-done:
        return nil // cancelled
    }
    defer func() { <-sema }() // release token
    // ...read directory...
}
```

* 使用互斥锁

```
var (
    mu      sync.Mutex // guards balance
    balance int
)

func Deposit(amount int) {
    mu.Lock()
    defer mu.Unlock()
    balance = balance + amount
}

func Balance() int {
    mu.Lock()
    defer mu.Unlock()
    b := balance
    return b
}
```

* 使用读写锁

```
var (
    mu      sync.RWMutex // guards balance
    balance int
)

func Deposit(amount int) {
    mu.Lock()
    defer mu.Unlock()
    balance = balance + amount
}

func Balance() int {
    mu.RLock()
    defer mu.RUnlock()
    return balance
}
```

* 懒加载数据

```
var loadIconsOnce sync.Once
var icons map[string]image.Image
// Concurrency-safe.
func Icon(name string) image.Image {
    loadIconsOnce.Do(loadIcons)
    return icons[name]
}
```

* 表格驱动的测试

```
func TestIsPalindrome(t *testing.T) {
    var tests = []struct {
        input string
        want  bool
    }{
        {"", true},
        {"a", true},
        {"aa", true},
        {"ab", false},
        {"kayak", true},
        {"detartrated", true},
        {"A man, a plan, a canal: Panama", true},
        {"Evil I did dwell; lewd did I live.", true},
        {"Able was I ere I saw Elba", true},
        {"été", true},
        {"Et se resservir, ivresse reste.", true},
        {"palindrome", false}, // non-palindrome
        {"desserts", false},   // semi-palindrome
    }
    for _, test := range tests {
        if got := IsPalindrome(test.input); got != test.want {
            t.Errorf("IsPalindrome(%q) = %v", test.input, got)
        }
    }
}
```

* 使用命令行参数

```
var n = flag.Bool("n", false, "omit trailing newline")
var sep = flag.String("s", " ", "separator")

func main() {
	flag.Parse()
	fmt.Print(strings.Join(flag.Args(), *sep))
	if !*n {
		fmt.Println()
	}
}
```

## 其它

另外在看这本书的过程中也对一些其它概念有了进一步认识。

* Unicode与UTF8的关系

> 在很久以前，世界还是比较简单的，起码计算机世界就只有一个ASCII字符集：美国信息交换标准代码。ASCII，更准确地说是美国的ASCII，使用7bit来表示128个字符：包含英文字母的大小写、数字、各种标点符号和设置控制符。对于早期的计算机程序来说，这些就足够了，但是这也导致了世界上很多其他地区的用户无法直接使用自己的符号系统。随着互联网的发展，混合多种语言的数据变得很常见（译注：比如本身的英文原文或中文翻译都包含了ASCII、中文、日文等多种语言字符）。如何有效处理这些包含了各种语言的丰富多样的文本数据呢？

> 答案就是使用Unicode（ http://unicode.org ），它收集了这个世界上所有的符号系统，包括重音符号和其它变音符号，制表符和回车符，还有很多神秘的符号，每个符号都分配一个唯一的Unicode码点，Unicode码点对应Go语言中的rune整数类型（译注：rune是int32等价类型）。

> 在第八版本的Unicode标准收集了超过120,000个字符，涵盖超过100多种语言。这些在计算机程序和数据中是如何体现的呢？通用的表示一个Unicode码点的数据类型是int32，也就是Go语言中rune对应的类型；它的同义词rune符文正是这个意思。

> 我们可以将一个符文序列表示为一个int32序列。这种编码方式叫UTF-32或UCS-4，每个Unicode码点都使用同样的大小32bit来表示。这种方式比较简单统一，但是它会浪费很多存储空间，因为大数据计算机可读的文本是ASCII字符，本来每个ASCII字符只需要8bit或1字节就能表示。而且即使是常用的字符也远少于65,536个，也就是说用16bit编码方式就能表达常用字符。但是，还有其它更好的编码方法吗？

> UTF8是一个将Unicode码点编码为字节序列的变长编码。UTF8编码由Go语言之父Ken Thompson和Rob Pike共同发明的，现在已经是Unicode的标准。UTF8编码使用1到4个字节来表示每个Unicode码点，ASCII部分字符只使用1个字节，常用字符部分使用2或3个字节表示。每个符号编码后第一个字节的高端bit位用于表示总共有多少编码个字节。如果第一个字节的高端bit为0，则表示对应7bit的ASCII字符，ASCII字符每个字符依然是一个字节，和传统的ASCII编码兼容。如果第一个字节的高端bit是110，则说明需要2个字节；后续的每个高端bit都以10开头。更大的Unicode码点也是采用类似的策略处理。

> 0xxxxxxx                             runes 0-127    (ASCII)
> 110xxxxx 10xxxxxx                    128-2047       (values <128 unused)
> 1110xxxx 10xxxxxx 10xxxxxx           2048-65535     (values <2048 unused)
> 11110xxx 10xxxxxx 10xxxxxx 10xxxxxx  65536-0x10ffff (other values unused)

> 变长的编码无法直接通过索引来访问第n个字符，但是UTF8编码获得了很多额外的优点。首先UTF8编码比较紧凑，完全兼容ASCII码，并且可以自动同步：它可以通过向前回朔最多2个字节就能确定当前字符编码的开始字节的位置。它也是一个前缀编码，所以当从左向右解码时不会有任何歧义也并不需要向前查看（译注：像GBK之类的编码，如果不知道起点位置则可能会出现歧义）。没有任何字符的编码是其它字符编码的子串，或是其它编码序列的字串，因此搜索一个字符时只要搜索它的字节编码序列即可，不用担心前后的上下文会对搜索结果产生干扰。同时UTF8编码的顺序和Unicode码点的顺序一致，因此可以直接排序UTF8编码序列。同时因为没有嵌入的NUL(0)字节，可以很好地兼容那些使用NUL作为字符串结尾的编程语言。

总结来说，Unicode用一个int32序列表示了每个符文(rune)。而UTF8则将Unicode码点编码为字节序列，按照UTF8编码的规则，它编码出的长度是不固定的，从1个Byte至4个Byte。

* Goroutines和线程的区别

> 每一个OS线程都有一个固定大小的内存块(一般会是2MB)来做栈，这个栈会用来存储当前正在被调用或挂起(指在调用其它函数时)的函数的内部变量。这个固定大小的栈同时很大又很小。因为2MB的栈对于一个小小的goroutine来说是很大的内存浪费，比如对于我们用到的，一个只是用来WaitGroup之后关闭channel的goroutine来说。而对于go程序来说，同时创建成百上千个gorutine是非常普遍的，如果每一个goroutine都需要这么大的栈的话，那这么多的goroutine就不太可能了。除去大小的问题之外，固定大小的栈对于更复杂或者更深层次的递归函数调用来说显然是不够的。修改固定的大小可以提升空间的利用率允许创建更多的线程，并且可以允许更深的递归调用，不过这两者是没法同时兼备的。相反，一个goroutine会以一个很小的栈开始其生命周期，一般只需要2KB。一个goroutine的栈，和操作系统线程一样，会保存其活跃或挂起的函数调用的本地变量，但是和OS线程不太一样的是一个goroutine的栈大小并不是固定的；栈的大小会根据需要动态地伸缩。而goroutine的栈的最大值有1GB，比传统的固定大小的线程栈要大得多，尽管一般情况下，大多goroutine都不需要这么大的栈。

> OS线程会被操作系统内核调度。每几毫秒，一个硬件计时器会中断处理器，这会调用一个叫作scheduler的内核函数。这个函数会挂起当前执行的线程并保存内存中它的寄存器内容，检查线程列表并决定下一次哪个线程可以被运行，并从内存中恢复该线程的寄存器信息，然后恢复执行该线程的现场并开始执行线程。因为操作系统线程是被内核所调度，所以从一个线程向另一个“移动”需要完整的上下文切换，也就是说，保存一个用户线程的状态到内存，恢复另一个线程的到寄存器，然后更新调度器的数据结构。这几步操作很慢，因为其局部性很差需要几次内存访问，并且会增加运行的cpu周期。Go的运行时包含了其自己的调度器，这个调度器使用了一些技术手段，比如m:n调度，因为其会在n个操作系统线程上多工(调度)m个goroutine。Go调度器的工作和内核的调度是相似的，但是这个调度器只关注单独的Go程序中的goroutine。和操作系统的线程调度不同的是，Go调度器并不是用一个硬件定时器而是被Go语言"建筑"本身进行调度的。因为因为这种调度方式不需要进入内核的上下文，所以重新调度一个goroutine比调度一个线程代价要低得多。

> 在大多数支持多线程的操作系统和程序语言中，当前的线程都有一个独特的身份(id)，并且这个身份信息可以以一个普通值的形式被被很容易地获取到，典型的可以是一个integer或者指针值。这种情况下我们做一个抽象化的thread-local storage(线程本地存储，多线程编程中不希望其它线程访问的内容)就很容易，只需要以线程的id作为key的一个map就可以解决问题，每一个线程以其id就能从中获取到值，且和其它线程互不冲突。goroutine没有可以被程序员获取到的身份(id)的概念。这一点是设计上故意而为之，由于thread-local storage总是会被滥用。比如说，一个web server是用一种支持tls的语言实现的，而非常普遍的是很多函数会去寻找HTTP请求的信息，这代表它们就是去其存储层(这个存储层有可能是tls)查找的。这就像是那些过分依赖全局变量的程序一样，会导致一种非健康的“距离外行为”，在这种行为下，一个函数的行为可能不是由其自己内部的变量所决定，而是由其所运行在的线程所决定。因此，如果线程本身的身份会改变——比如一些worker线程之类的——那么函数的行为就会变得神秘莫测。Go鼓励更为简单的模式，这种模式下参数对函数的影响都是显式的。这样不仅使程序变得更易读，而且会让我们自由地向一些给定的函数分配子任务时不用担心其身份信息影响行为。

* golang中CSP并发编程模型

> CSP模型是上个世纪七十年代提出的，用于描述两个独立的并发实体通过共享的通讯 channel(管道)进行通信的并发模型。 CSP中channel是第一类对象，它不关注发送消息的实体，而关注与发送消息时使用的channel。

> Golang 就是借用CSP模型的一些概念为之实现并发进行理论支持，其实从实际上出发，go语言并没有，完全实现了CSP模型的所有理论，仅仅是借用了 process和channel这两个概念。process是在go语言上的表现就是 goroutine 是实际并发执行的实体，每个实体之间是通过channel通讯来实现数据共享。

> Golang中使用 CSP中 channel 这个概念。channel 是被单独创建并且可以在进程之间传递，它的通信模式类似于 boss-worker 模式的，一个实体通过将消息发送到channel 中，然后又监听这个 channel 的实体处理，两个实体之间是匿名的，这个就实现实体中间的解耦，其中 channel 是同步的一个消息被发送到 channel 中，最终是一定要被另外的实体消费掉的，在实现原理上其实是一个阻塞的消息队列。

## 参考

`Go语言程序设计`
`http://www.jianshu.com/p/36e246c6153d`
