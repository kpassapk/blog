---
title: Optimizing Go Tests for Readability
date: 2023-11-05T20:00:00-05:00
---

# Optimizing Go Tests for Readability

Software developers spend much more time reading code than writing code. By
various accounts, time deciphering and analyzing code exceeds time writing by at
lest 5x - and it could be as much as 20x.

This measure is compounded when a new developer is brought onto an existing
codebase, looking to adapt it to a new business requirement. Before a single
line of code is altered, they are going to be doing a lot of reading to zero in
on the place to make the change.

A well-structured suite of unit and integration tests becomes an invaluable
asset in this context. If the tests are readable, the new developer can start by
reading the tests, then go to the code being tested. Tests can tremendously aid
the readability of the system. But they can also hinder it: in typical
Object-Oriented (OO) code, they are obscured by lengthy test setup, or can be
too low-level to be understood quickly.

At Yalo, we have settled on a variant of Go table-driven tests which uses
scenarios to express test setup. By making tests more friendly to new readers,
they help speed up change cycles and make software more maintainable in the long
run.

## Test Setup in OO-land

Unit testing is key to the overall reliability of a system. Although there is a
surprising amount of debate on the subject, the general rule that higher unit
test coverage leads to more reliable code is beyond question.

Unit tests should test the smallest unit of code possible: a function. 

If the function under test is a pure function, tests are straightforward:
a test takes a set of inputs, runs the function and checks the results.

Object-based test code will require more setup. The object of the class
(equivalent to the receiver in go) needs to be initialized somehow. Each of the
object's collaborators may have varied state. Doing this setup compactly is key
to successful testing of object-based code. (See this [great
talk](https://youtu.be/Iel4vVYgExA?si=cVbGO0SU8lKoueyG) for more on test setup.)

The Go community uses table-driven testing heavily to keep tests concise. This
pattern is particularly great for simple functions. For functions with complex
receivers, it is hard to keep these tests compact and easy to understand.

We will walk through a table-driven test on a simple receiver object.
Then we will rewrite it in a more human-friendly way as a scenario.

## Code to test

We will test a greeter object, which can be constructed with a language string.
It will provide us with a greeting in that language.

```golang
type lang string

const (
	en lang = "EN"
	es lang = "ES"
)

type greeter struct {
	lang lang
}
```

When we create a new greeter, we provide a language. 
```golang
func NewGreeter(l string) greeter {
	return greeter{
		lang: lang(l),
	}
}
```

The `Hello` and `Goodbye` methods return a greeting string or an error, in case
an unknown language is provided. (In practice, we would want
to check the language in the constructor. This example is contrived to illustrate
some functions which can return errors.)

```go
func (g greeter) Hello(name string) (string, error) {
	switch g.lang {
	case es:
		return fmt.Sprintf("hola, %s", name), nil
	case en:
		return fmt.Sprintf("hi, %s", name), nil
	default:
		return "", fmt.Errorf("I don't know how to say hello in %s!", g.lang)
	}
}

func (g greeter) Goodbye() (string, error) {
	switch g.lang {
	case es:
		return "adios!", nil
	case en:
		return "goodbye!", nil
	default:
		return "", fmt.Errorf("I don't know how to say goodbye in %s!", g.lang)
	}
}
```

## Table-driven tests

In a [table-driven][tabledriven] test, each table entry is a complete test case
with inputs and expected results, and sometimes with additional information such
as a test name to make the test output easily readable. This can help reduce
test duplication, so that every variant being tested is presented as a line in
the table.

Given a table of test cases, the actual test simply iterates through all table
entries and for each entry performs the necessary tests.

[tabledriven]: https://github.com/golang/go/wiki/TableDrivenTests

Using the [gotests][gotests] library to create a test,

```shell
gotests -exported go_test.go
```

creates this test file:

```golang
func Test_greeter_Hello(t *testing.T) {
        type args struct {
                name string
        }
        tests := []struct {
                name    string
                g       greeter
                args    args
                want    string
                wantErr bool
        }{
                // TODO: Add test cases.
        }
        for _, tt := range tests {
                t.Run(tt.name, func(t *testing.T) {
                        got, err := tt.g.Hello(tt.args.name)
                        if (err != nil) != tt.wantErr {
                                t.Errorf("greeter.Hello() error = %v, wantErr %v", err, tt.wantErr)
                                return
                        }
                        if got != tt.want {
                                t.Errorf("greeter.Hello() = %v, want %v", got, tt.want)
                        }
                })
        }
}
```

Each row in the table has to provide a test name, a previously set up greeter,
the arguments to call the function with, and finally the desired string and
whether or not an error is desired.

The setup function below uses a closure as a test function, providing arguments
to the `Hello` function and then checking the result. The statement `if (err !=
nil) != tt.wantErr` is true if an error is desired and not obtiained, or if an
error was not desired but was obtained.

A good thing about its code is that all the logic is in one place. To add an
additional test case, it is enough to add a row with the additional data
structures. Error messages are consistent across tets, and it is relatively easy
easy to see what is going on.

Let's add a few tests to the table. Here we will test the English and
Spanish greetings, and also ask for an Esperanto greeting, checking that there
is an error.

```golang
{
	{"en", NewGreeter("EN"), args{"Joe"}, "hi, Joe", false},
	{"es", NewGreeter("ES"), args{"Jose"}, "hola, Jose", false},
	{"esperanto", NewGreeter("esperanto"), args{"Adorinda"}, "", true},
}
```

It was easy to achieve branch coverage with this auto-generated test. 

Even for a very simple greeter class, however, there is a lot of input data to
go in the table. The test code (below the table) is not easy to read. In more
complex scenarios, this style of testing can result in tests that are very
spread out and hard to reason about.

Suppose we want to check the returned error. Where would we add a checking code?

If I am a newcomer to this code, it may be difficult reading the test code above
and seeing immediately how the greeting functions and their receiver struct
work.

[gotests]: https://github.com/cweill/gotests

## Scenarios

We would like to write a test like this:

```go
{
    "says hi to Joe in English",
    args{
        name: "Joe",
    },
    func(s SomeType) {
        s.givenLanguage("EN")
        s.when(hello)
        s.assertNoError()
        s.assertResultIs("hi, Joe")
    },
}
```

This will scale up better with more complex tests, and is more friendly to newcomers.
It is easy to scan this function and get a feel for what the function is supposed to
be doing. 

The conventions are simple: the `given[X]` functions should set up the receiver;
if the receiver has mocked collaborators, they could provided as arguments here.
The `assertX` functions should check the output values of the `hello` function,
including error values. Lastly, The `when` method should invoke the function and
save the results.

## Generic tester class

Let's define a generic Tester class that will help us write unit tests for the
greeter in the style above. It assumes the receiver is a struct and that the
function returns a value and an error. Most complex real-world functions in Go
have this signature. 

The tester will be generic on `F`, a struct type containing the receiver fields;
`A`, which defines the data type for each argument to the function under test;
and `R`, which is the type the function returns. `err` will be set to the
returned error value.

```go
type tester[F, A, R any] struct {
	assert   *assert.Assertions
	fields   F
	args     A
	response R
	err      error
}
```

The constructor takes the `args` just like the table-driven test. The
`givenFields` method sets the tester's `fields` and returns the tester
so that we can chain the commands if we want.

```
func newTester[F, A, R any](t *testing.T, args A) *tester[F, A, R] {
	return &tester[F, A, R]{
		assert: assert.New(t),
		args:   args,
	}
}

func (s *tester[F, A, R]) givenFields(fields F) *tester[F, A, R] {
	s.fields = fields
	return s
}

```

We will instantiate a tester class before starting the test:

```go
type args struct {
   name string
}

type fields struct {
   lang lang
}

// A tester for a struct receiver with 'fields', 
t := newTester[fields, args, string]

t.givenFields(fields{lang: "EN"})
... do something...
```

Next we want to add a function `t.when(...)` that invokes the function under
test with arguments that we pass in. 

```go
func (s *tester[F, A, R]) when(call func(F, A) (R, error)) {
	s.response, s.err = call(s.fields, s.args)
}
```

Now we can rewrite the greeter test using the tester.

```go
type args struct {
   name string
}

type fields struct {
   lang lang
}

hello := func(fields greeterFields, args args) (string, error) {
    g := NewGreeter(fields.lang)
    return g.Hello(args.name)
}

// A tester for a struct receiver with 'fields', 
t := newTester[fields, args, string]

t.givenFields(fields{lang: "EN"})
t.when(hello)
... check assertions...
```

Finally, we want to make some assertions on the output. In this example,
we are wrapping the popular [testify][testify] package.

[testify]: https://github.com/stretchr/testify

```go
func (s *tester[F, A, R]) assertResultIs(result R) {
	s.assert.Equal(result, s.response)
}

func (s *tester[F, A, R]) assertNoError() *tester[F, A, R] {
	s.assert.NoError(s.err)
	return s
}

func (s *tester[F, A, R]) assertError() *tester[F, A, R] {
	s.assert.Error(s.err)
	return s
}
```

Putting it all together, our test can be called like this:

```
type args struct {
   name string
}

type fields struct {
   lang lang
}

hello := func(fields greeterFields, args args) (string, error) {
    g := NewGreeter(fields.lang)
    return g.Hello(args.name)
}

// A tester for a struct receiver with 'fields', 
t := newTester[fields, args, string]

t.givenFields(fields{lang: "EN"})
t.when(hello)
t.assertNoError()
t.assertResultIs("hi, Yao")
```

## Table-driven test, revisited

Now let's put it in a table-driven, *scenario-driven* test. 

```go
func TestGreeter_Hello(t *testing.T) {
	type args struct {
		name string
	}
    type fields = greeterFields
    type tester = greeterTester[args, string])

	hello := func(fields fields, args args) (string, error) {
		g := NewGreeter(fields.lang)
		return g.Hello(args.name)
	}

	tests := []struct {
		name     string
		args     args
		scenario func(*tester)
	}{
		{
			"says hi to Yao in English",
			args{
				name: "Yao",
			},
			func(s *tester) {
				s.givenFields(fields{lang: "EN"})
				s.when(hello)
				s.assertNoError()
				s.assertResultIs("hi, Yao")
			},
		},
    }
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
    		a := assert.New(t)
			tt.scenario(&tester{
                Assert: a,
				Args:   tt.args,
			})
        }
    }
}
```

The table now contains 3 elements only: `name`, `args`, and `scenario`. This can be
the same for every test in the company codebase, so the reader can just scan this 
quickly and get right to the setup functions.

The tester `greeterTester` at package level and reused for all the greeter's functions.
(They will share the same struct fields.)

By implementing new `given...` methods on the tester, we can abstract away any complex
setup of the receiver, should it be necessary. The assertions are easy to read, and can
be reused across the coebase.  The test setup code in `t.Run(...)` at the bottom of the 
file is easy to read as well.

## Conclusion

Object-based langauges like Go require careful setup to put each object under
test in the necessary state. This test setup can obscure the meaning of the
tests.

Some simple generic tester packages can make the code easier to read, at the
cost of some verbosity. The resulting tests have a consistent structure that is
easy to read.

Keeping tests readable helps newcomers to the code approach the code by reading
the tests first. This lowers the cost of changes in the future.
