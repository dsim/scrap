﻿/**
 * from Boost.Interfaces
 * Written by Kenji Hara(9rnsr)
 * License: Boost License 1.0
 */
module interfaces;

import std.traits, std.typecons, std.typetuple;
import std.functional;

import meta_forward, meta_expand;

version = SharedTest;
version = ImmutableTest;


private template AdaptTo(I) if( is(I == interface) )
{
	alias MakeSignatureTbl!(I, 0).result Names;
	alias MakeSignatureTbl!(I, 3).result FnTypes;
	
	bool isAllContains(T)()
	{
		alias MakeSignatureTbl!(I, 0).result I_Names;
		alias MakeSignatureTbl!(I, 1).result I_FpTypes;
		
		alias MakeSignatureTbl!(T, 0).result T_Names;
		alias MakeSignatureTbl!(T, 1).result T_FpTypes;
		
		bool result = true;
		foreach( i, name; I_Names )
		{
			
			bool res = false;
			foreach( j, s; T_Names )
			{
				if( name == s
				 && is(ParameterTypeTuple!(I_FpTypes[i])
					== ParameterTypeTuple!(T_FpTypes[j])) )
				{
					res = true;
					break;
				}
			}
			result = result && res;
			if( !result ) break;
		}
		return result;
	}
	
	final class Impl(T) : I
	{
	private:
		T obj;
		this(T o){ obj = o; }
	
	public:
		template MixinAll(int n)
		{
			static if( n >= Names.length )
			{
				enum result = q{};
			}
			else
			{
	//			pragma(msg, FnTypes[n]);
				enum N = n.stringof;
				enum result = 
					mixin(expand!q{
						mixin Forward!(
							FnTypes[${N}],
							Names[${N}],	//"__${N}__",
							"return obj." ~ Names[${N}] ~ "(args);"
						);
					//	mixin("alias __${N}__ " ~ Names[${N}] ~ ";");
					})
					~ MixinAll!(n+1).result;
			}
		}
//		pragma(msg, MixinAll!(0).result);
		mixin(MixinAll!(0).result);
	}
}


/+
template LazyInterfaceI(string def)
{
	static assert(
		__traits(compiles, {
			mixin("interface I { " ~ def ~ "}");
		}),
		"invalid interface definition");
	mixin("interface I { " ~ def ~ "}");
}


/// 
template LazyInterface(string def)
{
	alias LazyInterface!(LazyInterfaceI!(def).I) LazyInterface;
}

/// 
struct LazyInterface(I) if( is(I == interface) )
{
protected:	// want to be private
//	static assert(
//		__traits(compiles, {
//			mixin("interface I { " ~ def ~ "}");
//		}),
//		"invalid interface definition");
//	mixin("interface I { " ~ def ~ "}");

private:
	alias MakeSignatureTbl!(I, 0).result Names;
	alias MakeSignatureTbl!(I, 1).result FpTypes;
	alias MakeSignatureTbl!(I, 2).result DgTypes;
	alias MakeSignatureTbl!(I, 3).result FnTypes;
	
	void*	objptr;
	FpTypes	funtbl;

	static bool isAllContains(I, T)()
	{
		alias MakeSignatureTbl!(I, 0).result I_Names;
		alias MakeSignatureTbl!(I, 1).result I_FpTypes;
		
		alias MakeSignatureTbl!(T, 0).result T_Names;
		alias MakeSignatureTbl!(T, 1).result T_FpTypes;
		
		bool result = true;
		foreach( i, name; I_Names )
		{
			
			bool res = false;
			foreach( j, s; T_Names )
			{
				if( name == s
				 && is(ParameterTypeTuple!(I_FpTypes[i])
					== ParameterTypeTuple!(T_FpTypes[j])) )
				{
					res = true;
					break;
				}
			}
			result = result && res;
			if( !result ) break;
		}
		return result;
	}


public:
	this(T)(T obj) if( isAllContains!(I, T)() )
	{
		objptr = cast(void*)obj;
		foreach( i, name; Names )
		{
			static if( is(FpTypes[i] U == U*) )
			{
				static if( is(U == immutable) )
				{
					DgTypes[i] dg = mixin("&(cast(immutable)obj)." ~ name);
				}
				else static if( is(U == shared) && is(U == const) )
				{
					DgTypes[i] dg = mixin("&(cast(shared const)obj)." ~ name);
				}
				else static if( is(U == shared) )
				{
					DgTypes[i] dg = mixin("&(cast(shared)obj)." ~ name);
				}
				else static if( is(U == const) )
				{
					DgTypes[i] dg = mixin("&(cast(const)obj)." ~ name);
				}
				else
				{
					DgTypes[i] dg = mixin("&(cast(Unqual!T)obj)." ~ name);
				}
			}
			funtbl[i] = dg.funcptr;
		}
	}
	
	template MixinAll(int n)
	{
		static if( n >= Names.length )
		{
			enum result = q{};
		}
		else
		{
//			pragma(msg, FnTypes[n]);
			enum N = n.stringof;
			enum result = 
				mixin(expand!q{
					mixin Forward!(
						FnTypes[${N}],
						"__${N}__",
						q{ return composeDg(objptr, funtbl[${N}])(args); }
					);
					mixin("alias __${N}__ " ~ Names[${N}] ~ ";");
				})
				~ MixinAll!(n+1).result;
		}
	}
//	pragma(msg, MixinAll!(0).result);
	mixin(MixinAll!(0).result);
	
	static auto opDispatch(string Name, Args...)(Args args)
	{
		static if( __traits(compiles, mixin("I." ~ Name))
				&& __traits(isStaticFunction, mixin("I." ~ Name)) )
		{
			return mixin("I." ~ Name)(args);
		}
		else
		{
			static assert(0,
				"member '" ~ Name ~ "' not found in " ~ Names.stringof);
		}
	}

}
+/


I adaptTo(I, T)(T obj) if( AdaptTo!I.isAllContains!T() )
{
	return new AdaptTo!I.Impl!T(obj);
}


unittest
{
	static class C
	{
		int draw(){ return 10; }
	}
	interface Drawable
	{
		int draw();
	}
	
	auto c = new C();
	Drawable d = adaptTo!Drawable(c);
	assert(d.draw() == 10);
}


/+unittest
{
	class N
	{
		int draw(){ return 10; }
	}
	interface Drawable
	{
		int draw();
	}
	
	auto n = new N();
	auto d = adaptTo!Drawable(n);
	assert(d.draw() == 10);
}+/


unittest
{
	static class A
	{
		int draw(){ return 10; }
	}
	static class B : A
	{
		int draw(){ return 20; }
	}
	
	interface Drawable
	{
		int draw();
	}
	
	auto a = new A();
	auto b = new B();
	
	Drawable d;
	d = adaptTo!Drawable(a);
	assert(d.draw() == 10);
	d = adaptTo!Drawable(b);
	assert(d.draw() == 20);
	d = adaptTo!Drawable(cast(A)b);
	assert(d.draw() == 20); 	// dynamic interface resolution
}


unittest
{
	static class A
	{
		int draw(){ return 10; }
	}
	
	interface S{
		int draw();
		static int f(){ return 20; }
	}
	
	S s = adaptTo!S(new A());
	assert(s.draw() == 10);
	assert(s.f() == 20);
	assert(S.f() == 20);
	static assert(!__traits(compiles, s.g()));
}


unittest
{
	static class A
	{
		int draw()				{ return 10; }
		int draw() const		{ return 20; }
		int draw() shared		{ return 30; }	// not supported
		int draw() shared const { return 40; }	// not supported
		int draw() immutable	{ return 50; }	// not supported
	}
	
	interface Drawable
	{
		int draw();
		int draw() const;
		int draw() shared;
		int draw() shared const;
		int draw() immutable;
	}
	
	auto a = new A();
/+	{
		Drawable d = a;
		assert(composeDg(d.objptr, d.funtbl[0])() == 10);
		assert(composeDg(d.objptr, d.funtbl[1])() == 20);
	  version(SharedTest)
	  {
		assert(composeDg(d.objptr, d.funtbl[2])() == 30);
		assert(composeDg(d.objptr, d.funtbl[3])() == 40);
	  }
	  version(ImmutableTest)
	  {
		assert(composeDg(d.objptr, d.funtbl[4])() == 50);
	  }
	}+/
	{
		auto		   d = adaptTo!Drawable(a);
		const		  cd = adaptTo!Drawable(a);
		shared		  sd = adaptTo!(shared(Drawable))(cast(shared)a);	// workaround
		shared const scd = adaptTo!(shared(Drawable))(cast(shared)a);	// workaround
		immutable	  id = adaptTo!(immutable(Drawable))(cast(immutable)a);	// workaround
		assert(  d.draw() == 10);
		assert( cd.draw() == 20);
	  version(SharedTest)
	  {
		assert( sd.draw() == 30);
		assert(scd.draw() == 40);
	  }
	  version(ImmutableTest)
	  {
		assert( id.draw() == 50);
	  }
	}
}


unittest
{
	static class A
	{
		int draw()				{ return 1; }
		int draw() const		{ return 10; }
		int draw(int v) 		{ return v*2; }
		int draw(int v, int n)	{ return v*n; }
	}
	static class B
	{
		int draw()				{ return 2; };
	}
	static class X
	{
		void undef(){}
	}
	static class Y
	{
		void draw(double f){}
	}

	{
		interface Drawable1
		{
			int draw();
		}
		
		Drawable1 d = adaptTo!Drawable1(new A());
		assert(d.draw() == 1);
		
		d = adaptTo!Drawable1(new B());
		assert(d.draw() == 2);
		
		static assert(!__traits(compiles, d = adaptTo!Drawable1(new X())));
	}
	{
		interface Drawable2
		{
			int draw(int v);
		}
		
		Drawable2 d = adaptTo!Drawable2(new A());
		static assert(!__traits(compiles, d.draw()));
		assert(d.draw(8) == 16);
	}
	{
		interface Drawable3
		{
			int draw(int v, int n);
		}
		
		Drawable3 d = adaptTo!Drawable3(new A());
		assert(d.draw(8, 8) == 64);
		
		static assert(!__traits(compiles, d = adaptTo!Drawable3(new Y())));
	}
}


private template MakeSignatureTbl(T, int Mode)
{
	alias TypeTuple!(__traits(allMembers, T)) Names;
	
	template CollectOverloadsImpl(string Name)
	{
		alias TypeTuple!(__traits(getVirtualFunctions, T, Name)) Overloads;
		
		template MakeTuples(int N)
		{
			static if( N < Overloads.length )
			{
				static if( Mode == 0 )	// identifier names
				{
					alias TypeTuple!(
						Name,
						MakeTuples!(N+1).result
					) result;
				}
				static if( Mode == 1 )	// function-pointer types
				{
					alias TypeTuple!(
						typeof(&Overloads[N]),
						MakeTuples!(N+1).result
					) result;
				}
				static if( Mode == 2 )	// delegate types
				{
					alias TypeTuple!(
						typeof({
							typeof(&Overloads[N]) fp;
							return toDelegate(fp);
						}()),
						MakeTuples!(N+1).result
					) result;
				}
				static if( Mode == 3 )	// delegate types
				{
					alias TypeTuple!(
						typeof(Overloads[N]),
						MakeTuples!(N+1).result
					) result;
				}
			}
			else
			{
				alias TypeTuple!() result;
			}
		}
		
		alias MakeTuples!(0).result result;
	}
	template CollectOverloads(string Name)
	{
		alias CollectOverloadsImpl!(Name).result CollectOverloads;
	}
	
	alias staticMap!(CollectOverloads, Names) result;
}


// modified from std.functional
auto toDelegate(F)(auto ref F fp) if (isCallable!(F)) {

	static if (is(F == delegate))
	{
		return fp;
	}
	else static if (is(typeof(&F.opCall) == delegate)
				|| (is(typeof(&F.opCall) V : V*) && is(V == function)))
	{
		return toDelegate(&fp.opCall);
	}
	else
	{
		alias typeof(&(new DelegateFaker!(F)).doIt) DelType;

		static struct DelegateFields {
			union {
				DelType del;

				struct {
					void* contextPtr;
					typeof({
						auto dg = &(new DelegateFaker!(F)).doIt;
						return dg.funcptr;
					}()) funcPtr;
						// get delegate type including StorageClass Modifier
				}
			}
		}

		// fp is stored in the returned delegate's context pointer.
		// The returned delegate's function pointer points to
		// DelegateFaker.doIt.
		DelegateFields df;

		df.contextPtr = cast(void*) fp;

		DelegateFaker!(F) dummy;
		auto dummyDel = &(dummy.doIt);
		df.funcPtr = dummyDel.funcptr;

		return df.del;
	}
}


/// 
auto composeDg(T...)(T args)
{
	static if( T.length==1 && is(Unqual!(T[0]) X == Tuple!(void*, U), U) )
	{
		auto tup = args[0];
		//alias typeof(tup.field[1]) U;
		
		auto ptr		= tup.field[0];
		auto funcptr	= tup.field[1];
		
	}
	else static if( T.length==2 && (
						is(Unqual!(T[0]) X == X*) && (
							is(X Y == const Y) ||
							is(X Y == shared Y) ||
							is(X Y == shared const Y) ||
							is(X Y == immutable Y) ||
							is(X Y == Y)
						) && is(Y == void)
					) &&
					isFunctionPointer!(Unqual!(T[1])) )
	{
		auto ptr		= args[0];
		auto funcptr	= args[1];
		alias T[1] U;
		
	}
	else
	{
		static assert(0, T.stringof);
	}
	
	ReturnType!U delegate(ParameterTypeTuple!U) dg;
	dg.ptr		= cast(void*)ptr;
	dg.funcptr	= cast(typeof(dg.funcptr))funcptr;
	return dg;
}
unittest
{
	int localfun(int n){ return n*10; }
	
	auto dg = &localfun;
	assert(composeDg(dg.ptr, dg.funcptr)(5) == 50);
}


