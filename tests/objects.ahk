a := [10, 20, 30]
Echo, % a.Length . " " . a[1] . " " . a[-1]
a.Push(40)
a[2] := 21
a[3] += 5
Echo, % a.Join("-")
Echo, % a.Pop() . " " . a.Length
m := Map("one", 1, "two", 2)
m["three"] := 3
m["one"] += 10
Echo, % m.Count . " " . m["one"] . " " . m.Has("two") . m.Has("zzz") . " " . m.Get("zzz", "dflt")
o := {name: "Ann", age: 30}
o.age := o.age + 1
o.city := "Cairo"
Echo, % o.name . " " . o.age . " " . o.city
nested := {list: [1, 2, 3], inner: Map("k", "v")}
nested.list.Push(4)
nested.list[1] := 100
Echo, % nested.list.Join(",") . " " . nested.inner["k"]
total := 0
for v in a
	total += v
Echo, total=%total%
for i, v in [5, 6]
	Echo, % i . ":" . v
keys := ""
for k, v in Map("x", 1, "y", 2)
	keys .= k . "=" . v . ";"
Echo, %keys%
for k in {p: 1, q: 2}
	keys .= k
Echo, %keys%
Echo, % Sum([1, 2, 3, 4]) . " " . Depth(3)
parts := StrSplit("a,b,c", ",")
Echo, % parts.Length . parts[3] . " " . IsObject(parts) . IsObject("x")
Echo, % Sorted2([5, 3])
b := a.Clone()
b.Push(99)
Echo, % a.Length . " " . b.Length
Return

Sum(arr)
{
	s := 0
	for v in arr
		s += v
	return s
}
Depth(n)
{
	c := 0
	for v in [1, 2]
	{
		if (n > 0)
			c += Depth(n - 1)
		c += 1
	}
	return c
}
Sorted2(arr)
{
	if (arr[1] > arr[2])
		return arr[2] . "<" . arr[1]
	return arr[1] . "<" . arr[2]
}
