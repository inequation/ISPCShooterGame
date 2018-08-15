#pragma once

inline void* uniform extract(void* varying x, uniform int i)
{
	return (void* uniform)extract((unsigned int64)x, i);
}

inline const void* uniform extract(const void* varying x, uniform int i)
{
	return (const void* uniform)extract((unsigned int64)x, i);
}

inline bool uniform extract(bool varying x, uniform int i)
{
	return (uniform bool)extract((int8)x, i);
}

inline uniform int<2> extract(varying int<2> v, int uniform i)
{
	uniform int<2> u;
	u.x = extract(v.x, i);
	u.y = extract(v.y, i);
	return u;
}

inline uniform int<3> extract(varying int<3> v, int uniform i)
{
	uniform int<3> u;
	u.x = extract(v.x, i);
	u.y = extract(v.y, i);
	u.z = extract(v.z, i);
	return u;
}

inline uniform float<4> extract(varying float<4> v, uniform int i)
{
	uniform float<4> u;
	u.x = extract(v.x, i);
	u.y = extract(v.y, i);
	u.z = extract(v.z, i);
	u.w = extract(v.w, i);
	return u;
}

inline float* uniform extract(float* varying x, uniform int i)
{
	return (float* uniform)extract((void* varying)x, i);
}

inline varying bool insert(varying bool v, uniform int32 index, uniform bool u)
{
	return (varying bool)insert((varying int8)v, index, (uniform int8)u);
}

inline varying float<3> insert(varying float<3> v, uniform int32 index, uniform float<3> u)
{
	v.x = insert(v.x, index, u.x);
	v.y = insert(v.y, index, u.y);
	v.z = insert(v.z, index, u.z);
	return v;
}
