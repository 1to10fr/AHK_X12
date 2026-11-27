Echo, % Add(2, 3)
Echo, % Fact(5)
Echo, % Fib(10)
Echo, % Greet("Ann") . "|" . Greet()
x := 10
Bump(x)
Echo, x=%x%
y := 1
Scope()
Echo, y=%y% leaked=%leaked%
Echo, % Max3(4, 9, 2)
Echo, % Add(Add(1, 2), Add(3, 4))
if (IsEven(10) && !IsEven(7))
	Echo, even ok
Return

Add(a, b)
{
	return a + b
}
Fact(n)
{
	if (n <= 1)
		return 1
	return n * Fact(n - 1)
}
Fib(n)
{
	if (n < 2)
		return n
	return Fib(n - 1) + Fib(n - 2)
}
Greet(name := "World")
{
	return "Hello " . name
}
Bump(ByRef v)
{
	v := v + 5
}
Scope()
{
	y := 99
	leaked := 1
}
Max3(a, b, c)
{
	m := a
	if (b > m)
		m := b
	if (c > m)
		m := c
	return m
}
IsEven(n)
{
	return Mod(n, 2) = 0
}
