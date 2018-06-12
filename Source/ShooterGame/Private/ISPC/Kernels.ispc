export uniform int Kernel(uniform int i)
{
	varying int j = 0;
	foreach(k = 0 ... i)
	{
		j = k;
	}
	return reduce_add(j);
}