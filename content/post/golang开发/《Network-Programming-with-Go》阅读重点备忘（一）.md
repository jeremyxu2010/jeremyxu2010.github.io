---
title: 《Network Programming with Go》阅读重点备忘（一）
author: Jeremy Xu
tags:
  - golang
  - network
categories:
  - golang开发
date: 2016-10-24 00:42:00+08:00
---
最近读了一本老外写的电子书《[Network Programming with Go](https://jannewmarch.gitbooks.io/network-programming-with-go-golang-/content/index.html)》，感觉写得还可以，在这里将书中一些重点记录一下以备忘。

## 架构

跟其它书不同，这本书的第一章主要讲了分布式系统与传统单机系统在架构层面的区别。其中有4节我觉得还挺重要的，设计分布式系统时可以多参考这些方面。

> ###Points of Failure###

> Distributed applications run in a complex environment. This makes them much more prone to failure than standalone applications on a single computer. The points of failure include

>
* The client side of the application could crash
* The client system may have h/w problems
* The client's network card could fail
* Network contention could cause timeouts
* There may be network address conflicts
* Network elements such as routers could fail
* Transmission errors may lose messages
* The client and server versions may be incompatible
* The server's network card could fail
* The server system may have h/w problems
* The server s/w may crash
* The server's database may become corrupted

> Applications have to be designed with these possible failures in mind. Any action performed by one component must be recoverable if failure occurs in some other part of the system. Techniques such as transactions and continuous error checking need to be employed to avoid errors.

> ###Acceptance Factors###

>
* Reliability
* Performance
* Responsiveness
* Scalability
* Capacity
* Security

> ###Transparency###

> The "holy grails" of distributed systems are to provide the following:

>
* access transparency
* location transparency
* migration transparency
* replication transparency
* concurrency transparency
* scalability transparency
* performance transparency
* failure transparency

> ###Eight fallacies of distributed computing###

> Sun Microsystems was a company that performed much of the early work in distributed systems, and even had a mantra "The network is the computer." Based on their experience over many years a number of the scientists at Sun came up with the following list of fallacies commonly assumed:

>
* The network is reliable.
* Latency is zero.
* Bandwidth is infinite.
* The network is secure.
* Topology doesn't change.
* There is one administrator.
* Transport cost is zero.
* The network is homogeneous.

> Many of these directly impact on network programming. For example, the design of most remote procedure call systems is based on the premise that the network is reliable so that a remote procedure call will behave in the same way as a local call. The fallacies of zero latency and infinite bandwidth also lead to assumptions about the time duration of an RPC call being the same as a local call, whereas they are magnitudes of order slower.

> The recognition of these fallacies led Java's RMI (remote method invocation) model to require every RPC call to potentially throw a RemoteException. This forced programmers to at least recognise the possibility of network error and to remind them that they could not expect the same speeds as local calls.

## TCP、UDP与Raw Socket

第三章就讲到golang里面的socket编程了。

### 首先是IP地址与端口服务相关概念及关键类型。

```
type IP []byte # IP类型
ip := net.ParseIP(ipStr) # 由string解析出IP类型
type IPMask []byte # IPMask类型
func IPv4Mask(a, b, c, d byte) IPMask # 得到一个IPMask
func (ip IP) DefaultMask() IPMask # 得到一个IP地址默认的IPMask
func (ip IP) Mask(mask IPMask) IP # 得到一个IP地址所对应的网络地址
type IPAddr {
    IP IP
} # IPAddr类型
func ResolveIPAddr(net, addr string) (*IPAddr, os.Error) # 由string解析出一个IPAddr， 如net.ResolveIPAddr("ip4", "192.168.1.1")
func LookupHost(name string) (cname string, addrs []string, err os.Error) # 根据主机名查找其对应的CName与IP地址
func LookupPort(network, service string) (port int, err os.Error) # 查询一个服务的默认端口， 如port, err := net.LookupPort("tcp", "telnet")
type TCPAddr struct {
    IP   IP
    Port int
} # TCPAddr类型
func ResolveTCPAddr(net, addr string) (*TCPAddr, os.Error) # 解析出一个TCPAddr类型， 如addr, err := net.ResolveTCPAddr("tcp", "192.168.1.1:23")
```

### 然后TCP相关API

```
# TCPConn实现了Writer与Reader接口
func (c *TCPConn) Write(b []byte) (n int, err os.Error)
func (c *TCPConn) Read(b []byte) (n int, err os.Error)
# 客户端连接TCP，如conn, err := net.DialTCP("tcp", nil, addr)
func DialTCP(net string, laddr, raddr *TCPAddr) (c *TCPConn, err os.Error)
# 服务端监听TCP，如listener, err := net.ListenTCP("tcp", addr)
func ListenTCP(net string, laddr *TCPAddr) (l *TCPListener, err os.Error)
# 服务端接受了一个连接，如conn, err := listener.Accept()
func (l *TCPListener) Accept() (c Conn, err os.Error)
```

TCP服务端的一般范式为

```
service := ":1201"
tcpAddr, err := net.ResolveTCPAddr("tcp", service)
checkError(err)
listener, err := net.ListenTCP("tcp", tcpAddr)
checkError(err)
for {
    conn, err := listener.Accept()
    if err != nil {
        continue
    }
    // run as a goroutine
    go handleClient(conn)
}
```

### UDP相关API

```
# 解析出UDP的地址
func ResolveUDPAddr(net, addr string) (*UDPAddr, os.Error)
# 客户端连接UDP， 如conn, err := net.DialUDP("udp", nil, addr)
func DialUDP(net string, laddr, raddr *UDPAddr) (c *UDPConn, err os.Error)
# 服务端监听UDP，如conn, err := net.ListenUDP("udp", addr)
func ListenUDP(net string, laddr *UDPAddr) (c *UDPConn, err os.Error)
# 服务端读写UDP包数据
func (c *UDPConn) ReadFromUDP(b []byte) (n int, addr *UDPAddr, err os.Error
func (c *UDPConn) WriteToUDP(b []byte, addr *UDPAddr) (n int, err os.Error)
```

UDP服务端的一般范式为

```
service := ":1200"
udpAddr, err := net.ResolveUDPAddr("udp", service)
checkError(err)
conn, err := net.ListenUDP("udp", udpAddr)
checkError(err)
for {
    handleClient(conn)
}
```

### Raw Socket相关API

```
# 客户端连接Raw Socket
func DialIP(netProto string, laddr, raddr *IPAddr) (*IPConn, error)
# 服务端监听Raw Socket
func ListenIP(netProto string, laddr *IPAddr) (*IPConn, error)
# 客户端或服务端读写Raw Socket
func (c *IPConn) ReadFromIP(b []byte) (int, *IPAddr, error)
func (c *IPConn) WriteToIP(b []byte, addr *IPAddr) (int, error)
```

更范型化的接口

```
# 客户端连接服务端，如conn, err := net.Dial("tcp", nil, addr) 或 conn, err := net.Dial("udp", nil, addr) 或 conn, err := net.Dial("ip", nil, addr)
func Dial(net, laddr, raddr string) (c Conn, err os.Error)
# 服务端监听TCP，如listener, err := net.Listen("tcp", addr)
func Listen(net, laddr string) (l Listener, err os.Error)
# 服务端接受TCP连接, 如conn, err := listener.Accept()
func (l Listener) Accept() (c Conn, err os.Error)
# 服务端监听UDP, 如conn, err := net.ListenPacket("udp", addr)
func ListenPacket(net, laddr string) (c PacketConn, err os.Error)
# 服务端读写UDP包数据
type PacketConn interface {
	ReadFrom(b []byte) (n int, addr Addr, err error)
	WriteTo(b []byte, addr Addr) (n int, err error)
}
```

### 选择接口的原则

> The Go net package recommends using these interface types rather than the concrete ones. But by using them, you lose specific methods such as SetKeepAlive or TCPConn and SetReadBuffer of UDPConn, unless you do a type cast. It is your choice.

## 数据序列化

第四章讲的是数据序列化方案

### asn1序列化

```
# 将对象marshal为字节数组
func Marshal(val interface{}) ([]byte, error)
# 从字节数组unmarshal回对象
func Unmarshal(b []byte, val interface{}) (rest []byte, err error)
```

这个主要用于读写X.509证书。

### json序列化

```
# 获得一个json encoder
encoder := json.NewEncoder(writer)
# 将对象序列化
err := encoder.Encode(obj)
encoder.Close()

# 获得一个json decoder
decoder := json.NewDecoder(reader)
# 将对象反序列化
err := decoder.Decode(&obj)
```

json序列化方案功能比较完善，语言互操作性好，序列化后结果也可读便于查错。但其基于文本，性能与大小可能没有基于字节流的好。

### gob序列化

```
# 获得一个gob encoder
encoder := gob.NewEncoder(writer)
# 将对象序列化
err := encoder.Encode(obj)
encoder.Close()

# 获得一个gob decoder
decoder := gob.NewDecoder(reader)
# 将对象反序列化
err := decoder.Decode(&obj)
```

golang语言特有的序列化方案，功能完善，高效，但语言互操作性不好。

### 字节数组序列化为string

base64序列化方案

```
# 获得一个base64 encoder
encoder := base64.NewEncoder(base64.StdEncoding, writer)
# 将对象序列化
err := encoder.Encode(obj)
encoder.Close()

# 直接进行base64序列化
str := base64.StdEncoding.EncodeToString(obj)

# 获得一个base64 decoder
decoder := base64.NewDecoder(base64.StdEncoding, reader)
# 将对象反序列化
err := decoder.Decode(&obj)

# 直接进行base64反序列化
bb, err := base64.StdEncoding.DecodeString(str)
```

可以看到golang里各种编码器的API很类似，用会一个，其它就举一反三了，这点很好。

## 应用层协议设计

第5章主要讲应用层如何设计。其中讲到的概念其实以前做网络编程都涉及过，只不过在这章归纳总结后，更清晰了。

应用层协议设计主要有以下方面需要注意：

* 传输层协议选择
* 是否有回应？如何处理回应丢失，超时。
* 传输的数据格式，基于文本还是基于字节流。
* 传输的数据包格式设计
* 协议的版本控制
* 应用的状态如何转换
* 如何控制服务质量
* 最终目标文件是一个独立的程序还是一个供第三方调用的库

详细的说明可参阅[Application-Level Protocols](https://jannewmarch.gitbooks.io/network-programming-with-go-golang-/content/applevelprotocols/index.html)

上述这些问题并没有一个确定性的答案，需要根据具体场景作决策。

这里针对两种不同的数据格式，服务端的代码范式如下

```
# 基于字节流的数据格式
handleClient(conn) {
    while (true) {
        byte b = conn.readByte()
        switch (b) {
            case MSG_TYPE_1: ...
            case MSG_TYPE_2: ...
            ...
        }
    }
}

# 基于文本的数据格式
handleClient(conn) {
    while (true) {
        line = conn.readLine()
        if (line.startsWith(...) {
            ...
        } else if (line.startsWith(...) {
            ...
        }
    }
}
```

## 字符集与文字编码

第6章主要讲了字符集与文字编码问题，这里有一个概念要理解一下。

* 字符： 某种语言中一个独立的符号，可能是一个字母，一个汉字，一个标点符号等。
* 字符集： 多个同类型的字符组成的一个集合，比如ASCII字符集、GBK字符集、BIG5字符集、Unicode字符集等。
* 字符code: 字符在某个字符集中对应的整体值。比如在ASCII字符集中字母'A'的字符code为65。
* 字符编码：将字符code编码为计算机真正可识别的字节数组，比如ASCII字符编码、GBK字符编码、UTF16字符编码、UTF8字符编码。

golang内部使用UTF-8字符编码对字符串进行编码，UTF-8字符编码是一种针对Unicode的可变长度字符编码。因此在编程中会用到以下方法。

```
str := "百度一下，你就知道"
# 得到字符串进行UTF-8编码后最后字节数组的长度
println("Byte length", len(str))
# 得到字符串中字符的个数
println("String length", len([]rune(str)))
```

字符集与字符编码的问题很重要，但事实上平时在编程中遇到比较多的可能仅仅是读写中文字符文件，这个记录一下，其它编码的处理也类似。

```
fileName := "test.txt"
if _, err := os.Stat(fileName); os.IsNotExist(err) {
	_, err := os.Create(fileName)
	checkErr(err)
}

f, err := os.Open(fileName)
checkErr(err)

writer := transform.NewWriter(f, simplifiedchinese.GB18030.NewEncoder())
io.WriteString(writer, "百度一下，你就知道")
writer.Close()

reader := transform.NewReader(f, simplifiedchinese.GB18030.NewDecoder())
bb, err := ioutil.ReadAll(reader)
checkErr(err)
fmt.Println(string(bb))

f.Close()
```

## 安全

第7章主要讲安全，在编程中主要用到的有以下几种技术。

### 用于检验数据完整性的hash算法

```
# 下面的md5的使用，其它sha1, sha256等hash算法的使用方法类似
hash := md5.New() // hash := md5.NewMD5([]byte{27, 23, 13, 55})
bytes := []byte("hello\n")
hash.Write(bytes)
hashValue := hash.Sum(nil)
```

### 对称加密

```
# 这里演示了blowfish对称加密算法，其它AES，DES使用方法类似
key := []byte("my key")
cipher, err := blowfish.NewCipher(key)
if err != nil {
	fmt.Println(err.Error())
}

# 加密
enc := make([]byte, 255)
cipher.Encrypt(enc, []byte("hello world"))

# 解密
decrypt := make([]byte, 8)
cipher.Decrypt(decrypt, enc)
fmt.Println(string(decrypt))
```

### 非对称加密

这里仅说明了下如何生成一对RSA公私钥及如何加载RSA公私钥，如何生成证书及如何加载证书，因为在编程中很少自己进行非对称加密，一般用在TLS连接会话里。而使用方法多数仅仅只是在建立连接时配置一下证书。

```
# 生成一对公私钥，并保存到文件
func main() {
	privateKey, err := rsa.GenerateKey(rand.Reader, 2048)
	checkErr(err)
	publicKey := &(privateKey.PublicKey)
	savePEMKey("pri.key", privateKey)
	savePEMPublicKey("pub.key", publicKey)
}
func savePEMPublicKey(path string, key *rsa.PublicKey) {
	file, err := os.Create(path)
	checkErr(err)
	defer file.Close()
	publicKey, err := ssh.NewPublicKey(key)
	checkErr(err)
	file.Write(ssh.MarshalAuthorizedKey(publicKey))
}
func savePEMKey(path string, key *rsa.PrivateKey) {
	file, err := os.Create(path)
	checkErr(err)
	defer file.Close()
	block := &pem.Block{
		Type : "RSA PRIVATE KEY",
		Bytes : x509.MarshalPKCS1PrivateKey(key),
	}
	pem.Encode(file, block)

}
func checkErr(err error) {
	if err != nil {
		fmt.Fprintf(os.Stderr, "error: %v", err)
		os.Exit(-1)
	}
}

# 从文件中加载公私钥
func main() {
	privateKey := loadPEMKey("pri.key")
	fmt.Printf("%v\n", *privateKey)
	publicKey := loadPEMPublicKey("pub.key")
	fmt.Printf("%v\n", *publicKey)
}
func loadPEMKey(path string) *rsa.PrivateKey {
	file, err := os.Open(path)
	checkErr(err)
	defer file.Close()
	bb, err := ioutil.ReadAll(file)
	block, _ := pem.Decode(bb)
	privateKey, err := x509.ParsePKCS1PrivateKey(block.Bytes)
	checkErr(err)
	return privateKey
}
func loadPEMPublicKey(path string) *rsa.PublicKey{
	file, err := os.Open(path)
	checkErr(err)
	defer file.Close()
	bb, err := ioutil.ReadAll(file)
	checkErr(err)
	pkey, _, _, _, err:= ssh.ParseAuthorizedKey(bb)
	checkErr(err)
	if pkey, ok := pkey.(ssh.CryptoPublicKey); ok {
		publicKey := pkey.CryptoPublicKey().(*rsa.PublicKey)
		return publicKey
	}
	return nil
}
func checkErr(err error) {
	if err != nil {
		fmt.Fprintf(os.Stderr, "error: %v", err)
		os.Exit(-1)
	}
}

# 生成证书，并保存证书到文件
func main() {
	generateCert("test.cer.pem")
}
func generateCert(path string) {
	random := rand.Reader
	privateKey := loadPEMKey("pri.key")
	now := time.Now()
	then := now.Add(60 * 60 * 24 * 365 * 1000 * 1000 * 1000) // one year
	template := x509.Certificate{
		SerialNumber: big.NewInt(1),
		Subject: pkix.Name{
			CommonName:   "jan.newmarch.name",
			Organization: []string{"Jan Newmarch"},
		},
		NotBefore: now,
		NotAfter:  then,

		SubjectKeyId: []byte{1, 2, 3, 4},
		KeyUsage:     x509.KeyUsageCertSign | x509.KeyUsageKeyEncipherment | x509.KeyUsageDigitalSignature,

		BasicConstraintsValid: true,
		IsCA:                  true,
		DNSNames:              []string{"jan.newmarch.name", "localhost"},
	}
  derBytes, err := x509.CreateCertificate(random, &template,
		&template, &(privateKey.PublicKey), privateKey)
	checkErr(err)

	block := &pem.Block{
		Type: "CERTIFICATE",
		Bytes: derBytes,
	}

	certCerFile, err := os.Create(path)
	checkErr(err)
	pem.Encode(certCerFile, block)
	certCerFile.Close()
}

func loadPEMKey(path string) *rsa.PrivateKey {
	file, err := os.Open(path)
	checkErr(err)
	defer file.Close()
	bb, err := ioutil.ReadAll(file)
	block, _ := pem.Decode(bb)
	privateKey, _ := x509.ParsePKCS1PrivateKey(block.Bytes)
	return privateKey
}
func checkErr(err error) {
	if err != nil {
		fmt.Fprintf(os.Stderr, "error: %v", err)
		os.Exit(-1)
	}
}

# 从文件中加载证书
func main() {
	cert := loadCert("test.cer.pem")
	fmt.Printf("%v\n", *cert)
}
func loadCert(path string) *x509.Certificate {
	certCerFile, err := os.Open(path)
	checkErr(err)
	bb, err := ioutil.ReadAll(certCerFile)
	checkErr(err)
	certCerFile.Close()

	block, _ := pem.Decode(bb)

	// trim the bytes to actual length in call
	cert, err := x509.ParseCertificate(block.Bytes)
	checkErr(err)
	return cert;
}
func checkErr(err error) {
	if err != nil {
		fmt.Fprintf(os.Stderr, "error: %v", err)
		os.Exit(-1)
	}
}

# TCP服务端启用TLS
func main() {
	startTCPServerWithTLS()
}
func startTCPServerWithTLS() {
	cert, err := tls.LoadX509KeyPair("test.cer.pem", "pri.key")
	checkErr(err)
	config := tls.Config{Certificates: []tls.Certificate{cert}}
	now := time.Now()
	config.Time = func() time.Time { return now }
	config.Rand = rand.Reader
	_, err = tls.Listen("tcp", ":1200", &config)
	checkErr(err)
	...
}

# TCP客户端启用TLS
func main() {
	startTCPClientWithTLS()
}
func startTCPClientWithTLS() {
	conn, err := tls.Dial("tcp", "127.0.0.1:1200", nil)
	checkErr(err)
	handleClient(conn)
}
```
