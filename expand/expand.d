﻿import std.algorithm : startsWith;
import std.ctype : isalpha, isalnum;
import std.traits : isCallable, isSomeString;
import std.stdio;

/**
Expand expression in string literal, with mixin expression.
--------------------
enum string op = "+";
static assert(mixin(expand!q{ 1 ${op} 2 }) == q{ 1 + 2 });
--------------------

If expreesion is single variable:$(UL
$(LI you can omit side braces)
$(LI automatically provides you implicitly conversion to string (requires importing std.conv.to)))
--------------------
int n = 2;
string msg = "hello";
writeln(mixin(expand!"I told you $n times: $msg!"));
// prints "I told you 2 times: hello!"
--------------------

Other example, it is easy making parameterized code-blocks.
--------------------
template DefFunc(string name)
{
  // generates specified name function.
  mixin(
    mixin(expand!q{
      int ${name}(int a){ return a; }
    })
  );
}
--------------------
 */
template expand(string s)
{
	enum expand = expandImpl(s);
}

private @trusted
{
	public string expandImpl(string code)
	{
		auto s = Slice(Kind.CODESTR, code);
		s.parseCode();
		return "`" ~ s.buffer ~ "`";
	}

	enum Kind
	{
		METACODE,
		CODESTR,
		STR_IN_METACODE,
		ALT_IN_METACODE,
		RAW_IN_METACODE,
		QUO_IN_METACODE,
	}

	string match(Pred)(string s, Pred pred)
	{
		static if (isCallable!Pred)
		{
			size_t eaten = 0;
			while (eaten < s.length && pred(s[eaten]))
				++eaten;
			if (eaten)
				return s[0..eaten];
			return null;
		}
		else static if (isSomeString!Pred)
		{
			if (startsWith(s, pred))
				return s[0 .. pred.length];
			return null;
		}
	}
/+
	// match and eat
	string munch(Pred)(ref string s, Pred pred)
	{
		auto r = chomp(s, pred);
		if (r.length)
			s = s[r.length .. $];
		return r;
	}+/
	
	struct Slice
	{
		Kind current;
		string buffer;
		size_t eaten;
		
		this(Kind c, string h, string t=null){
			current = c;
			if (t is null)
			{
				buffer = h;
				eaten = 0;
			}
			else
			{
				buffer = h ~ t;
				eaten = h.length;
			}
		}
		
		bool chomp(string s)
		{
			auto res = startsWith(tail, s);
			if (res)
				eaten += s.length;
			return res;
		}
		void chomp(size_t n)
		{
			if (eaten + n <= buffer.length)
				eaten += n;
		}
		
		@property bool  exist() {return eaten < buffer.length;}
		@property string head() {return buffer[0..eaten];}
		@property string tail() {return buffer[eaten..$];}

		bool parseEsc()
		{
			if (chomp(`\`))
			{
				if (chomp("x"))
					chomp(2);
				else
					chomp(1);
				return true;
			}
			else
				return false;
		}
		bool parseStr()
		{
			if (chomp(`"`))
			{
				auto save_head = head;	// workaround for ctfe
				
				auto s = Slice(
					(current == Kind.METACODE ? Kind.STR_IN_METACODE : current),
					tail);
				while (s.exist && !s.chomp(`"`))
				{
					if (s.parseVar()) continue;
					if (s.parseEsc()) continue;
					s.chomp(1);
				}
				this = Slice(
					current,
					(current == Kind.METACODE
						? save_head[0..$-1] ~ `("` ~ s.head[0..$-1] ~ `")`
						: save_head[0..$] ~ s.head[0..$]),
					s.tail);
				
				return true;
			}
			else
				return false;
		}
		bool parseAlt()
		{
			if (chomp("`"))
			{
				auto save_head = head;	// workaround for ctfe
				
				auto s = Slice(
					(current == Kind.METACODE ? Kind.ALT_IN_METACODE : current),
					tail);
				while (s.exist && !s.chomp("`"))
				{
					if (s.parseVar()) continue;
					s.chomp(1);
				}
				this = Slice(
					current,
					(current == Kind.METACODE
						? save_head[0..$-1] ~ "(`" ~ s.head[0..$-1] ~ "`)"
						: save_head[0..$-1] ~ "` ~ \"`\" ~ `" ~ s.head[0..$-1] ~ "` ~ \"`\" ~ `"),
					s.tail);
				return true;
			}
			else
				return false;
		}
		bool parseRaw()
		{
			if (chomp(`r"`))
			{
				auto save_head = head;	// workaround for ctfe
				
				auto s = Slice(
					(current == Kind.METACODE ? Kind.RAW_IN_METACODE : current),
					tail);
				while (s.exist && !s.chomp(`"`))
				{
					if (s.parseVar()) continue;
					s.chomp(1);
				}
				this = Slice(
					current,
					(current == Kind.METACODE
						? save_head[0..$-2] ~ `(r"` ~ s.head[0..$-1] ~ `")`
						: save_head[0..$] ~ s.head[0..$]),
					s.tail);
				
				return true;
			}
			else
				return false;
		}
		bool parseQuo()
		{
			if (chomp(`q{`))
			{
				auto save_head = head;	// workaround for ctfe
				
				auto s = Slice(
					(current == Kind.METACODE ? Kind.QUO_IN_METACODE : current),
					tail);
				if (s.parseCode!`}`())
				{
					this = Slice(
						current,
						(current == Kind.METACODE
							? save_head[0..$-2] ~ `(q{` ~ s.head[0..$-1] ~ `})`
							: save_head[] ~ s.head),
						s.tail);
				}
				return true;
			}
			else
				return false;
		}
		bool parseBlk()
		{
			if (chomp(`{`))
				return parseCode!`}`();
			else
				return false;
		}
		private void checkVarNested()
		{
			if (current == Kind.METACODE)
				if (__ctfe)
					assert(0, "Invalid var in raw-code.");
				else
					throw new Exception("Invalid var in raw-code.");
		}
		private string encloseVar(string exp)
		{
			string open, close;
			switch(current)
			{
			case Kind.CODESTR		:	open = "`" , close = "`";	break;
			case Kind.STR_IN_METACODE:	open = `"` , close = `"`;	break;
			case Kind.ALT_IN_METACODE:	open = "`" , close = "`";	break;
			case Kind.RAW_IN_METACODE:	open = `r"`, close = `"`;	break;
			case Kind.QUO_IN_METACODE:	open = `q{`, close = `}`;	break;
			}
			return close ~ " ~ " ~ exp ~ " ~ " ~ open;
		}
		bool parseVar()
		{
			if (auto r = match(tail, `$`))
			{
				auto t = tail[1..$];
				
				static bool isIdtHead(dchar c) { return c=='_' || isalpha(c); }
				static bool isIdtTail(dchar c) { return c=='_' || isalnum(c); }
				
				if (match(t, `{`))
				{
					checkVarNested();
					
					auto s = Slice(Kind.METACODE, t[1..$]);
					s.parseCode!`}`();
					this = Slice(current, head ~ encloseVar(s.head[0..$-1]), s.tail);
					
					return true;
				}
				else if (auto r = match(t[0..1], &isIdtHead))
				{
					checkVarNested();
					
					auto id = t[0 .. 1 + match(t[1..$], &isIdtTail).length];
					this = Slice(current, head ~ encloseVar(".std.conv.to!string(" ~ id ~ ")"), t[id.length .. $]);
					
					return true;
				}
				return false;
			}
			return false;
		}
		bool parseCode(string end=null)()
		{
			enum endCheck = end ? "!chomp(end)" : "true";
			
			while (exist && mixin(endCheck))
			{
				if (parseStr()) continue;
				if (parseAlt()) continue;
				if (parseRaw()) continue;
				if (parseQuo()) continue;
				if (parseBlk()) continue;
				if (parseVar()) continue;
				chomp(1);
			}
			return true;
		}
	}
}

import expand_utest;
