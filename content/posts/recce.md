---
title: 'Recce: A Go test recorder compatible with REST Client'
date: 2023-08-13T19:30:00-05:00
---

*Recce (ReKi)* **[V]**: to visit [a] place in order to become familiar with it.
- Collins

[-> github](https://github.com/kpassapk/recce)

You're hard at work when a new task comes in: you have to whip up a new REST API and
hash out the contract ASAP for the latest product feature. You decide to take it.

Now what? You track down consumers and lay out an initial deisign. You stand up
an early version of the endpoints, try to guard against incorrect input, and provide
some minimum level of feedback to avoid leaving your users in the dark. At the
same time, you are trying to write something that has a chance of being put into
production without outages.

But here's the trick: how can you be sure the API contracts stay intact? Or that
other teams aren't getting too cozy with quirks of your initial version,
treating them as a deliberate part of the design? And isn’t there a way to keep
the documentation fresh without resorting to a Slack message marathon? You want
to just code, after all.

It turns out that what starts out as a simple task reveals itself to be quite
challenging! Yet this may just be the main activity of backend software development.

In this post, we'll write some simple tools to keep things running smoothly. The
main idea is have our test tooling generate as many recordings of your
interface as possible in an executable format. This approach provides an
uninterrupted workflow from coding to debugging and visual validation.

Armed with these tools, navigating the early stages of API design isn’t just
speedier, it's more fun. Teammates will appreciate the up to date examples,
including recent changes and exploratory edge cases. Meanwhile, you have extra
time to make your application more robust.

If this sounds good, then read on! Code below is in Go, but should be easily
replicable in any language. You can also jump straight to
[the code](https://github.com/kpassapk/recce) on Github.

## REST(less)

REST APIs are a response to the SOAP days of super-heavy locked down contracts.
Perhaps an overcorrection: they are so contract-averse that really anything
goes. Yes, verbs - but that aside, no one standard wins, and bikeshedding starts
right out the gate. (Just browse a group board describing the drifting OpenAPI
specification to see what I mean.)

The lniking and explorability that were arguably the founding idea of REST seem
to have gone right out the window, leaving us with a pretty bare bones set of
standards and tooling.

Common aspects that every single production use could use, like filtering,
search, pagination, etc. are all left as an exercise to the reader. (And usually
just foregone, full stop.) As for tooling, in practice the collaborative
development process amounts to developers hoarding private Postman collections
and sharing shell (cURL) commands with each other. Not very 2023 if you ask me.
Don't even get me started on Postman itself and what a giant,
impossibly-badly-designed piece of bloatware it is.

Back to our project. Against this sea of uncertainty, a reasonable strategy is to
over-communicate: collect a broad set of examples of our API contract. Automate
this somehow; as we evolve the contract, we update all examples.

To be really fast, why not see if we can stay away from the unhappy Postman and
cURL duo altogether, doing all testing and example-saving in the amazing and expensive IDEs
at our disposal.

## Recordings

Back in my Ruby days, one of my favorite test tools was called [VCR][vcr]. As you made
requests to external APIs, the Ruby gem would keep recordings in files, and then
monkey-patch the HTTP client to return those answers instead of the real thing.
Super useful, because even under-documented aspects of the APIs would be
captured. Things like missing headers, incorrect content types, bad JSON bodies,
trailing backslashes in paths (yes, things go wrong even here).

[vcr]: https://github.com/vcr/vcr

Apart from helping you test, the set of recordings it built up over time was
kind of like documentation, if you squinted a bit. They were meant to be
machine-readable, but often I would find myself looking at versioned recordings
on Github. The format was a bit strange, but you could see requests and response
codes, bodies, headers and the like, all in one place. The Ruby tool spawned a bunch
of [variants](govcr) in [other][vcrpy] [languages][betamax], which testifies to the genral
usefulness of this pattern.

Over time, recordings of our own APIs became a kind of ad hoc - but effective - documentation set.

[govcr]: https://github.com/dnaeon/go-vcr
[vcrpy]: https://vcrpy.readthedocs.io/en/latest/usage.html
[betamax]: https://github.com/betamaxteam/betamax

Coming to Go, things felt a bit more strict. Not only is monkey-patching frowned
upon / not even possible, but testing is more pure in terms of how you are
supposed to do it: use the same handler functions in your test and in your
program, and do all testing internal to your process. Much preferable and way
faster to run, in wall-clock seconds. But part of was left wanting good old VCR
when I was still feeling things out. I for sure missed the versioned recording
files.

Along the way I made one fortunate discovery: VS Code [REST
client](https://marketplace.visualstudio.com/items?itemName=humao.rest-client)
as an alternative to Postman and cURL. It uses a format like this:

```
POST /api
Content-Type: application/json

{
  "one": "two"
}
```

It's not an IETF standard as far as I can see, but perhaps it should be.
Implementaitons are widepsread. ([Emacs][restemacs], [Vim][restvim],
[Intellij][intellij]) Seems like it brings back a bit of the simplicity REST was
supposed to be all about!

[restemacs]: https://github.com/pashky/restclient.el
[restvim]: restclient.vim
[intellij]: https://www.jetbrains.com/help/idea/http-client-in-product-code-editor.html

It should be easy to record tests in Go, I thought - and why not save in a
sorta standard format that can be immediately re-run? 

Let's put this together bit by bit:
1. Nice standard tests in Golang
2. ... that save test files as they run
3. ... in REST client format

We're going to start with a sample REST API for "tasks". We will use
table-driven tests in Golang, leaving a recording of API requests and responses
to files that can later be executed. This will give us quick feedback, and
generate a large amount of runnable requests to play with. Perfect for the early
stages of API design.

## Our API

Our example will let you create and retrieve a list of tasks.

1. To get all tasks: `GET /tasks`
2. To get a specific task by ID: `GET tasks/{ID}`
3. To create a new task: `POST /tasks` with a JSON body, e.g., `{"title": "New task"}`

The "create task' API, using `github.com/gorilla/mux package` for routing, would look something like this:

```go
package main

import (
	"encoding/json"
	"log"
	"net/http"
	"github.com/gorilla/mux"
	"strconv"
)

type Task struct {
	ID    int    `json:"id"`
	Title string `json:"title"`
}

func createTask(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	var task Task
	_ = json.NewDecoder(r.Body).Decode(&task)

	task.ID = len(tasks) + 1
	tasks = append(tasks, task)

	json.NewEncoder(w).Encode(task)
}
```

Set up a router and a main:

```
func SetupRouter() *mux.Router {
	r := mux.NewRouter()
	r.HandleFunc("/tasks", createTask).Methods("POST")
	return r
}

func main() {
	r := SetupRouter()
	http.ListenAndServe(":8000", r)
}
```

To create a new task, we send a JSON-encoded task name. 

```
POST http://localhost:8000/tasks
Content-Type: application/json

{
  "title": "New task"
}
```


If we open up this request using the REST client in VS Code, emacs, vim, or others, we can seend it and get a response back. 

```
HTTP/1.1 200 OK
Content-Type: application/json

{
  "id": 1,
  "title": "New task"
}
```

It's a start! Now let's write a test for it.

## Testing the "Create" endpoint

A table-driven test for the "create " endpoint might look like

```go
func TestCreateTask(t *testing.T) {
	r := SetupRouter()

	tests := []struct {
		name   string
		input  string
		status int
		output Task
	}{
		{
			name:   "valid task",
			input:  `{"title": "Test Task"}`,
			status: http.StatusOK,
			output: Task{ID: 2, Title: "Test Task"},  // Assuming 1 task already exists, the ID will be 2
		},
		// Add more cases as needed
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			req, err := http.NewRequest("POST", "/tasks", bytes.NewBuffer([]byte(tt.input)))
			if err != nil {
				t.Fatal(err)
			}

			rr := httptest.NewRecorder()
			r.ServeHTTP(rr, req)

			if rr.Code != tt.status {
				t.Errorf("Expected status %v; got %v", tt.status, rr.Code)
			}

			var task Task
			err = json.Unmarshal(rr.Body.Bytes(), &task)
			if err != nil {
				t.Fatal(err)
			}

			if task != tt.output {
				t.Errorf("Expected task %+v; got %+v", tt.output, task)
			}
		})
	}
}
```

This test will not send out a request, but instead redirect the output to a
recorder using the `httptest` package. More test cases can be added to the table
(slice) at the top fo the test file, providing different inputs and validating
the output against our expectation.

There are some difficulties with this, however. 
1. We have to deal with the assumption of the task ID
2. As the API grows, the test code will get a lot more complicated
3. The API may still be in flux

If there is a failure, it will take us a second to figure out whether the error
is due to bad test code, or bad program code. If we have time pressure in
developing a new API, it will take us so long to write test code that we may
sacrifice overall veocity.

We would normally swtich to Postman or a similar tool to use the API and look at
API. We have to switch to the program and switch context to understanding what is
being sent out; then switch back to the IDE. This context switch is expensive,
compared with the usual debugging cycle. Postman does have automation, but it's
in Javascript. We already have very full-featured langauge in Go.

Using any external tool to exercise our API endpoints will leave almost no paper
trail behind. We will end up with separate program code and Postman collections
or cURL requests that are not versioned. Newcomers will have to ask or try and
fgure out what the program does by looking at the code. (Go is easy to follow
but not the most compact, and invariably descends into infrastructurey words
like readers and buffers.)

To achieve a looser testing style, let's implement a simple tester which only
checks response codes. Verifying the request and response bodies will be up to
us at this stage, with the help `.rest` files

## Tester

Let's write the same test but introduce a tester

```go
type tester struct {
	assert *assert.Assertions
	req    *http.Request
	res    *http.Response
}
```



```go
func (s *tester) NewRequest(method, url string, body io.Reader) {
	req, err := http.NewRequest(method, url, body)
	s.assert.NoError(err)
	s.req = req
}

func (s *tester) SendRequest(handler http.HandlerFunc) {
	rr := httptest.NewRecorder()
	handler(rr, s.req)
	s.res = rr.Result()
}

func (s *tester) CheckStatus(status int) {
	s.assert.Equal(status, s.res.StatusCode)
}
```

Then we can replace the test running code above with a simplified version

```
t.Run(tt.name, func(t *testing.T) {
    tester := Start(t)
    tester.SetRequest("POST", "/tasks", bytes.NewBuffer([]byte(tt.input)))
    tester.SendRequest(r.ServeHTTP)
    tester.CheckStatus(tt.status)
})
```

Now that we have our own tester, we can add some methods to record the request
to a file as a side effect.

## Recording the request

To record the test, we add a `Finish` method which creates a test file.

```go
func (s *tester) Finish() {
    err = s.createTestFile()
    if err != nil {
        panic(err)
    }
    err = s.res.Body.Close()
    if err != nil {
        panic(err)
    }
}
```

We will call this method with `defer` just after `Start()`, so that the files
are written once all tests are done.

```
tester.Start()
defer tester.Finish()
tester.SetRequest(...)
...
```

To implement `createTestFile()`, we're going to have to decide how to lay out the test files. Here is one way:

```
recordings
└── tasks
    ├── create
    │   ├── example1.rest
    │   ├── example2.rest
    │   └── example3.rest
    ├── update
    │   └── example1.rest
    └── delete
```

We will store files using the noun (tasks), then one directory for each verb,
and then example files. Let's define "group" to be`tasks/create`, `tasks/update`
and so on. Each group will have many examples. Add the group to the tester
struct, as well as a test case number and name, and a hostname
to write in the test files.

```
type tester struct {
	group  string
    tc int
    host string
    ...
}
```

Now let's write the function to write out or example file to disk.

```
func (s *tester) createTestFile() error {
	// Split group into individual directories
	directories := strings.Split(s.group, "/")

	// Build the full path starting from "examples"
	fullPath := filepath.Join("scenarios", filepath.Join(directories...))

	// Ensure the directories exist
	err := os.MkdirAll(fullPath, os.ModePerm)
	if err != nil {
		return fmt.Errorf("error creating directories: %v", err)
	}

	// Create the file
	fileName := fmt.Sprintf("example%d.rest", s.tc)
	file, err := os.Create(filepath.Join(fullPath, fileName))
	if err != nil {
		return fmt.Errorf("error creating file: %v", err)
	}
	defer file.Close()

	// Write file contents
	content, err := s.prettyPrintRequest()  // <-- implement me
	if err != nil {
		return errors.Wrap(err, "error pretty printing request")
	}
	_, err = file.WriteString(content)
	if err != nil {
		return fmt.Errorf("error writing to file: %v", err)
	}

	return nil
}

```

The `errors.Wrap` command is from
[github.com/pkg/errors](https://github.com/pkg/errors), and provides stack
traces and slightly improved semantics for dealing with error chains. 

The `prettyPrintRequest()` command will write out the `*http.Request` in a format
understandable by the text-based REST clients:


```
func (s *apiScenario) prettyPrintRequest() (string, error) {
	var buf bytes.Buffer

	// Print method, URL, and protocol
	buf.WriteString(fmt.Sprintf("%s %s/%s %s\n", s.req.Method, s.hostname, s.req.URL, s.req.Proto))

	// Print headers
	for k, values := range s.req.Header {
		for _, v := range values {
			buf.WriteString(fmt.Sprintf("%s: %s\n", k, v))
		}
	}

	if s.req.Body != nil {
		// Print a blank line to separate headers from body
		buf.WriteString("\n")

		var printableBody []byte
		if s.isContentTypeJSON() {
			var pp bytes.Buffer
			err := json.Indent(&pp, s.bodyBytes, "", "  ")
			if err != nil {
				// Silently ignore errors and print the body as is
				printableBody = s.bodyBytes
			} else {
			    printableBody = pp.Bytes()
            }
		} else {
			printableBody = s.bodyBytes
		}

		buf.Write(printableBody)
	}

	return buf.String(), nil
}
```

The format is pretty simple: the request method, URL, and protocol (e.g.
HTTP/1.1) go in the first line. Any headers go in the following lines, separated
by a colon. After an empty line, we print out the request body. In the common
case of JSON request bodies, we try to pretty print it. Since we may want test
cases with unparseable JSON, this should fall back on printing the raw bytes.
The `isContentTypeJSON()` is not reproduced here, but is available in the
example code.

Since this function is called at the end of the tests, the `req.Body` (which as
an `io.ReadCloser` interface) will have already been read. Its bytes are already
"consumed", so we will read the contents into a `bytes.Buffer`:


```
func (s *tester) saveRequestBody() error {
	// Check if the request has a body
	if s.req.Body == nil {
		return errors.New("request has no body")
	}

	// Read the request body
	var err error
	s.bodyBytes, err = io.ReadAll(s.req.Body)
	if err != nil {
		return err
	}

	// Restore the request body to its original state
	s.req.Body = io.NopCloser(bytes.NewBuffer(s.bodyBytes))

	return nil
}
```

Let's modify `SendRequest` to call this function just before we send the request off.

```
func (s *tester) SendRequest(handler http.HandlerFunc) {
	rr := httptest.NewRecorder()
	if s.req.Body != nil {
		err := s.saveRequestBody()
		if err != nil {
			s.assert.FailNow(err.Error())
		}
	}
	handler(rr, s.req)
	s.res = rr.Result()
}
```

When we run the test, we will see an example file that looks like this in `sceanrios/tasks/create/example1.rest`

```
POST localhost:8000/tasks HTTP/1.1

{
  "title": "Test Task"
}
```

When we run this example in Goland, VS Code, or any other editor which sports a REST client, we get a text response:

```
HTTP/1.1 200 OK
Content-Type: application/json
Date: Sat, 12 Aug 2023 22:49:04 GMT
Content-Length: 29

{
  "id": 2,
  "title": "Test Task"
}

Response file saved.
> 2023-08-12T174905.200.json
```

Although we did not automate tests against the response body at this early
stage, it is already easy to get a feel for the behavior of the API. If we want
to tweak the request, we can do the tweaks directly in the `.rest` file, without
having to go back to the Go code, and without having to leave the IDE. This
provides a tremendously fast feedback cycle.

A simple improvement would be to save these text responses next to each example.
By versioning both the request and the response, The trail of recordings will
help us and our teammates until automated testing catches up and more robust
documentation is built.

## Recce

These ideas have gone into [recce][recce], in case it may be useful to
somebody. It's a super early version right now. Comments welcome.

[recce]: https://github.com/kpassapk/recce

Since a copy of the request and response is kept in memory, this library will be
performant only with small requests and responses. Most of the time, this will not
be a serious limitation.

This "light" version of the Ruby VCR-like libraries doesn't affect the calls
made by the test code in any way, it just saves a bunch of files that are easy
to read and can be re-run at will. I have found this feedback loop to be
amazingly fast. 

Once the recording is no longer needed, the tester can be trivially swapped out,
and test code will be almost unchanged.
