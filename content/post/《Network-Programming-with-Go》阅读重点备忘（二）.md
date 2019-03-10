---
title: 《Network Programming with Go》阅读重点备忘（二）
author: Jeremy Xu
tags:
  - golang
  - network
categories:
  - golang开发
date: 2016-10-25 00:14:00+08:00
---
接上一篇博文，这里是我阅读电子书《[Network Programming with Go](https://jannewmarch.gitbooks.io/network-programming-with-go-golang-/content/index.html)》后，书中一些重点的第二部分。

## HTTP

第8章主要讲到了golang中对HTTP的支持。

首先是很关键的两个对象*Request*与*Response*，及一些常用的发送HTTP请求的方法。

```
# Request对象
type Request struct {
	// Method specifies the HTTP method (GET, POST, PUT, etc.).
	// For client requests an empty string means GET.
	Method string

	// URL specifies either the URI being requested (for server
	// requests) or the URL to access (for client requests).
	//
	// For server requests the URL is parsed from the URI
	// supplied on the Request-Line as stored in RequestURI.  For
	// most requests, fields other than Path and RawQuery will be
	// empty. (See RFC 2616, Section 5.1.2)
	//
	// For client requests, the URL's Host specifies the server to
	// connect to, while the Request's Host field optionally
	// specifies the Host header value to send in the HTTP
	// request.
	URL *url.URL

	// The protocol version for incoming server requests.
	//
	// For client requests these fields are ignored. The HTTP
	// client code always uses either HTTP/1.1 or HTTP/2.
	// See the docs on Transport for details.
	Proto      string // "HTTP/1.0"
	ProtoMajor int    // 1
	ProtoMinor int    // 0

	// Header contains the request header fields either received
	// by the server or to be sent by the client.
	//
	// If a server received a request with header lines,
	//
	//	Host: example.com
	//	accept-encoding: gzip, deflate
	//	Accept-Language: en-us
	//	fOO: Bar
	//	foo: two
	//
	// then
	//
	//	Header = map[string][]string{
	//		"Accept-Encoding": {"gzip, deflate"},
	//		"Accept-Language": {"en-us"},
	//		"Foo": {"Bar", "two"},
	//	}
	//
	// For incoming requests, the Host header is promoted to the
	// Request.Host field and removed from the Header map.
	//
	// HTTP defines that header names are case-insensitive. The
	// request parser implements this by using CanonicalHeaderKey,
	// making the first character and any characters following a
	// hyphen uppercase and the rest lowercase.
	//
	// For client requests, certain headers such as Content-Length
	// and Connection are automatically written when needed and
	// values in Header may be ignored. See the documentation
	// for the Request.Write method.
	Header Header

	// Body is the request's body.
	//
	// For client requests a nil body means the request has no
	// body, such as a GET request. The HTTP Client's Transport
	// is responsible for calling the Close method.
	//
	// For server requests the Request Body is always non-nil
	// but will return EOF immediately when no body is present.
	// The Server will close the request body. The ServeHTTP
	// Handler does not need to.
	Body io.ReadCloser

	// ContentLength records the length of the associated content.
	// The value -1 indicates that the length is unknown.
	// Values >= 0 indicate that the given number of bytes may
	// be read from Body.
	// For client requests, a value of 0 means unknown if Body is not nil.
	ContentLength int64

	// TransferEncoding lists the transfer encodings from outermost to
	// innermost. An empty list denotes the "identity" encoding.
	// TransferEncoding can usually be ignored; chunked encoding is
	// automatically added and removed as necessary when sending and
	// receiving requests.
	TransferEncoding []string

	// Close indicates whether to close the connection after
	// replying to this request (for servers) or after sending this
	// request and reading its response (for clients).
	//
	// For server requests, the HTTP server handles this automatically
	// and this field is not needed by Handlers.
	//
	// For client requests, setting this field prevents re-use of
	// TCP connections between requests to the same hosts, as if
	// Transport.DisableKeepAlives were set.
	Close bool

	// For server requests Host specifies the host on which the
	// URL is sought. Per RFC 2616, this is either the value of
	// the "Host" header or the host name given in the URL itself.
	// It may be of the form "host:port".
	//
	// For client requests Host optionally overrides the Host
	// header to send. If empty, the Request.Write method uses
	// the value of URL.Host.
	Host string

	// Form contains the parsed form data, including both the URL
	// field's query parameters and the POST or PUT form data.
	// This field is only available after ParseForm is called.
	// The HTTP client ignores Form and uses Body instead.
	Form url.Values

	// PostForm contains the parsed form data from POST, PATCH,
	// or PUT body parameters.
	//
	// This field is only available after ParseForm is called.
	// The HTTP client ignores PostForm and uses Body instead.
	PostForm url.Values

	// MultipartForm is the parsed multipart form, including file uploads.
	// This field is only available after ParseMultipartForm is called.
	// The HTTP client ignores MultipartForm and uses Body instead.
	MultipartForm *multipart.Form

	// Trailer specifies additional headers that are sent after the request
	// body.
	//
	// For server requests the Trailer map initially contains only the
	// trailer keys, with nil values. (The client declares which trailers it
	// will later send.)  While the handler is reading from Body, it must
	// not reference Trailer. After reading from Body returns EOF, Trailer
	// can be read again and will contain non-nil values, if they were sent
	// by the client.
	//
	// For client requests Trailer must be initialized to a map containing
	// the trailer keys to later send. The values may be nil or their final
	// values. The ContentLength must be 0 or -1, to send a chunked request.
	// After the HTTP request is sent the map values can be updated while
	// the request body is read. Once the body returns EOF, the caller must
	// not mutate Trailer.
	//
	// Few HTTP clients, servers, or proxies support HTTP trailers.
	Trailer Header

	// RemoteAddr allows HTTP servers and other software to record
	// the network address that sent the request, usually for
	// logging. This field is not filled in by ReadRequest and
	// has no defined format. The HTTP server in this package
	// sets RemoteAddr to an "IP:port" address before invoking a
	// handler.
	// This field is ignored by the HTTP client.
	RemoteAddr string

	// RequestURI is the unmodified Request-URI of the
	// Request-Line (RFC 2616, Section 5.1) as sent by the client
	// to a server. Usually the URL field should be used instead.
	// It is an error to set this field in an HTTP client request.
	RequestURI string

	// TLS allows HTTP servers and other software to record
	// information about the TLS connection on which the request
	// was received. This field is not filled in by ReadRequest.
	// The HTTP server in this package sets the field for
	// TLS-enabled connections before invoking a handler;
	// otherwise it leaves the field nil.
	// This field is ignored by the HTTP client.
	TLS *tls.ConnectionState

	// Cancel is an optional channel whose closure indicates that the client
	// request should be regarded as canceled. Not all implementations of
	// RoundTripper may support Cancel.
	//
	// For server requests, this field is not applicable.
	//
	// Deprecated: Use the Context and WithContext methods
	// instead. If a Request's Cancel field and context are both
	// set, it is undefined whether Cancel is respected.
	Cancel <-chan struct{}

	// Response is the redirect response which caused this request
	// to be created. This field is only populated during client
	// redirects.
	Response *Response

	// ctx is either the client or server context. It should only
	// be modified via copying the whole Request using WithContext.
	// It is unexported to prevent people from using Context wrong
	// and mutating the contexts held by callers of the same request.
	ctx context.Context
}

# Response对象
type Response struct {
	Status     string // e.g. "200 OK"
	StatusCode int    // e.g. 200
	Proto      string // e.g. "HTTP/1.0"
	ProtoMajor int    // e.g. 1
	ProtoMinor int    // e.g. 0

	// Header maps header keys to values. If the response had multiple
	// headers with the same key, they may be concatenated, with comma
	// delimiters.  (Section 4.2 of RFC 2616 requires that multiple headers
	// be semantically equivalent to a comma-delimited sequence.) Values
	// duplicated by other fields in this struct (e.g., ContentLength) are
	// omitted from Header.
	//
	// Keys in the map are canonicalized (see CanonicalHeaderKey).
	Header Header

	// Body represents the response body.
	//
	// The http Client and Transport guarantee that Body is always
	// non-nil, even on responses without a body or responses with
	// a zero-length body. It is the caller's responsibility to
	// close Body. The default HTTP client's Transport does not
	// attempt to reuse HTTP/1.0 or HTTP/1.1 TCP connections
	// ("keep-alive") unless the Body is read to completion and is
	// closed.
	//
	// The Body is automatically dechunked if the server replied
	// with a "chunked" Transfer-Encoding.
	Body io.ReadCloser

	// ContentLength records the length of the associated content. The
	// value -1 indicates that the length is unknown. Unless Request.Method
	// is "HEAD", values >= 0 indicate that the given number of bytes may
	// be read from Body.
	ContentLength int64

	// Contains transfer encodings from outer-most to inner-most. Value is
	// nil, means that "identity" encoding is used.
	TransferEncoding []string

	// Close records whether the header directed that the connection be
	// closed after reading Body. The value is advice for clients: neither
	// ReadResponse nor Response.Write ever closes a connection.
	Close bool

	// Uncompressed reports whether the response was sent compressed but
	// was decompressed by the http package. When true, reading from
	// Body yields the uncompressed content instead of the compressed
	// content actually set from the server, ContentLength is set to -1,
	// and the "Content-Length" and "Content-Encoding" fields are deleted
	// from the responseHeader. To get the original response from
	// the server, set Transport.DisableCompression to true.
	Uncompressed bool

	// Trailer maps trailer keys to values in the same
	// format as Header.
	//
	// The Trailer initially contains only nil values, one for
	// each key specified in the server's "Trailer" header
	// value. Those values are not added to Header.
	//
	// Trailer must not be accessed concurrently with Read calls
	// on the Body.
	//
	// After Body.Read has returned io.EOF, Trailer will contain
	// any trailer values sent by the server.
	Trailer Header

	// Request is the request that was sent to obtain this Response.
	// Request's Body is nil (having already been consumed).
	// This is only populated for Client requests.
	Request *Request

	// TLS contains information about the TLS connection on which the
	// response was received. It is nil for unencrypted responses.
	// The pointer is shared between responses and should not be
	// modified.
	TLS *tls.ConnectionState
}

# 常用发送HTTP请求方法
func Head(url string) (resp *Response, err error)
func Get(url string) (resp *Response, err error)
func Post(url string, bodyType string, body io.Reader) (resp *Response, err error)
```

如果需要对*HTTP Request*对象进行定制，可使用以下范式。

```
request, err := http.NewRequest("GET", url.String(), nil)
checkError(err)
request.Header.Add("Accept-Charset", "UTF-8;q=1, ISO-8859-1;q=0")
client := &http.Client{}
response, err := client.Do(request)
...
```

发送请求时使用HTTP代理也可以通过定制*http.Client*对象及*HTTP Request*对象来完成。

```
transport := &http.Transport{Proxy: http.ProxyURL(proxyURL)}
client := &http.Client{Transport: transport}
request, err := http.NewRequest("GET", url.String(), nil)
auth := "jannewmarch:mypassword"
basic := "Basic " + base64.StdEncoding.EncodeToString([]byte(auth))
request.Header.Add("Proxy-Authorization", basic)
client := &http.Client{}
response, err := client.Do(request)
```

HTTP服务端主要涉及4个API

```
# Handler接口
type Handler interface {
	ServeHTTP(ResponseWriter, *Request)
}

# 用于监听并开始伺服，此处handler可定制multiplexer，如handler为nil, 则为DefaultServeMux
func ListenAndServe(addr string, handler Handler) error

# 某一个url pattern采用`handler`这个Handler接口来处理
func Handle(pattern string, handler Handler)

# 某一个url pattern采用`handler`这个请求处理函数来处理
func HandleFunc(pattern string, handler func(ResponseWriter, *Request))

# 将一个请求处理函数转化为实现Handler接口的对象
type HandlerFunc func(ResponseWriter, *Request)
// ServeHTTP calls f(w, r).
func (f HandlerFunc) ServeHTTP(w ResponseWriter, r *Request) {
	f(w, r)
}
```

服务端代码的一般范式为

```
fileServer := http.FileServer(http.Dir("/var/www"))
# 使用http.Handle注册实现了Handler接口的对象来处理某个pattern的请求
http.Handle("/", fileServer)
# 使用http.HandleFunc注册请求处理函数来处理某个pattern的请求
http.HandleFunc("/cgi-bin/printenv", printEnv)
# 最后调用http.ListenAndServe监听并开始伺服
err := http.ListenAndServe(":8000", nil)
    checkError(err)
```

## 模板

动态页面技术免不了需要使用模板，第9章讲了模板相关内容

使用模板的一般范式为

```
# 定义模板字符串
temp := `
....
`
# 使用模板，参考数据形成输出
t := template.New("Person template")
t, err := t.Parse(templ)
if err == nil {
    buff := bytes.NewBufferString("")
    t.Execute(buff, person)
}
```

模板里主要有以下写法

```
{{.Name}}

{{range .Emails}}
        ...
{{end}}

{{with .Jobs}}
    {{range .}}
        ...
    {{end}}
{{end}}

{{. | html}}

```

还可以定义函数，可在模板中使用

```
const templ = `The name is {{.Name}}.
{{range .Emails}}
        An email is "{{. | emailExpand}}"
{{end}}
`
t := template.New("Person template")
// add our function
t = t.Funcs(template.FuncMap{"emailExpand": EmailExpander})
t, err := t.Parse(templ)
checkError(err)
err = t.Execute(os.Stdout, person)
checkError(err)
```

在模板中定义变量

```
const templ = `{{$name := .Name}}
{{range .Emails}}
    Name is {{$name}}, email is {{.}}
{{end}}
```

最后一小节在讲到根据条件进行输出时，讲到两种方法输出序列间的逗号。

```
# 使用if判断循环的索引
{{range $index, $elmt := .Emails}}
  {{if $index}}
      , "{{$elmt}}"
  {{else}}
       "{{$elmt}}"
  {{end}}
{{end}}


# 利用定义的函数根据条件输出逗号
tmpl := `{{$comma := sequence "" ", "}}
{{range $}}
  {{$comma.Next}}{{.}}
{{end}}`
var fmap = template.FuncMap{
    "sequence": sequenceFunc
}
t, err := template.New("").Funcs(fmap).Parse(tmpl)
if err != nil {
    fmt.Printf("parse error: %v\n", err)
    return
}
err = t.Execute(os.Stdout, []string{"a", "b", "c", "d", "e", "f"})
type generator struct {
    ss []string
    i  int
    f  func(s []string, i int) string
}
func (seq *generator) Next() string {
    s := seq.f(seq.ss, seq.i)
    seq.i++
    return s
}
func sequenceGen(ss []string, i int) string {
    if i >= len(ss) {
        return ss[len(ss)-1]
    }
    return ss[i]
}
func sequenceFunc(ss ...string) (*generator, error) {
    if len(ss) == 0 {
        return nil, errors.New("sequence must have at least one element")
    }
    return &generator{ss, 0, sequenceGen}, nil
}
```

最后利用前面讲的知识，写了一个[较完整的HTTP Server](https://jannewmarch.gitbooks.io/network-programming-with-go-golang-/content/webserver/the_complete_server.html)。

## XML

第12章讲了golang对XML的处理，这里重点是XML对应结构体中属性的tag值。

```
type Person struct {
    XMLName Name    `xml:"person"`
    Name    Name    `xml:"name"`
    Email   []Email `xml:"email"`
}

type Name struct {
    Family   string `xml:"family"`
    Personal string `xml:"personal"`
}

type Email struct {
    Type    string `xml:"type,attr"`
    Address string `xml:",chardata"`
}

str := `<?xml version="1.0" encoding="utf-8"?>
<person>
  <name>
    <family> Newmarch </family>
    <personal> Jan </personal>
  </name>
  <email type="personal">
    jan@newmarch.name
  </email>
  <email type="work">
    j.newmarch@boxhill.edu.au
  </email>
</person>`

# XML的unmarshal操作
var person Person
err := xml.Unmarshal([]byte(str), &person)
checkError(err)

# XML的marshal操作
bb, err := xml.Marshal(person)
checkError(err)
str2 := string(bb)
```

## RPC

第13章主要讲了在golang里几种RPC编写范式。

```
# HTTP RPC Server
arith := new(Arith)
rpc.Register(arith)
rpc.HandleHTTP()
err := http.ListenAndServe(":1234", nil)
if err != nil {
    fmt.Println(err.Error())
}

# HTTP RPC Client
client, err := rpc.DialHTTP("tcp", "127.0.0.1:1234")
if err != nil {
    log.Fatal("dialing:", err)
}
// Synchronous call
args := Args{17, 8}
var reply int
err = client.Call("Arith.Multiply", args, &reply)

# TCP RPC Server
arith := new(Arith)
rpc.Register(arith)
tcpAddr, err := net.ResolveTCPAddr("tcp", ":1234")
checkError(err)
listener, err := net.ListenTCP("tcp", tcpAddr)
checkError(err)
rpc.Accept(listener)

# TCP RPC Client
client, err := rpc.Dial("tcp", "127.0.0.1:1234")
if err != nil {
    log.Fatal("dialing:", err)
}
// Synchronous call
args := Args{17, 8}
var reply int
err = client.Call("Arith.Multiply", args, &reply)

# JSON RPC Server
arith := new(Arith)
rpc.Register(arith)
tcpAddr, err := net.ResolveTCPAddr("tcp", ":1234")
checkError(err)
listener, err := net.ListenTCP("tcp", tcpAddr)
checkError(err)
for {
    conn, err := listener.Accept()
    if err != nil {
        continue
    }
    jsonrpc.ServeConn(conn)
}

# JSON RPC Client
client, err := jsonrpc.Dial("tcp", "127.0.0.1:1234")
if err != nil {
    log.Fatal("dialing:", err)
}
// Synchronous call
args := Args{17, 8}
var reply int
err = client.Call("Arith.Multiply", args, &reply)
```

## netchan

第14章讲到的netchan包在Go 1.7.1上未找到，可能是早期版本提供的包，这里就不总结了。

## WebSockets

第15章主要讲websocket在golang里的应用，在我这里websocket相关支持在`golang.org/x/net/websocket`包里。

Server端范式如下。

```
# 这里ws是Conn类型，因此可对其进行读写
func echoServer(ws *Conn) {
	defer ws.Close()
	io.Copy(ws, ws)
}
func main() {
    http.Handle("/", websocket.Handler(echoServer))
    err := http.ListenAndServe(":12345", nil)
    checkError(err)
}

# 使用websocket.Message读写string
msgToSend := "Hello"
err := websocket.Message.Send(ws, msgToSend)
var msgToReceive string
err := websocket.Message.Receive(conn, &msgToReceive)

# 使用websocket.Message读写byte slice
dataToSend := []byte{0, 1, 2}
err := websocket.Message.Send(ws, dataToSend)
var dataToReceive []byte
err := websocket.Message.Receive(conn, &dataToReceive)

# 使用websocket.JSON读写json
person := Person{Name: "Jan",
    Emails: []string{"ja@newmarch.name", "jan.newmarch@gmail.com"},
}
err = websocket.JSON.Send(conn, person)
var person Person
err := websocket.JSON.Receive(ws, &person)

# 创造自定义编解码器
func xmlMarshal(v interface{}) (msg []byte, payloadType byte, err error) {
    msg, err = xml.Marshal(v)
    return msg, websocket.TextFrame, nil
}
func xmlUnmarshal(msg []byte, payloadType byte, v interface{}) (err error) {
    err = xml.Unmarshal(msg, v)
    return err
}
var XMLCodec = websocket.Codec{xmlMarshal, xmlUnmarshal}
person := Person{Name: "Jan",
    Emails: []string{"ja@newmarch.name", "jan.newmarch@gmail.com"},
}
err = XMLCodec.Send(conn, person)
var person Person
err := XMLCodec.Receive(ws, &person)
```

最后一小节演示了HTTP Server使用TLS socket的办法。

```
err := http.ListenAndServeTLS(":12345", "jan.newmarch.name.pem",
        "private.pem", nil)
```

## 总结

花了点时间将这本电子书《[Network Programming with Go](https://jannewmarch.gitbooks.io/network-programming-with-go-golang-/content/index.html)》的重点都抓出来了，同时在抓取的过程写了不少小例子进行测试学习，这样学习印象就挺深刻了。以后学习其它东西也可以仿照这个，多记一些笔记。

