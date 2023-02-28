# Scenarios

The Go community uses table-driven testing heavily to keep tests concise. Sometimes, this comes at the expense of readability.

We have settled on a variant of table driven testing which uses scenarios to express test setup.
Using this testing style, we keep the advantages of table driven testing, while making test code easier for newcomers to approach and more reader-friendly.

## The importance of testing

Unit testing is key to the overall reliability of a system.

The importance of near 100% test coverage.

With pure functions, this is fairly straightforward: provide a series of inputs, and then test the outputs.

However, object-based test code will typically reuqire some setup. The object of the class (equivalent to the receiver in go) needs to be initialized somehow, and there may be various ways of doing this.

We will walk through a table-driven test and then introduce a receiver object. Then we will rewrite it in a more human-friendly way as a scenario.

## Code to test

We will test a greeter object, which can be constructed with a language string. It will provide us with a greeting in that language.

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

When we create a new greeter, we provide a language. In practice, we would want to check language here. We are checking this error in the functions so that we can check error conditions.

```golang
func NewGreeter(l string) greeter {
	return greeter{
		lang: lang(l),
	}
}
```

The `Hello` and `Goodbye` methods return a greeting string or an error, in case an unknown language is provided. 

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

In a [table-driven][tabledriven]] test, each table entry is a complete test case with inputs and expected results, and sometimes with additional information such as a test name to make the test output easily readable. This can help reduce test duplication, so that every variant being tested is presented as a line in the table.

Given a table of test cases, the actual test simply iterates through all table entries and for each entry performs the necessary tests.

[tabledriven]: https://github.com/golang/go/wiki/TableDrivenTests

Using the [gotests][gotests] library to create a test 

```shell
gotests -exported go_test.go
```

creates

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

Each row in the table has to provide a test name, a previously set up greeter, the arguments to call the function with, and finally the desired string and whether or not an error is desired. 

The setup function below uses a closure as a test function, providing arguments to the `Hello` function and then checking the result. The statement `if (err != nil) != tt.wantErr` is true if an error is desired and not obtiained, or if an error was not desired but was obtained. 

A good thing about its code is that all the logic is in one place. To add an additional test case, it is enough to add a row with the additional data structures. Error messages are consistent across tets, and it is relatively easy easy to see what is going on. 

Let's add a few tests to the table. Here we will test the test the English and Spanish greetings, and also ask for an Esperanto greeting, checking that there is an error.

```golang
{
	{"en", NewGreeter("EN"), args{"Joe"}, "hi, Joe", false},
	{"es", NewGreeter("ES"), args{"Jose"}, "hola, Jose", false},
	{"esperanto", NewGreeter("esperanto"), args{"Adorinda"}, "", true},
}
```

It was easy to achieve branch coverage with this auto-generated test. 

Even for a very simple greeter class, however, there is a lot of input data to go int he table. The test code (below the table) is not easy to read. In more complex scenarios, this style of testing can result in tests that are very spread out and hard to reason about. 

Suppose we want to check the returned error. Where would we add a checking code?

If I am a newcomer to this code, it may be difficult reading the test code above and seeing immediately how the greeting functions and their receiver struct work.

[gotests]: https://github.com/cweill/gotests

## Scenarios

Advantages of a more literate style

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

## Generic tester class

To achieve this, let's define a generic Tester class. 

For struct receivers, it will have a few helper functions for us to write down a scenario. The `FieldsType` contains the struct fields for the receiver; `ArgsType` defines the data type for each argument to the function under test; `ResponseType` is what the function returns.

```go
type tester[FieldsType any, ArgsType any, ResponseType any] struct {
	assert   *assert.Assertions
	args     ArgsType
	fields   FieldsType
	response ResponseType
	err      error
}

func newTester[F any, A any, R any](t *testing.T, args A) tester[F, A, R] {
	return tester[F, A, R]{
		assert: assert.New(t),
		args:   args,
	}
}

func (s *tester[F, A, R]) givenFields(fields F) *tester[F, A, R] {
	s.fields = fields
	return s
}

```

We will instantiate a tester class 

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

We will add a method to invoke the function under test with the arguments

```go
func (s *tester[F, A, R]) when(call func(F, A) (R, error)) {
	s.response, s.err = call(s.fields, s.args)
}
```

Now we can do 

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

Now we want to check assertions.


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

Finally, let's put the 

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

Now let's put it ina table driven test.

The result is here

```go
func TestGreeter_Hello(t *testing.T) {
	type args struct {
		name string
	}

	hello := func(fields greeterFields, args args) (string, error) {
		g := NewGreeter(fields.lang)
		return g.Hello(args.name)
	}

	tests := []struct {
		name     string
		args     args
		scenario func(*greeterTester[args, string])
	}{
		{
			"says hi to Yao in English",
			args{
				name: "Yao",
			},
			func(s *greeterTester[args, string]) {
				s.givenFields(fields{lang: "EN"})
				s.when(hello)
				s.assertNoError()
				s.assertResultIs("hi, Yao")
			},
		},
    ...
}
```

The table now contains 3 elements only. 

## Checking errors

One of the advantages vs the "out of the box" table-driven test is when checking errors.

