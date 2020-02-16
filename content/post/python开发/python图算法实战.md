---
title: python图算法实战
date: 2020-02-16 18:12:00+08:00
tags:
  - python
  - networkx
  - graphviz
categories:
  - python开发
---

复工后第一周的工作是用python写一个图遍历的算法，周末稍微总结一下。

## 纯手工写

最开始想挑战一下，于是不借助任何第三方库，纯手工编写，其实也不太难。

```python
# 用一个字典表示有向图中各节点到其它节点的边
graph = {'A': ['B', 'C', 'D'],
         'B': ['E'],
         'C': ['D', 'F'],
         'D': ['B', 'E', 'G'],
         'E': [],
         'F': ['D', 'G'],
         'G': ['E']}

# 查找从一个节点到另一个节点的路径
def findPath(graph, start, end, path=[]):
    path = path + [start]
    if start == end:
        return path
    for node in graph[start]:
        if node not in path:
            newpath = findPath(graph, node, end, path)
            if newpath:
                return newpath
    return None


# 找到所有从start到end的路径
def findAllPath(graph, start, end, path=[]):
    path = path + [start]
    if start == end:
        return [path]

    paths = []  # 存储所有路径
    for node in graph[start]:
        if node not in path:
            newpaths = findAllPath(graph, node, end, path)
            for newpath in newpaths:
                paths.append(newpath)
    return paths


# 查找最短路径
def findShortestPath(graph, start, end, path=[]):
    path = path + [start]
    if start == end:
        return path

    shortestPath = []
    for node in graph[start]:
        if node not in path:
            newpath = findShortestPath(graph, node, end, path)
            if newpath:
                if not shortestPath or len(newpath) < len(shortestPath):
                    shortestPath = newpath
    return shortestPath

# 查找最短路径
def findLongestPath(graph, start, end, path=[]):
    path = path + [start]
    if start == end:
        return path

    longestPath = []
    for node in graph[start]:
        if node not in path:
            newpath = findLongestPath(graph, node, end, path)
            if newpath:
                if not longestPath or len(newpath) > len(longestPath):
                    longestPath = newpath
    return longestPath
```

代码不太难，可以看到上述方法均使用了递归。

然后测试一下：

```python
onepath = findPath(graph, 'A', 'E')
print('一条路径:', onepath)

allpath = findAllPath(graph, 'A', 'E')
print('\n所有路径：', allpath)

shortpath = findShortestPath(graph, 'A', 'E')
print('\n最短路径：', shortpath)

longpath = findLongestPath(graph, 'A', 'E')
print('\n最长路径：', longpath)
```

为了便于观看这个有向图到底长成什么样子了，这里用`graphviz`画一下这个有向图：

```python
import tempfile
from graphviz import Digraph

g = Digraph(name='G')
g.node_attr.update(shape='circle')
g.node('A', shape='doublecircle')
g.node('E', shape='doublecircle')
for tail, v in graph.items():
    for head in v:
        g.edge(tail, head)

g.view(tempfile.mktemp('.gv'))
```

## 使用networkx库实现

纯手工写可以锻炼下动手能力，但真正在生产实践中，面对时刻变化的需求，还是找一个成熟的图算法库好一点，这里我找到了[networkx](https://networkx.github.io/)这个python库。

`networkx`这个库支持多种类型的图：无向图、有向图、允许平行边的无向图、允许平行边的有向图。

| Networkx Class | Type       | Self-loops allowed | Parallel edges allowed |
| -------------- | ---------- | ------------------ | ---------------------- |
| Graph          | undirected | Yes                | No                     |
| DiGraph        | directed   | Yes                | No                     |
| MultiGraph     | undirected | Yes                | Yes                    |
| MultiDiGraph   | directed   | Yes                | Yes                    |

如果对排序一致性有要求的话，还可以用`**OrderedGraph**`、`**OrderedDiGraph**`、`**OrderedMultiGraph**`、`**OrderedMultiDiGraph**`这四个变种。

选择合适的图类型即可创建图，如下：

```python
import networkx as nx

g = nx.OrderedDiGraph()
```

接下来就可以向图中添加节点和边了：

```python
# 只要对象是hashable的，即可添加进图
g.add_node(1)
g.add_node(2)
g.add_nodes_from([3, 4, 5])

g.add_edge(1, 2)
g.add_edges_from([(2, 3), (3, 4), (4, 5)])
```

可以访问图的节点或边：

```python
g.nodes()

g.edges()
```

访问图中节点的邻居：

```python
g.adj[1]
```

访问图中某些节点相关的度量：

```python
g.degree([1, 2])
```

图、节点、边上都可以添加属性：

```python
g.graph['desc']='This is a demo graph'

g.nodes[1]['name'] = 'node1'

g.edges[(1, 2)]['desc'] = 'from 1 to 2'
```

用相关的API构造出图后，即可采用一定的算法处理这个图，`networkx`提供了很多相关的算法[
Algorithms](https://networkx.github.io/documentation/stable/reference/algorithms/index.html#)，这个就是这个库的关键所在了，思考下业务场景找到对应的算法调用即可。

比如想搜索一下图中出现的环，使用这个包[Cycles](https://networkx.github.io/documentation/stable/reference/algorithms/cycles.html)下的方法就可以了：

```python
from networkx.algorithms.cycles import simple_cycles

cycles = simple_cycles(g)
```

探索从某节点到某节点的路径列表，使用这个包[Simple Paths](https://networkx.github.io/documentation/stable/reference/algorithms/simple_paths.html)下的方法：

```python
from networkx.algorithms.simple_paths import all_simple_paths, shortest_simple_paths

all_paths = all_simple_paths(g, 'S', 'E')

shortest_paths = shortest_simple_paths(g, 'S', 'E')
```

除此以外，这个库还提供一些生成器方法，用来生成一些业界很知名的图，这个可以很方便地用来进行测试，如：

```python
petersen = nx.petersen_graph()
tutte = nx.tutte_graph()
maze = nx.sedgewick_maze_graph()
tet = nx.tetrahedral_graph()
```

最后为了让开发人员可以直观地看图，`networkx`也提供将图画出来的能力，不过我还是习惯用`graphviz`来画，这个样式调整起来更方便，见上面`graphviz`的小例子。

DONE！

## 参考

1. https://networkx.github.io/
2. https://graphviz.readthedocs.io/



