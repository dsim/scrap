﻿module test;

import interfaces;

import std.stdio;


void main(){}


/+class A
{
	void f() {}
	void f_c() const{}
	void f_s() shared{}
	void f_sc() shared const{}
	void f_i() immutable{}
}
unittest
{
	pragma(msg, typeof(&A.f).mangleof);		//             void()
	pragma(msg, typeof(&A.f_c).mangleof);		//const        void()
	pragma(msg, typeof(&A.f_s).mangleof);		//shared       void()
	pragma(msg, typeof(&A.f_sc).mangleof);	//shared const void()
	pragma(msg, typeof(&A.f_i).mangleof);		//immutable    void()		// immutable
}+/

/+class A
{
	synchronized void y_f() {}
	synchronized void y_f_c() const{}
	synchronized void y_f_i() immutable{}
	synchronized void y_f_cs() shared const{}
	synchronized void y_f_is() shared immutable{}
	
	void f() {}
	void f_c() const{}
	void f_i() immutable{}
	void f_s() shared{}
	void f_sc() shared const{}
	void f_si() shared immutable{}
	
	//invalid storage class
	//void f_ci() const immutable{}
}

unittest
{
	pragma(msg, typeof(A.y_f));		//shared       void()
	pragma(msg, typeof(A.y_f_c));	//shared const void()
	pragma(msg, typeof(A.y_f_i));	//immutable    void()		// immutable優先
	pragma(msg, typeof(A.y_f_cs));	//shared const void()
	pragma(msg, typeof(A.y_f_is));	//shared       void()		// 明示sharedで上書き、bug?
	pragma(msg, "----");
	pragma(msg, typeof(A.f));		//             void()
	pragma(msg, typeof(A.f_c));		//const        void()
	pragma(msg, typeof(A.f_i));		//immutable    void()		// immutable
	pragma(msg, typeof(A.f_s));		//shared       void()
	pragma(msg, typeof(A.f_sc));	//shared const void()
	pragma(msg, typeof(A.f_si));	//shared       void()		// shared優先、bug?
}
+/
