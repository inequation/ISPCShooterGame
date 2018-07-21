export uniform int Kernel(uniform int i, uniform int l)
{
	varying int j = 0;
	foreach(k = 0 ... i)
	{
		j = k;
	}
	// Return *something*...
	return reduce_add(j) + l;
}
